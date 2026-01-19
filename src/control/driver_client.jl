"""
Driver client state for control-plane requests and responses.
"""
mutable struct DriverClientState
    pub::Aeron.Publication
    sub::Aeron.Subscription
    attach_proxy::AttachRequestProxy
    keepalive_proxy::KeepaliveProxy
    detach_proxy::DetachRequestProxy
    poller::DriverResponsePoller
    client_id::UInt32
    role::DriverRole.SbeEnum
    lease_id::UInt64
    stream_id::UInt32
    node_id::UInt32
    keepalive_timer::PolledTimer
    next_correlation_id::Int64
    revoked::Bool
    shutdown::Bool
    keepalive_failed::Bool
end

"""
Initialize a driver client for control-plane messaging.

Arguments:
- `client`: Aeron client to use for publications/subscriptions.
- `control_channel`: Aeron channel for driver control.
- `control_stream_id`: Aeron stream id for driver control.
- `client_id`: unique client identifier.
- `role`: driver role enum (producer/consumer/etc).
- `keepalive_interval_ns`: keepalive interval in nanoseconds (keyword).
- `attach_purge_interval_ns`: purge interval for stale attach responses (keyword).

Returns:
- `DriverClientState` initialized for control-plane operations.
"""
function init_driver_client(
    client::Aeron.Client,
    control_channel::AbstractString,
    control_stream_id::Int32,
    client_id::UInt32,
    role::DriverRole.SbeEnum;
    keepalive_interval_ns::UInt64 = UInt64(1_000_000_000),
    attach_purge_interval_ns::UInt64 = UInt64(0),
)
    pub = Aeron.add_publication(client, control_channel, control_stream_id)
    sub = Aeron.add_subscription(client, control_channel, control_stream_id)
    effective_id = resolve_client_id(client_id)
    @tp_info "Driver client control endpoints" role = role client_id = effective_id channel = control_channel stream_id =
        control_stream_id pub_max_payload = Aeron.max_payload_length(pub) pub_max_message =
        Aeron.max_message_length(pub) pub_channel_status_indicator_id = Aeron.channel_status_indicator_id(pub) sub_channel_status_indicator_id =
        Aeron.channel_status_indicator_id(sub)
    poller = DriverResponsePoller(sub)
    set_interval!(poller.attach_purge_timer, attach_purge_interval_ns)
    return DriverClientState(
        pub,
        sub,
        AttachRequestProxy(pub),
        KeepaliveProxy(pub),
        DetachRequestProxy(pub),
        poller,
        effective_id,
        role,
        UInt64(0),
        UInt32(0),
        UInt32(0),
        PolledTimer(keepalive_interval_ns),
        init_correlation_seed(effective_id),
        false,
        false,
        false,
    )
end

function resolve_client_id(client_id::UInt32)
    if client_id == 0
        assigned = rand(UInt32)
        assigned == 0 && (assigned = UInt32(1))
        @tp_info "auto-assigned client_id" client_id = assigned
        return assigned
    end
    return client_id
end

function init_correlation_seed(client_id::UInt32)
    low = rand(UInt32)
    low == 0 && (low = UInt32(1))
    return Int64((UInt64(client_id) << 32) | UInt64(low))
end

function reset_client_id!(state::DriverClientState, client_id::UInt32)
    state.client_id = client_id
    state.next_correlation_id = init_correlation_seed(client_id)
    empty!(state.poller.attach_by_correlation)
    state.poller.attach_purge_active = false
    state.poller.attach_purge_touch = false
    return nothing
end

"""
Return the next correlation id for control-plane requests.

Arguments:
- `state`: driver client state.

Returns:
- Correlation id (Int64).
"""
function next_correlation_id!(state::DriverClientState)
    cid = state.next_correlation_id
    high = UInt64(cid) & 0xffff_ffff_0000_0000
    low = UInt32(UInt64(cid) & 0xffff_ffff) + UInt32(1)
    low == 0 && (low = UInt32(1))
    state.next_correlation_id = Int64(high | UInt64(low))
    return cid
end

"""
Send an attach request and return the correlation id.

Arguments (keywords):
- `stream_id`: stream identifier to attach.
- `expected_layout_version`: expected layout version (default: 0).
- `publish_mode`: publish mode override (optional).
- `require_hugepages`: hugepage policy (optional).
- `desired_node_id`: requested node ID (optional).
- `desired_node_id`: requested node ID (optional).

Returns:
- Correlation id (Int64) on send success, or 0 on failure.
"""
function send_attach_request!(
    state::DriverClientState;
    stream_id::UInt32,
    expected_layout_version::UInt32 = UInt32(0),
    publish_mode::Union{DriverPublishMode.SbeEnum, Nothing} = nothing,
    require_hugepages::Union{DriverHugepagesPolicy.SbeEnum, Bool, Nothing} = nothing,
    desired_node_id::Union{UInt32, Nothing} = nothing,
)
    correlation_id = next_correlation_id!(state)
    sent = send_attach!(
        state.attach_proxy;
        correlation_id = correlation_id,
        stream_id = stream_id,
        client_id = state.client_id,
        role = state.role,
        expected_layout_version = expected_layout_version,
        publish_mode = publish_mode,
        require_hugepages = require_hugepages,
        desired_node_id = desired_node_id,
    )
    if !sent
        @tp_warn "attach request send failed" correlation_id = correlation_id stream_id = stream_id client_id =
            state.client_id role = state.role
        return Int64(0)
    end
    return correlation_id
