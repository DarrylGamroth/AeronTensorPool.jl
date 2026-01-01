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

function AttachRequestProxy(pub::Aeron.Publication)
    return AttachRequestProxy(pub, Aeron.BufferClaim(), ShmAttachRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}))
end

function KeepaliveProxy(pub::Aeron.Publication)
    return KeepaliveProxy(pub, Aeron.BufferClaim(), ShmLeaseKeepalive.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}))
end

function DetachRequestProxy(pub::Aeron.Publication)
    return DetachRequestProxy(pub, Aeron.BufferClaim(), ShmDetachRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}))
end

@inline hugepages_policy_value(value::DriverHugepagesPolicy.SbeEnum) = value

@inline hugepages_policy_value(value::Bool) =
    value ? DriverHugepagesPolicy.HUGEPAGES : DriverHugepagesPolicy.STANDARD

@inline hugepages_policy_value(::Nothing) = DriverHugepagesPolicy.UNSPECIFIED

"""
Send an attach request.
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
    return try_claim_sbe!(proxy.pub, proxy.claim, msg_len) do buf
        ShmAttachRequest.wrap_and_apply_header!(proxy.encoder, buf, 0)
        ShmAttachRequest.correlationId!(proxy.encoder, correlation_id)
        ShmAttachRequest.streamId!(proxy.encoder, stream_id)
        ShmAttachRequest.clientId!(proxy.encoder, client_id)
        ShmAttachRequest.role!(proxy.encoder, role)
        ShmAttachRequest.expectedLayoutVersion!(proxy.encoder, expected_layout_version)
        ShmAttachRequest.maxDims!(proxy.encoder, max_dims)

        if isnothing(publish_mode)
            ShmAttachRequest.publishMode!(proxy.encoder, DriverPublishMode.NULL_VALUE)
        else
            ShmAttachRequest.publishMode!(proxy.encoder, publish_mode)
        end

        ShmAttachRequest.requireHugepages!(proxy.encoder, hugepages_policy_value(require_hugepages))
    end
end

"""
Send a lease keepalive.
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
    return try_claim_sbe!(proxy.pub, proxy.claim, msg_len) do buf
        ShmLeaseKeepalive.wrap_and_apply_header!(proxy.encoder, buf, 0)
        ShmLeaseKeepalive.leaseId!(proxy.encoder, lease_id)
        ShmLeaseKeepalive.streamId!(proxy.encoder, stream_id)
        ShmLeaseKeepalive.clientId!(proxy.encoder, client_id)
        ShmLeaseKeepalive.role!(proxy.encoder, role)
        ShmLeaseKeepalive.clientTimestampNs!(proxy.encoder, client_timestamp_ns)
    end
end

"""
Send a detach request.
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
    return try_claim_sbe!(proxy.pub, proxy.claim, msg_len) do buf
        ShmDetachRequest.wrap_and_apply_header!(proxy.encoder, buf, 0)
        ShmDetachRequest.correlationId!(proxy.encoder, correlation_id)
        ShmDetachRequest.leaseId!(proxy.encoder, lease_id)
        ShmDetachRequest.streamId!(proxy.encoder, stream_id)
        ShmDetachRequest.clientId!(proxy.encoder, client_id)
        ShmDetachRequest.role!(proxy.encoder, role)
    end
end
