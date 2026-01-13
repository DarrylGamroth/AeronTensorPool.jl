function next_lease_id!(state::DriverState)
    lease_id = state.next_lease_id
    state.next_lease_id += 1
    return lease_id
end

function lease_expiry_ns(state::DriverState, now_ns::UInt64)
    grace_ns = UInt64(state.config.policies.lease_keepalive_interval_ms) * 1_000_000 *
        UInt64(state.config.policies.lease_expiry_grace_intervals)
    return now_ns + grace_ns
end

function desired_node_id(msg::ShmAttachRequest.Decoder)
    node_id = ShmAttachRequest.desiredNodeId(msg)
    if node_id == ShmAttachRequest.desiredNodeId_null_value(ShmAttachRequest.Decoder)
        return nothing
    end
    return node_id
end

function allocate_node_id!(state::DriverState, desired::Union{UInt32, Nothing})
    if isnothing(desired)
        start = state.next_node_id
        node_id = start
        while haskey(state.assigned_node_ids, node_id)
            node_id = node_id == typemax(UInt32) ? UInt32(1) : node_id + 1
            node_id == start && return nothing
        end
        state.next_node_id = node_id == typemax(UInt32) ? UInt32(1) : node_id + 1
        return node_id
    end
    haskey(state.assigned_node_ids, desired) && return nothing
    return desired
end

"""
Handle an incoming ShmAttachRequest.

Arguments:
- `state`: driver state.
- `msg`: decoded ShmAttachRequest message.

Returns:
- `true` if handled, `false` otherwise.
"""
function handle_attach_request!(state::DriverState, msg::ShmAttachRequest.Decoder)
    @tp_info "attach request received" correlation_id = ShmAttachRequest.correlationId(msg) stream_id =
        ShmAttachRequest.streamId(msg) client_id = ShmAttachRequest.clientId(msg) role =
        ShmAttachRequest.role(msg)
    correlation_id = ShmAttachRequest.correlationId(msg)
    stream_id = ShmAttachRequest.streamId(msg)
    client_id = ShmAttachRequest.clientId(msg)
    role = ShmAttachRequest.role(msg)
    expected_layout_version = ShmAttachRequest.expectedLayoutVersion(msg)
    requested_node_id = desired_node_id(msg)

    publish_mode = ShmAttachRequest.publishMode(msg)
    if publish_mode == DriverPublishMode.NULL_VALUE
        publish_mode = DriverPublishMode.REQUIRE_EXISTING
    end
    if publish_mode != DriverPublishMode.REQUIRE_EXISTING &&
       publish_mode != DriverPublishMode.EXISTING_OR_CREATE
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.UNSUPPORTED,
            "unsupported publish_mode",
            nothing,
        )
    end

    hugepages_policy = ShmAttachRequest.requireHugepages(msg)
    if hugepages_policy == DriverHugepagesPolicy.HUGEPAGES && !state.config.shm.require_hugepages
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "hugepages required but unavailable",
            nothing,
        )
    end
    if hugepages_policy == DriverHugepagesPolicy.STANDARD && state.config.shm.require_hugepages
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "hugepages required by driver policy",
            nothing,
        )
    end
    if hugepages_policy != DriverHugepagesPolicy.UNSPECIFIED &&
       hugepages_policy != DriverHugepagesPolicy.HUGEPAGES &&
       hugepages_policy != DriverHugepagesPolicy.STANDARD
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.INVALID_PARAMS,
            "unknown hugepages policy",
            nothing,
        )
    end

    for lease in values(state.leases)
        if lease.client_id == client_id
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.REJECTED,
                "client_id already attached",
                nothing,
            )
        end
    end

    stream_state, stream_status = get_or_create_stream!(state, stream_id, publish_mode)
    if isnothing(stream_state)
        if stream_status == :range_missing
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.INVALID_PARAMS,
                "stream_id_range not configured",
                nothing,
            )
        elseif stream_status == :range_exhausted
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.INVALID_PARAMS,
                "stream_id_range exhausted",
                nothing,
            )
        elseif stream_status == :profile_missing
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.INVALID_PARAMS,
                "profile not found",
                nothing,
            )
        end
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "stream not provisioned",
            nothing,
        )
    end

    if expected_layout_version != 0 && expected_layout_version != UInt32(1)
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "layout_version mismatch",
            nothing,
        )
    end

    isempty(stream_state.profile.payload_pools) &&
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.INVALID_PARAMS,
            "stream has no payload pools",
            nothing,
        )

    for lease in values(state.leases)
        if lease.stream_id == stream_id && lease.client_id == client_id && lease.role == role
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.REJECTED,
                "duplicate attach",
                nothing,
            )
        end
    end

    if stream_state.epoch == 0
        try
            bump_epoch!(state, stream_state)
        catch err
            msg = sprint(showerror, err)
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.INTERNAL_ERROR,
                "failed to provision SHM: $(msg)",
                nothing,
            )
        end
    end

    if role == DriverRole.PRODUCER
        if stream_state.producer_lease_id != 0
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.REJECTED,
                "producer already attached",
                nothing,
            )
        end
        try
            bump_epoch!(state, stream_state)
        catch err
            msg = sprint(showerror, err)
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.INTERNAL_ERROR,
                "failed to provision SHM: $(msg)",
                nothing,
            )
        end
    end

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    lease_id = next_lease_id!(state)
    node_id = allocate_node_id!(state, requested_node_id)
    if node_id === nothing
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "node_id unavailable",
            nothing,
        )
    end
    expiry_ns = lease_expiry_ns(state, now_ns)
    lease = DriverLease(lease_id, stream_id, client_id, node_id, expiry_ns, LeaseLifecycle(), role)
    state.leases[lease_id] = lease
    state.assigned_node_ids[node_id] = lease_id

    if role == DriverRole.PRODUCER
        stream_state.producer_lease_id = lease_id
    else
        push!(stream_state.consumer_lease_ids, lease_id)
    end

    @tp_info "lease attached" lease_id stream_id client_id role expiry_ns
    Hsm.dispatch!(lease.lifecycle, :AttachOk, state.metrics)
    emit_attach_response!(
        state,
        correlation_id,
        DriverResponseCode.OK,
        "",
        stream_state,
        lease_id,
        expiry_ns,
        node_id,
    )
    emit_driver_announce!(state, stream_state)
    return true
