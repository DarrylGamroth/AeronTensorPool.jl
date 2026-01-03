"""
Payload pool metadata from ShmAttachResponse.
"""
mutable struct DriverPool
    pool_id::UInt16
    pool_nslots::UInt32
    stride_bytes::UInt32
    region_uri::FixedString
end

"""
Snapshot of a ShmAttachResponse.
"""
mutable struct AttachResponse
    correlation_id::Int64
    code::DriverResponseCode.SbeEnum
    lease_id::UInt64
    lease_expiry_ns::UInt64
    stream_id::UInt32
    epoch::UInt64
    layout_version::UInt32
    header_nslots::UInt32
    header_slot_bytes::UInt16
    max_dims::UInt8
    header_region_uri::FixedString
    pools::Vector{DriverPool}
    pool_count::Int
    error_message::FixedString
end

"""
Snapshot of a ShmDetachResponse.
"""
mutable struct DetachResponse
    correlation_id::Int64
    code::DriverResponseCode.SbeEnum
    error_message::FixedString
end

"""
Snapshot of a ShmLeaseRevoked.
"""
mutable struct LeaseRevoked
    timestamp_ns::UInt64
    lease_id::UInt64
    stream_id::UInt32
    client_id::UInt32
    role::DriverRole.SbeEnum
    reason::DriverLeaseRevokeReason.SbeEnum
    error_message::FixedString
end

"""
Snapshot of a ShmDriverShutdown.
"""
mutable struct DriverShutdown
    timestamp_ns::UInt64
    reason::DriverShutdownReason.SbeEnum
    error_message::FixedString
end

"""
Poller for driver control-plane responses (Aeron-style).
"""
mutable struct DriverResponsePoller
    subscription::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    attach_decoder::ShmAttachResponse.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    detach_decoder::ShmDetachResponse.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    revoke_decoder::ShmLeaseRevoked.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    shutdown_decoder::ShmDriverShutdown.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    last_template_id::UInt16
    attach_response::AttachResponse
    detach_response::DetachResponse
    revoke_response::LeaseRevoked
    shutdown_response::DriverShutdown
    last_attach::Union{AttachResponse, Nothing}
    last_detach::Union{DetachResponse, Nothing}
    last_revoke::Union{LeaseRevoked, Nothing}
    last_shutdown::Union{DriverShutdown, Nothing}
end

function DriverResponsePoller(sub::Aeron.Subscription)
    poller = DriverResponsePoller(
        sub,
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, _, _
            nothing
        end),
        ShmAttachResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDetachResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmLeaseRevoked.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDriverShutdown.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        UInt16(0),
        AttachResponse(),
        DetachResponse(),
        LeaseRevoked(),
        DriverShutdown(),
        nothing,
        nothing,
        nothing,
        nothing,
    )
    poller.assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(poller) do plr, buffer, _
        handle_driver_response!(plr, buffer)
        nothing
    end)
    return poller
end

