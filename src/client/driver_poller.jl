"""
Snapshot of a payload pool from ShmAttachResponse.
"""
struct DriverPoolInfo
    pool_id::UInt16
    pool_nslots::UInt32
    stride_bytes::UInt32
    region_uri::String
end

"""
Snapshot of a ShmAttachResponse.
"""
struct AttachResponseInfo
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
    header_region_uri::String
    pools::Vector{DriverPoolInfo}
    error_message::String
end

"""
Snapshot of a ShmDetachResponse.
"""
struct DetachResponseInfo
    correlation_id::Int64
    code::DriverResponseCode.SbeEnum
    error_message::String
end

"""
Snapshot of a ShmLeaseRevoked.
"""
struct LeaseRevokedInfo
    timestamp_ns::UInt64
    lease_id::UInt64
    stream_id::UInt32
    client_id::UInt32
    role::DriverRole.SbeEnum
    reason::DriverLeaseRevokeReason.SbeEnum
    error_message::String
end

"""
Snapshot of a ShmDriverShutdown.
"""
struct DriverShutdownInfo
    timestamp_ns::UInt64
    reason::DriverShutdownReason.SbeEnum
    error_message::String
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
    last_attach::Union{AttachResponseInfo, Nothing}
    last_detach::Union{DetachResponseInfo, Nothing}
    last_revoke::Union{LeaseRevokedInfo, Nothing}
    last_shutdown::Union{DriverShutdownInfo, Nothing}
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
        poller.last_attach = snapshot_attach_response(poller.attach_decoder)
    elseif template_id == TEMPLATE_SHM_DETACH_RESPONSE
        ShmDetachResponse.wrap!(poller.detach_decoder, buffer, 0; header = header)
        poller.last_detach = snapshot_detach_response(poller.detach_decoder)
    elseif template_id == TEMPLATE_SHM_LEASE_REVOKED
        ShmLeaseRevoked.wrap!(poller.revoke_decoder, buffer, 0; header = header)
        poller.last_revoke = snapshot_lease_revoked(poller.revoke_decoder)
    elseif template_id == TEMPLATE_SHM_DRIVER_SHUTDOWN
        ShmDriverShutdown.wrap!(poller.shutdown_decoder, buffer, 0; header = header)
        poller.last_shutdown = snapshot_shutdown(poller.shutdown_decoder)
    end
    return true
end

function snapshot_attach_response(msg::ShmAttachResponse.Decoder)
    pools = DriverPoolInfo[]
    for group in ShmAttachResponse.payloadPools(msg)
        pool_id = ShmAttachResponse.PayloadPools.poolId(group)
        pool_nslots = ShmAttachResponse.PayloadPools.poolNslots(group)
        stride_bytes = ShmAttachResponse.PayloadPools.strideBytes(group)
        region_uri = String(ShmAttachResponse.PayloadPools.regionUri(group))
        push!(pools, DriverPoolInfo(pool_id, pool_nslots, stride_bytes, region_uri))
    end
    header_uri = String(ShmAttachResponse.headerRegionUri(msg))
    error_message = String(ShmAttachResponse.errorMessage(msg))
    return AttachResponseInfo(
        ShmAttachResponse.correlationId(msg),
        ShmAttachResponse.code(msg),
        ShmAttachResponse.leaseId(msg),
        ShmAttachResponse.leaseExpiryTimestampNs(msg),
        ShmAttachResponse.streamId(msg),
        ShmAttachResponse.epoch(msg),
        ShmAttachResponse.layoutVersion(msg),
        ShmAttachResponse.headerNslots(msg),
        ShmAttachResponse.headerSlotBytes(msg),
        ShmAttachResponse.maxDims(msg),
        header_uri,
        pools,
        error_message,
    )
end

function snapshot_detach_response(msg::ShmDetachResponse.Decoder)
    return DetachResponseInfo(
        ShmDetachResponse.correlationId(msg),
        ShmDetachResponse.code(msg),
        String(ShmDetachResponse.errorMessage(msg)),
    )
end

function snapshot_lease_revoked(msg::ShmLeaseRevoked.Decoder)
    return LeaseRevokedInfo(
        ShmLeaseRevoked.timestampNs(msg),
        ShmLeaseRevoked.leaseId(msg),
        ShmLeaseRevoked.streamId(msg),
        ShmLeaseRevoked.clientId(msg),
        ShmLeaseRevoked.role(msg),
        ShmLeaseRevoked.reason(msg),
        String(ShmLeaseRevoked.errorMessage(msg)),
    )
end

function snapshot_shutdown(msg::ShmDriverShutdown.Decoder)
    return DriverShutdownInfo(
        ShmDriverShutdown.timestampNs(msg),
        ShmDriverShutdown.reason(msg),
        String(ShmDriverShutdown.errorMessage(msg)),
    )
end