end

"""
Apply a successful attach response to the client state.
"""
function apply_attach!(state::DriverClientState, attach::AttachResponse)
    if attach.code == DriverResponseCode.OK
        state.lease_id = attach.lease_id
        state.stream_id = attach.stream_id
        if attach.node_id == ShmAttachResponse.nodeId_null_value(ShmAttachResponse.Decoder)
            state.node_id = UInt32(0)
        else
            state.node_id = attach.node_id
        end
        state.revoked = false
        state.shutdown = false
    end
    return nothing
end

"""
Poll driver responses and emit keepalives when due.

Arguments:
- `state`: driver client state.
- `now_ns`: current time in nanoseconds.

Returns:
- Work count (responses processed + keepalive sent).
"""
function driver_client_do_work!(state::DriverClientState, now_ns::UInt64)
    poller = state.poller
    work_count = poll_driver_responses!(poller)
    if poller.attach_purge_timer.interval_ns != 0
        if poller.attach_purge_touch
            reset!(poller.attach_purge_timer, now_ns)
            poller.attach_purge_active = true
            poller.attach_purge_touch = false
        end
        if poller.attach_purge_active && expired(poller.attach_purge_timer, now_ns)
            empty!(poller.attach_by_correlation)
            poller.attach_purge_active = false
            @tp_warn "attach response cache purged"
        end
    end
    if poller.last_revoke !== nothing && poller.last_revoke.lease_id == state.lease_id
        state.revoked = true
        state.lease_id = UInt64(0)
        @tp_warn "driver lease revoked" lease_id = poller.last_revoke.lease_id reason = poller.last_revoke.reason
    end
    if poller.last_shutdown !== nothing
        state.shutdown = true
        @tp_warn "driver shutdown received" reason = poller.last_shutdown.reason
    end

    if state.lease_id != 0 && expired(state.keepalive_timer, now_ns)
        sent = send_keepalive!(
            state.keepalive_proxy;
            lease_id = state.lease_id,
            stream_id = state.stream_id,
            client_id = state.client_id,
            role = state.role,
            client_timestamp_ns = now_ns,
        )
        if sent
            reset!(state.keepalive_timer, now_ns)
            @tp_info "Driver keepalive sent" client_id = state.client_id role = state.role lease_id = state.lease_id stream_id =
                state.stream_id
            work_count += 1
        else
            @tp_warn "Driver keepalive failed" client_id = state.client_id role = state.role lease_id = state.lease_id stream_id =
                state.stream_id
            state.keepalive_failed = true
            state.revoked = true
            state.lease_id = UInt64(0)
        end
    end
    return work_count
end

"""
Poll once for an attach response with the given correlation id.

Arguments:
- `state`: driver client state.
- `correlation_id`: attach request correlation id.
- `now_ns`: current time in nanoseconds.

Returns:
- `AttachResponse` if received for the given id, otherwise `nothing`.
"""
function poll_attach!(
    state::DriverClientState,
    correlation_id::Int64,
    now_ns::UInt64,
)
    driver_client_do_work!(state, now_ns)
    attach = get(state.poller.attach_by_correlation, correlation_id, nothing)
    if attach !== nothing
        delete!(state.poller.attach_by_correlation, correlation_id)
        if isempty(state.poller.attach_by_correlation)
            state.poller.attach_purge_active = false
        end
        apply_attach!(state, attach)
        return attach
    end
    return nothing
end

"""
Poll for any attach response matching a list of correlation ids.

Arguments:
- `state`: driver client state.
- `correlation_ids`: pending correlation ids to match.
- `now_ns`: current time in nanoseconds.

Returns:
- `AttachResponse` for the first matching id, otherwise `nothing`.
"""
function poll_attach_any!(
    state::DriverClientState,
    correlation_ids::AbstractVector{Int64},
    now_ns::UInt64,
)
    driver_client_do_work!(state, now_ns)
    for correlation_id in correlation_ids
        attach = get(state.poller.attach_by_correlation, correlation_id, nothing)
        if attach !== nothing
            delete!(state.poller.attach_by_correlation, correlation_id)
            if isempty(state.poller.attach_by_correlation)
                state.poller.attach_purge_active = false
            end
            apply_attach!(state, attach)
            return attach
        end
    end
    return nothing
end

function poll_attach_any!(
    state::DriverClientState,
    correlation_id::Int64,
    now_ns::UInt64,
)
    return poll_attach_any!(state, (correlation_id,), now_ns)
end