"""
Poll responses and update the latest snapshot.
"""
function poll_driver_responses!(poller::DriverResponsePoller, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(poller.subscription, poller.assembler, fragment_limit)
end

function handle_driver_response!(poller::DriverResponsePoller, buffer::AbstractVector{UInt8})
    header = DriverMessageHeader.Decoder(buffer, 0)
    template_id = DriverMessageHeader.templateId(header)
    poller.last_template_id = template_id

    if template_id == TEMPLATE_SHM_ATTACH_RESPONSE
        ShmAttachResponse.wrap!(poller.attach_decoder, buffer, 0; header = header)
        snapshot_attach_response!(poller.attach_response, poller.attach_decoder)
        poller.last_attach = poller.attach_response
    elseif template_id == TEMPLATE_SHM_DETACH_RESPONSE
        ShmDetachResponse.wrap!(poller.detach_decoder, buffer, 0; header = header)
        snapshot_detach_response!(poller.detach_response, poller.detach_decoder)
        poller.last_detach = poller.detach_response
    elseif template_id == TEMPLATE_SHM_LEASE_REVOKED
        ShmLeaseRevoked.wrap!(poller.revoke_decoder, buffer, 0; header = header)
        snapshot_lease_revoked!(poller.revoke_response, poller.revoke_decoder)
        poller.last_revoke = poller.revoke_response
    elseif template_id == TEMPLATE_SHM_DRIVER_SHUTDOWN
        ShmDriverShutdown.wrap!(poller.shutdown_decoder, buffer, 0; header = header)
        snapshot_shutdown!(poller.shutdown_response, poller.shutdown_decoder)
        poller.last_shutdown = poller.shutdown_response
    end
    return true
end

@inline function DriverPool()
    return DriverPool(UInt16(0), UInt32(0), UInt32(0), FixedString(DRIVER_URI_MAX_BYTES))
end

@inline function AttachResponse()
    return AttachResponse(
        Int64(0),
        DriverResponseCode.NULL_VALUE,
        UInt64(0),
        UInt64(0),
        UInt32(0),
        UInt64(0),
        UInt32(0),
        UInt32(0),
        UInt16(0),
        UInt8(0),
        FixedString(DRIVER_URI_MAX_BYTES),
        DriverPool[],
        0,
        FixedString(DRIVER_ERROR_MAX_BYTES),
    )
end

@inline function DetachResponse()
    return DetachResponse(
        Int64(0),
        DriverResponseCode.NULL_VALUE,
        FixedString(DRIVER_ERROR_MAX_BYTES),
    )
end

@inline function LeaseRevoked()
    return LeaseRevoked(
        UInt64(0),
        UInt64(0),
        UInt32(0),
        UInt32(0),
        DriverRole.NULL_VALUE,
        DriverLeaseRevokeReason.NULL_VALUE,
        FixedString(DRIVER_ERROR_MAX_BYTES),
    )
end

@inline function DriverShutdown()
    return DriverShutdown(
        UInt64(0),
        DriverShutdownReason.NULL_VALUE,
        FixedString(DRIVER_ERROR_MAX_BYTES),
    )
end

function ensure_pool_capacity!(pools::Vector{DriverPool}, count::Int)
    while length(pools) < count
        push!(pools, DriverPool())
    end
    return nothing
end

function snapshot_attach_response!(resp::AttachResponse, msg::ShmAttachResponse.Decoder)
    resp.correlation_id = ShmAttachResponse.correlationId(msg)
    resp.code = ShmAttachResponse.code(msg)
    resp.lease_id = ShmAttachResponse.leaseId(msg)
    resp.lease_expiry_ns = ShmAttachResponse.leaseExpiryTimestampNs(msg)
    resp.stream_id = ShmAttachResponse.streamId(msg)
    resp.epoch = ShmAttachResponse.epoch(msg)
    resp.layout_version = ShmAttachResponse.layoutVersion(msg)
    resp.header_nslots = ShmAttachResponse.headerNslots(msg)
    resp.header_slot_bytes = ShmAttachResponse.headerSlotBytes(msg)
    resp.max_dims = ShmAttachResponse.maxDims(msg)

    copyto!(resp.header_region_uri, ShmAttachResponse.headerRegionUri(msg, StringView))
    payload_groups = ShmAttachResponse.payloadPools(msg)
    pool_count = 0
    for group in payload_groups
        pool_count += 1
        ensure_pool_capacity!(resp.pools, pool_count)
        pool = resp.pools[pool_count]
        pool.pool_id = ShmAttachResponse.PayloadPools.poolId(group)
        pool.pool_nslots = ShmAttachResponse.PayloadPools.poolNslots(group)
        pool.stride_bytes = ShmAttachResponse.PayloadPools.strideBytes(group)
        copyto!(
            pool.region_uri,
            ShmAttachResponse.PayloadPools.regionUri(group, StringView),
        )
    end
    resp.pool_count = pool_count

    copyto!(resp.error_message, ShmAttachResponse.errorMessage(msg, StringView))
    return resp
end

function snapshot_detach_response!(resp::DetachResponse, msg::ShmDetachResponse.Decoder)
    resp.correlation_id = ShmDetachResponse.correlationId(msg)
    resp.code = ShmDetachResponse.code(msg)
    copyto!(resp.error_message, ShmDetachResponse.errorMessage(msg, StringView))
    return resp
end

function snapshot_lease_revoked!(resp::LeaseRevoked, msg::ShmLeaseRevoked.Decoder)
    resp.timestamp_ns = ShmLeaseRevoked.timestampNs(msg)
    resp.lease_id = ShmLeaseRevoked.leaseId(msg)
    resp.stream_id = ShmLeaseRevoked.streamId(msg)
    resp.client_id = ShmLeaseRevoked.clientId(msg)
    resp.role = ShmLeaseRevoked.role(msg)
    resp.reason = ShmLeaseRevoked.reason(msg)
    copyto!(resp.error_message, ShmLeaseRevoked.errorMessage(msg, StringView))
    return resp
end

function snapshot_shutdown!(resp::DriverShutdown, msg::ShmDriverShutdown.Decoder)
    resp.timestamp_ns = ShmDriverShutdown.timestampNs(msg)
    resp.reason = ShmDriverShutdown.reason(msg)
    copyto!(resp.error_message, ShmDriverShutdown.errorMessage(msg, StringView))
    return resp
end
