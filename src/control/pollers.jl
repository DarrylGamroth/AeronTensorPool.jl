"""
Abstract interface for control pollers.

Required methods:
- `poll!(poller, fragment_limit)`
- `close(poller)`

Optional:
- `rebind!(poller, channel, stream_id)`
"""
abstract type AbstractControlPoller end

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
    node_id::UInt32
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
mutable struct DriverResponsePoller <: AbstractControlPoller
    client::Aeron.Client
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
    attach_by_correlation::Dict{Int64, AttachResponse}
    attach_purge_timer::PolledTimer
    attach_purge_active::Bool
    attach_purge_touch::Bool
end

function DriverResponsePoller(sub::Aeron.Subscription)
    poller = DriverResponsePoller(
        sub.client,
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
        Dict{Int64, AttachResponse}(),
        PolledTimer(UInt64(0)),
        false,
        false,
    )
    sizehint!(poller.attach_by_correlation, 4)
    poller.assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(poller) do plr, buffer, _
        handle_driver_response!(plr, buffer)
        nothing
    end)
    return poller
end

function DriverResponsePoller(client::Aeron.Client, channel::AbstractString, stream_id::Int32)
    sub = Aeron.add_subscription(client, channel, stream_id)
    return DriverResponsePoller(sub)
end

"""
Poll responses and update the latest snapshot.

Arguments:
- `poller`: driver response poller.
- `fragment_limit`: max fragments to poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_driver_responses!(poller::DriverResponsePoller, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return poll!(poller, fragment_limit)
end

function handle_driver_response!(poller::DriverResponsePoller, buffer::AbstractVector{UInt8})
    header = DriverMessageHeader.Decoder(buffer, 0)
    if !matches_driver_schema(
        header,
        DriverMessageHeader.sbe_schema_id(DriverMessageHeader.Decoder),
        ShmAttachResponse.sbe_schema_version(ShmAttachResponse.Decoder),
    )
        return false
    end
    template_id = DriverMessageHeader.templateId(header)
    poller.last_template_id = template_id
    @tp_info "driver response" template_id
    if template_id == TEMPLATE_SHM_ATTACH_RESPONSE
        ShmAttachResponse.wrap!(poller.attach_decoder, buffer, 0; header = header)
        snapshot_attach_response!(poller.attach_response, poller.attach_decoder)
        @tp_info "attach response" correlation_id = poller.attach_response.correlation_id code =
            poller.attach_response.code lease_id = poller.attach_response.lease_id
        correlation_id = poller.attach_response.correlation_id
        entry = get!(poller.attach_by_correlation, correlation_id) do
            AttachResponse()
        end
        copy_attach_response!(entry, poller.attach_response)
        poller.last_attach = entry
        poller.attach_purge_touch = true
    elseif template_id == TEMPLATE_SHM_DETACH_RESPONSE
        ShmDetachResponse.wrap!(poller.detach_decoder, buffer, 0; header = header)
        snapshot_detach_response!(poller.detach_response, poller.detach_decoder)
        @tp_info "detach response" correlation_id = poller.detach_response.correlation_id code =
            poller.detach_response.code
        poller.last_detach = poller.detach_response
    elseif template_id == TEMPLATE_SHM_LEASE_REVOKED
        ShmLeaseRevoked.wrap!(poller.revoke_decoder, buffer, 0; header = header)
        snapshot_lease_revoked!(poller.revoke_response, poller.revoke_decoder)
        @tp_warn "lease revoked" lease_id = poller.revoke_response.lease_id reason =
            poller.revoke_response.reason
        poller.last_revoke = poller.revoke_response
    elseif template_id == TEMPLATE_SHM_DRIVER_SHUTDOWN
        ShmDriverShutdown.wrap!(poller.shutdown_decoder, buffer, 0; header = header)
        snapshot_shutdown!(poller.shutdown_response, poller.shutdown_decoder)
        @tp_warn "driver shutdown" reason = poller.shutdown_response.reason
        poller.last_shutdown = poller.shutdown_response
    end
    return true
end

function DriverPool()
    return DriverPool(UInt16(0), UInt32(0), UInt32(0), FixedString(DRIVER_URI_MAX_BYTES))
end

function AttachResponse()
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
        ShmAttachResponse.nodeId_null_value(ShmAttachResponse.Decoder),
        FixedString(DRIVER_URI_MAX_BYTES),
        DriverPool[],
        0,
        FixedString(DRIVER_ERROR_MAX_BYTES),
    )
end

function DetachResponse()
    return DetachResponse(
        Int64(0),
        DriverResponseCode.NULL_VALUE,
        FixedString(DRIVER_ERROR_MAX_BYTES),
    )
end

function LeaseRevoked()
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

function DriverShutdown()
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
    resp.node_id = ShmAttachResponse.nodeId(msg)

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

    copyto!(resp.header_region_uri, ShmAttachResponse.headerRegionUri(msg, StringView))
    copyto!(resp.error_message, ShmAttachResponse.errorMessage(msg, StringView))
    return resp
end

function copy_attach_response!(dst::AttachResponse, src::AttachResponse)
    dst.correlation_id = src.correlation_id
    dst.code = src.code
    dst.lease_id = src.lease_id
    dst.lease_expiry_ns = src.lease_expiry_ns
    dst.stream_id = src.stream_id
    dst.epoch = src.epoch
    dst.layout_version = src.layout_version
    dst.header_nslots = src.header_nslots
    dst.header_slot_bytes = src.header_slot_bytes
    dst.node_id = src.node_id
    copyto!(dst.header_region_uri, view(src.header_region_uri))
    dst.pool_count = src.pool_count
    ensure_pool_capacity!(dst.pools, src.pool_count)
    for i in 1:src.pool_count
        src_pool = src.pools[i]
        dst_pool = dst.pools[i]
        dst_pool.pool_id = src_pool.pool_id
        dst_pool.pool_nslots = src_pool.pool_nslots
        dst_pool.stride_bytes = src_pool.stride_bytes
        copyto!(dst_pool.region_uri, view(src_pool.region_uri))
    end
    copyto!(dst.error_message, view(src.error_message))
    return dst
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
