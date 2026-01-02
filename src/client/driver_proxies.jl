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
    return let p = proxy,
        correlation_id = correlation_id,
        stream_id = stream_id,
        client_id = client_id,
        role = role,
        expected_layout_version = expected_layout_version,
        max_dims = max_dims,
        publish_mode = publish_mode,
        require_hugepages = require_hugepages
        try_claim_sbe!(p.pub, p.claim, msg_len) do buf
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
        try_claim_sbe!(p.pub, p.claim, msg_len) do buf
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
        try_claim_sbe!(p.pub, p.claim, msg_len) do buf
            ShmDetachRequest.wrap_and_apply_header!(p.encoder, buf, 0)
            ShmDetachRequest.correlationId!(p.encoder, correlation_id)
            ShmDetachRequest.leaseId!(p.encoder, lease_id)
            ShmDetachRequest.streamId!(p.encoder, stream_id)
            ShmDetachRequest.clientId!(p.encoder, client_id)
            ShmDetachRequest.role!(p.encoder, role)
        end
    end
end
