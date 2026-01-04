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
    keepalive_timer::PolledTimer
    next_correlation_id::Int64
    revoked::Bool
    shutdown::Bool
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
)
    pub = Aeron.add_publication(client, control_channel, control_stream_id)
    sub = Aeron.add_subscription(client, control_channel, control_stream_id)
    return DriverClientState(
        pub,
        sub,
        AttachRequestProxy(pub),
        KeepaliveProxy(pub),
        DetachRequestProxy(pub),
        DriverResponsePoller(sub),
        client_id,
        role,
        UInt64(0),
        UInt32(0),
        PolledTimer(keepalive_interval_ns),
        (Int64(client_id) << 32) + 1,
        false,
        false,
    )
end

"""
Return the next correlation id for control-plane requests.

Arguments:
- `state`: driver client state.

Returns:
- Correlation id (Int64).
"""
@inline function next_correlation_id!(state::DriverClientState)
    cid = state.next_correlation_id
    state.next_correlation_id += 1
    return cid
end

"""
Send an attach request and return the correlation id.

Arguments (keywords):
- `stream_id`: stream identifier to attach.
- `expected_layout_version`: expected layout version (default: 0).
- `max_dims`: expected MAX_DIMS (default: 0).
- `publish_mode`: publish mode override (optional).
- `require_hugepages`: hugepage policy (optional).

Returns:
- Correlation id (Int64) on send success, or 0 on failure.
"""
function send_attach_request!(
    state::DriverClientState;
    stream_id::UInt32,
    expected_layout_version::UInt32 = UInt32(0),
    max_dims::UInt8 = UInt8(0),
    publish_mode::Union{DriverPublishMode.SbeEnum, Nothing} = nothing,
    require_hugepages::Union{DriverHugepagesPolicy.SbeEnum, Bool, Nothing} = nothing,
)
    correlation_id = next_correlation_id!(state)
    sent = send_attach!(
        state.attach_proxy;
        correlation_id = correlation_id,
        stream_id = stream_id,
        client_id = state.client_id,
        role = state.role,
        expected_layout_version = expected_layout_version,
        max_dims = max_dims,
        publish_mode = publish_mode,
        require_hugepages = require_hugepages,
    )
    sent || return Int64(0)
    return correlation_id
end

"""
Apply a successful attach response to the client state.
"""
@inline function apply_attach!(state::DriverClientState, attach::AttachResponse)
    if attach.code == DriverResponseCode.OK
        state.lease_id = attach.lease_id
        state.stream_id = attach.stream_id
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
    work_count = poll_driver_responses!(state.poller)
    if state.poller.last_revoke !== nothing && state.poller.last_revoke.lease_id == state.lease_id
        state.revoked = true
        state.lease_id = UInt64(0)
    end
    if state.poller.last_shutdown !== nothing
        state.shutdown = true
    end

    if state.lease_id != 0 && due!(state.keepalive_timer, now_ns)
        send_keepalive!(
            state.keepalive_proxy;
            lease_id = state.lease_id,
            stream_id = state.stream_id,
            client_id = state.client_id,
            role = state.role,
            client_timestamp_ns = now_ns,
        ) && (work_count += 1)
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
    attach = state.poller.last_attach
    if attach !== nothing && attach.correlation_id == correlation_id
        apply_attach!(state, attach)
        return attach
    end
    return nothing
end
