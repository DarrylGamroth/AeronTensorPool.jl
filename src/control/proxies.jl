"""
Proxy for issuing ShmAttachRequest messages to the driver.
"""
mutable struct AttachRequestProxy
    pub::Aeron.Publication
    claim::Aeron.BufferClaim
    encoder::ShmAttachRequest.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

"""
Proxy for issuing ShmLeaseKeepalive messages to the driver.
"""
mutable struct KeepaliveProxy
    pub::Aeron.Publication
    claim::Aeron.BufferClaim
    encoder::ShmLeaseKeepalive.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

"""
Proxy for issuing ShmDetachRequest messages to the driver.
"""
mutable struct DetachRequestProxy
    pub::Aeron.Publication
    claim::Aeron.BufferClaim
    encoder::ShmDetachRequest.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

"""
Proxy for issuing ShmDriverShutdownRequest messages to the driver.
"""
mutable struct ShutdownRequestProxy
    pub::Aeron.Publication
    claim::Aeron.BufferClaim
    encoder::ShmDriverShutdownRequest.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

function AttachRequestProxy(pub::Aeron.Publication)
    return AttachRequestProxy(pub, Aeron.BufferClaim(), ShmAttachRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}))
end

function KeepaliveProxy(pub::Aeron.Publication)
    return KeepaliveProxy(pub, Aeron.BufferClaim(), ShmLeaseKeepalive.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}))
end

function DetachRequestProxy(pub::Aeron.Publication)
    return DetachRequestProxy(pub, Aeron.BufferClaim(), ShmDetachRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}))
end

