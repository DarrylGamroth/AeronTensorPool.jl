@inline function next_lease_id!(state::DriverState)
    lease_id = state.next_lease_id
    state.next_lease_id += 1
    return lease_id
end

@inline function lease_expiry_ns(state::DriverState, now_ns::UInt64)
    grace_ns = UInt64(state.config.policies.lease_keepalive_interval_ms) * 1_000_000 *
        UInt64(state.config.policies.lease_expiry_grace_intervals)
    return now_ns + grace_ns
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
    correlation_id = ShmAttachRequest.correlationId(msg)
    stream_id = ShmAttachRequest.streamId(msg)
    client_id = ShmAttachRequest.clientId(msg)
    role = ShmAttachRequest.role(msg)
    expected_layout_version = ShmAttachRequest.expectedLayoutVersion(msg)
    max_dims = ShmAttachRequest.maxDims(msg)

    publish_mode = ShmAttachRequest.publishMode(msg)
    if publish_mode == DriverPublishMode.NULL_VALUE || publish_mode == DriverPublishMode.UNKNOWN
        publish_mode = DriverPublishMode.REQUIRE_EXISTING
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

    stream_state = get_or_create_stream!(state, stream_id, publish_mode)
    if isnothing(stream_state)
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

    if max_dims != 0 && max_dims > stream_state.profile.max_dims
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.INVALID_PARAMS,
            "max_dims exceeds profile",
            nothing,
        )
    end

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
    expiry_ns = lease_expiry_ns(state, now_ns)
    lease = DriverLease(lease_id, stream_id, client_id, expiry_ns, LeaseLifecycle(), role)
    state.leases[lease_id] = lease

    if role == DriverRole.PRODUCER
        stream_state.producer_lease_id = lease_id
    else
        push!(stream_state.consumer_lease_ids, lease_id)
    end

    Hsm.dispatch!(lease.lifecycle, :AttachOk, state.metrics)
    emit_attach_response!(state, correlation_id, DriverResponseCode.OK, "", stream_state, lease_id, expiry_ns)
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
        end
    end

    lease.role == DriverRole.PRODUCER || emit_lease_revoked!(state, lease, reason, now_ns)
    Hsm.dispatch!(lease.lifecycle, :Close, state.metrics)
    delete!(state.leases, lease_id)
    if !isnothing(stream_state) &&
       stream_state.producer_lease_id == 0 &&
       isempty(stream_state.consumer_lease_ids) &&
       state.config.policies.allow_dynamic_streams
        delete!(state.streams, stream_state.stream_id)
    end
    return true
end