end

"""
Handle an incoming ShmDetachRequest.

Arguments:
- `state`: driver state.
- `msg`: decoded ShmDetachRequest message.

Returns:
- `true` if handled, `false` otherwise.
"""
function handle_detach_request!(state::DriverState, msg::ShmDetachRequest.Decoder)
    @tp_info "detach request received" correlation_id = ShmDetachRequest.correlationId(msg) lease_id =
        ShmDetachRequest.leaseId(msg) stream_id = ShmDetachRequest.streamId(msg) client_id =
        ShmDetachRequest.clientId(msg) role = ShmDetachRequest.role(msg)
    correlation_id = ShmDetachRequest.correlationId(msg)
    lease_id = ShmDetachRequest.leaseId(msg)
    stream_id = ShmDetachRequest.streamId(msg)
    client_id = ShmDetachRequest.clientId(msg)
    role = ShmDetachRequest.role(msg)

    lease = get(state.leases, lease_id, nothing)
    if isnothing(lease) ||
       lease.stream_id != stream_id ||
       lease.client_id != client_id ||
       lease.role != role
        return emit_detach_response!(state, correlation_id, DriverResponseCode.REJECTED, "unknown lease")
    end

    revoke_lease!(state, lease_id, DriverLeaseRevokeReason.DETACHED, UInt64(Clocks.time_nanos(state.clock)))
    return emit_detach_response!(state, correlation_id, DriverResponseCode.OK, "")
end