function ShutdownRequestProxy(pub::Aeron.Publication)
    return ShutdownRequestProxy(
        pub,
        Aeron.BufferClaim(),
        ShmDriverShutdownRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
end

@inline hugepages_policy_value(value::DriverHugepagesPolicy.SbeEnum) = value

@inline hugepages_policy_value(value::Bool) =
    value ? DriverHugepagesPolicy.HUGEPAGES : DriverHugepagesPolicy.STANDARD

@inline hugepages_policy_value(::Nothing) = DriverHugepagesPolicy.UNSPECIFIED

"""
Send an attach request.

Arguments (keywords):
- `correlation_id`: correlation id for the request.
- `stream_id`: stream identifier to attach.
- `client_id`: client identifier.
- `role`: driver role enum.
- `expected_layout_version`: expected layout version (default: 0).
- `max_dims`: expected MAX_DIMS (default: 0).
- `publish_mode`: publish mode override (optional).
- `require_hugepages`: hugepage policy (optional).

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function send_attach!(
    proxy::AttachRequestProxy;
    correlation_id::Int64,
    stream_id::UInt32,
    client_id::UInt32,
    role::DriverRole.SbeEnum,
    expected_layout_version::UInt32 = UInt32(0),
    max_dims::UInt8 = UInt8(0),
    publish_mode::Union{DriverPublishMode.SbeEnum, Nothing} = nothing,
    require_hugepages::Union{DriverHugepagesPolicy.SbeEnum, Bool, Nothing} = nothing,
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN + Int(ShmAttachRequest.sbe_block_length(ShmAttachRequest.Decoder))
    return let p = proxy,
        correlation_id = correlation_id,
        stream_id = stream_id,
        client_id = client_id,
        role = role,
        expected_layout_version = expected_layout_version,
        max_dims = max_dims,
        publish_mode = publish_mode,
        require_hugepages = require_hugepages
        @tp_info "send_attach!" correlation_id stream_id client_id role expected_layout_version max_dims publish_mode require_hugepages
        with_claimed_buffer!(p.pub, p.claim, msg_len) do buf
            ShmAttachRequest.wrap_and_apply_header!(p.encoder, buf, 0)
            ShmAttachRequest.correlationId!(p.encoder, correlation_id)
            ShmAttachRequest.streamId!(p.encoder, stream_id)
            ShmAttachRequest.clientId!(p.encoder, client_id)
            ShmAttachRequest.role!(p.encoder, role)
            ShmAttachRequest.expectedLayoutVersion!(p.encoder, expected_layout_version)
            ShmAttachRequest.maxDims!(p.encoder, max_dims)

            if isnothing(publish_mode)
                ShmAttachRequest.publishMode!(p.encoder, DriverPublishMode.NULL_VALUE)
            else
                ShmAttachRequest.publishMode!(p.encoder, publish_mode)
            end

            ShmAttachRequest.requireHugepages!(p.encoder, hugepages_policy_value(require_hugepages))
        end
    end
end

"""
Send a lease keepalive.

Arguments (keywords):
- `lease_id`: lease identifier.
- `stream_id`: stream identifier.
- `client_id`: client identifier.
- `role`: driver role enum.
- `client_timestamp_ns`: client timestamp in nanoseconds.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function send_keepalive!(
    proxy::KeepaliveProxy;
    lease_id::UInt64,
    stream_id::UInt32,
    client_id::UInt32,
    role::DriverRole.SbeEnum,
    client_timestamp_ns::UInt64,
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN + Int(ShmLeaseKeepalive.sbe_block_length(ShmLeaseKeepalive.Decoder))
    return let p = proxy,
        lease_id = lease_id,
        stream_id = stream_id,
        client_id = client_id,
        role = role,
        client_timestamp_ns = client_timestamp_ns
        with_claimed_buffer!(p.pub, p.claim, msg_len) do buf
            ShmLeaseKeepalive.wrap_and_apply_header!(p.encoder, buf, 0)
            ShmLeaseKeepalive.leaseId!(p.encoder, lease_id)
            ShmLeaseKeepalive.streamId!(p.encoder, stream_id)
            ShmLeaseKeepalive.clientId!(p.encoder, client_id)
            ShmLeaseKeepalive.role!(p.encoder, role)
            ShmLeaseKeepalive.clientTimestampNs!(p.encoder, client_timestamp_ns)
        end
    end
end

"""
Send a detach request.

Arguments (keywords):
- `correlation_id`: correlation id for the request.
- `lease_id`: lease identifier.
- `stream_id`: stream identifier.
- `client_id`: client identifier.
- `role`: driver role enum.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function send_detach!(
    proxy::DetachRequestProxy;
    correlation_id::Int64,
    lease_id::UInt64,
    stream_id::UInt32,
    client_id::UInt32,
    role::DriverRole.SbeEnum,
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN + Int(ShmDetachRequest.sbe_block_length(ShmDetachRequest.Decoder))
    return let p = proxy,
        correlation_id = correlation_id,
        lease_id = lease_id,
        stream_id = stream_id,
        client_id = client_id,
        role = role
        with_claimed_buffer!(p.pub, p.claim, msg_len) do buf
            ShmDetachRequest.wrap_and_apply_header!(p.encoder, buf, 0)
            ShmDetachRequest.correlationId!(p.encoder, correlation_id)
            ShmDetachRequest.leaseId!(p.encoder, lease_id)
            ShmDetachRequest.streamId!(p.encoder, stream_id)
            ShmDetachRequest.clientId!(p.encoder, client_id)
            ShmDetachRequest.role!(p.encoder, role)
        end
    end
end

"""
Send a shutdown request.

Arguments (keywords):
- `correlation_id`: correlation id for the request.
- `reason`: shutdown reason enum.
- `token`: shutdown token string.
- `error_message`: optional error message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function send_shutdown_request!(
    proxy::ShutdownRequestProxy;
    correlation_id::Int64,
    reason::DriverShutdownReason.SbeEnum,
    token::AbstractString,
    error_message::AbstractString = "",
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmDriverShutdownRequest.sbe_block_length(ShmDriverShutdownRequest.Decoder)) +
        ShmDriverShutdownRequest.token_header_length +
        sizeof(token) +
        ShmDriverShutdownRequest.errorMessage_header_length +
        sizeof(error_message)
    return let p = proxy,
        correlation_id = correlation_id,
        reason = reason,
        token = token,
        error_message = error_message
        with_claimed_buffer!(p.pub, p.claim, msg_len) do buf
            ShmDriverShutdownRequest.wrap_and_apply_header!(p.encoder, buf, 0)
            ShmDriverShutdownRequest.correlationId!(p.encoder, correlation_id)
            ShmDriverShutdownRequest.reason!(p.encoder, reason)
            ShmDriverShutdownRequest.token!(p.encoder, token)
            ShmDriverShutdownRequest.errorMessage!(p.encoder, error_message)
        end
    end
end