"""
Handle an incoming ShmLeaseKeepalive.

Arguments:
- `state`: driver state.
- `msg`: decoded ShmLeaseKeepalive message.

Returns:
- `true` if handled, `false` otherwise.
"""
function handle_keepalive!(state::DriverState, msg::ShmLeaseKeepalive.Decoder)
    @tp_info "keepalive received" lease_id = ShmLeaseKeepalive.leaseId(msg) stream_id =
        ShmLeaseKeepalive.streamId(msg) client_id = ShmLeaseKeepalive.clientId(msg) role =
        ShmLeaseKeepalive.role(msg)
    lease_id = ShmLeaseKeepalive.leaseId(msg)
    lease = get(state.leases, lease_id, nothing)
    if isnothing(lease)
        return false
    end
    Hsm.dispatch!(lease.lifecycle, :Keepalive, state.metrics)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    lease.expiry_ns = lease_expiry_ns(state, now_ns)
    state.metrics.keepalives += 1
    return true
end

"""
Handle an incoming ShmDriverShutdownRequest.

Arguments:
- `state`: driver state.
- `msg`: decoded ShmDriverShutdownRequest message.

Returns:
- `true` if handled, `false` otherwise.
"""
function handle_shutdown_request!(state::DriverState, msg::ShmDriverShutdownRequest.Decoder)
    @tp_info "shutdown request received" correlation_id = ShmDriverShutdownRequest.correlationId(msg) reason =
        ShmDriverShutdownRequest.reason(msg)
    token = String(ShmDriverShutdownRequest.token(msg))
    if isempty(state.config.policies.shutdown_token)
        return false
    end
    if token != state.config.policies.shutdown_token
        return false
    end

    state.shutdown_reason = ShmDriverShutdownRequest.reason(msg)
    msg_error = ShmDriverShutdownRequest.errorMessage(msg)
    state.shutdown_message = isempty(msg_error) ? "" : String(msg_error)
    driver_lifecycle_dispatch!(state, :ShutdownRequested)
    return true
end

function dispatch_lease_revoke!(lease::DriverLease, reason::DriverLeaseRevokeReason.SbeEnum, metrics::DriverMetrics)
    if reason == DriverLeaseRevokeReason.DETACHED
        return Hsm.dispatch!(lease.lifecycle, :Detach, metrics)
    elseif reason == DriverLeaseRevokeReason.EXPIRED
        return Hsm.dispatch!(lease.lifecycle, :LeaseTimeout, metrics)
    end
    return Hsm.dispatch!(lease.lifecycle, :Revoke, metrics)
end

function revoke_lease!(state::DriverState, lease_id::UInt64, reason::DriverLeaseRevokeReason.SbeEnum, now_ns::UInt64)
    @tp_warn "lease revoked" lease_id reason
    lease = get(state.leases, lease_id, nothing)
    isnothing(lease) && return false

    stream_state = get(state.streams, lease.stream_id, nothing)
    dispatch_lease_revoke!(lease, reason, state.metrics)
    if !isnothing(stream_state)
        if lease.role == DriverRole.PRODUCER
            stream_state.producer_lease_id = 0
            emit_lease_revoked!(state, lease, reason, now_ns)
            bump_epoch!(state, stream_state)
            emit_driver_announce!(state, stream_state)
        else
            delete!(stream_state.consumer_lease_ids, lease_id)
            delete!(state.consumer_descriptor_streams, lease.client_id)
            delete!(state.consumer_control_streams, lease.client_id)
        end
    end

    lease.role == DriverRole.PRODUCER || emit_lease_revoked!(state, lease, reason, now_ns)
    Hsm.dispatch!(lease.lifecycle, :Close, state.metrics)
    delete!(state.leases, lease_id)
    delete!(state.assigned_node_ids, lease.node_id)
    if !isnothing(stream_state) &&
       stream_state.producer_lease_id == 0 &&
       isempty(stream_state.consumer_lease_ids) &&
       state.config.policies.allow_dynamic_streams
        delete!(state.streams, stream_state.stream_id)
    end
    return true
end
