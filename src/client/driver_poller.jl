"""
Reference to string bytes stored in a stable arena buffer.
"""
struct StringRef
    buf::Vector{UInt8}
    offset::Int
    len::Int
end

"""
Simple arena for storing string bytes for driver response snapshots.
"""
mutable struct StringArena
    buf::Vector{UInt8}
    pos::Int
end

const DRIVER_STRING_ARENA_BYTES = 65536

@inline function StringArena(capacity::Int)
    return StringArena(Vector{UInt8}(undef, capacity), 0)
end

@inline function arena_reserve!(arena::StringArena, total::Int)
    total <= length(arena.buf) || throw(ArgumentError("string arena too small"))
    if arena.pos + total > length(arena.buf)
        arena.pos = 0
        return true
    end
    return false
end

@inline function arena_store!(arena::StringArena, s::AbstractString)
    len = ncodeunits(s)
    if len == 0
        return StringRef(arena.buf, arena.pos, 0)
    end
    copyto!(arena.buf, arena.pos + 1, codeunits(s), 1, len)
    ref = StringRef(arena.buf, arena.pos, len)
    arena.pos += len
    return ref
end

@inline function string_ref_view(ref::StringRef)
    if ref.len == 0
        return StringView("")
    end
    return StringView(view(ref.buf, ref.offset + 1:ref.offset + ref.len))
end

@inline function string_ref_string(ref::StringRef)
    return String(string_ref_view(ref))
end

"""
View of a payload pool from ShmAttachResponse (arena-backed).
"""
struct DriverPoolView
    pool_id::UInt16
    pool_nslots::UInt32
    stride_bytes::UInt32
    region_uri::StringRef
end

"""
View of a ShmAttachResponse (arena-backed).
"""
struct AttachResponseView
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
    header_region_uri::StringRef
    pools::Vector{DriverPoolView}
    error_message::StringRef
    generation::UInt64
end

"""
View of a ShmDetachResponse (arena-backed).
"""
struct DetachResponseView
    correlation_id::Int64
    code::DriverResponseCode.SbeEnum
    error_message::StringRef
    generation::UInt64
end

"""
View of a ShmLeaseRevoked (arena-backed).
"""
struct LeaseRevokedView
    timestamp_ns::UInt64
    lease_id::UInt64
    stream_id::UInt32
    client_id::UInt32
    role::DriverRole.SbeEnum
    reason::DriverLeaseRevokeReason.SbeEnum
    error_message::StringRef
    generation::UInt64
end

"""
View of a ShmDriverShutdown (arena-backed).
"""
struct DriverShutdownView
    timestamp_ns::UInt64
    reason::DriverShutdownReason.SbeEnum
    error_message::StringRef
    generation::UInt64
end

"""
Snapshot of a payload pool from ShmAttachResponse (owned).
"""
struct DriverPoolInfo
    pool_id::UInt16
    pool_nslots::UInt32
    stride_bytes::UInt32
    region_uri::String
end

"""
Snapshot of a ShmAttachResponse (owned).
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
Snapshot of a ShmDetachResponse (owned).
"""
struct DetachResponseInfo
    correlation_id::Int64
    code::DriverResponseCode.SbeEnum
    error_message::String
end

"""
Snapshot of a ShmLeaseRevoked (owned).
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
Snapshot of a ShmDriverShutdown (owned).
"""
struct DriverShutdownInfo
    timestamp_ns::UInt64
    reason::DriverShutdownReason.SbeEnum
    error_message::String
end

@inline function require_generation(view_generation::UInt64, current_generation::UInt64)
    view_generation == current_generation ||
        throw(ArgumentError("stale driver response view (generation mismatch)"))
    return nothing
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
    arena::StringArena
    generation::UInt64
    last_template_id::UInt16
    last_attach::Union{AttachResponseView, Nothing}
    last_detach::Union{DetachResponseView, Nothing}
    last_revoke::Union{LeaseRevokedView, Nothing}
    last_shutdown::Union{DriverShutdownView, Nothing}
end

"""
DriverResponsePoller stores string fields in a ring-style arena buffer.

StringRef values are only valid until the arena is overwritten by subsequent
responses; use materialize(poller) to obtain owned strings when you need to
retain them beyond the current polling cadence.
"""
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
        StringArena(DRIVER_STRING_ARENA_BYTES),
        UInt64(0),
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
        poller.last_attach = snapshot_attach_response(poller.attach_decoder, poller)
    elseif template_id == TEMPLATE_SHM_DETACH_RESPONSE
        ShmDetachResponse.wrap!(poller.detach_decoder, buffer, 0; header = header)
        poller.last_detach = snapshot_detach_response(poller.detach_decoder, poller)
    elseif template_id == TEMPLATE_SHM_LEASE_REVOKED
        ShmLeaseRevoked.wrap!(poller.revoke_decoder, buffer, 0; header = header)
        poller.last_revoke = snapshot_lease_revoked(poller.revoke_decoder, poller)
    elseif template_id == TEMPLATE_SHM_DRIVER_SHUTDOWN
        ShmDriverShutdown.wrap!(poller.shutdown_decoder, buffer, 0; header = header)
        poller.last_shutdown = snapshot_shutdown(poller.shutdown_decoder, poller)
    end
    return true
end

function snapshot_attach_response(msg::ShmAttachResponse.Decoder, poller::DriverResponsePoller)
    arena = poller.arena
    header_uri = ShmAttachResponse.headerRegionUri(msg, StringView)
    payload_groups = ShmAttachResponse.payloadPools(msg)
    total = ncodeunits(header_uri)
    for group in payload_groups
        total += ncodeunits(ShmAttachResponse.PayloadPools.regionUri(group, StringView))
    end
    error_message = ShmAttachResponse.errorMessage(msg, StringView)
    total += ncodeunits(error_message)
    if arena_reserve!(arena, total)
        poller.generation += 1
    end

    ShmAttachResponse.sbe_rewind!(msg)
    header_uri = ShmAttachResponse.headerRegionUri(msg, StringView)
    header_ref = arena_store!(arena, header_uri)
    payload_groups = ShmAttachResponse.payloadPools(msg)
    pools = DriverPoolView[]
    for group in payload_groups
        pool_id = ShmAttachResponse.PayloadPools.poolId(group)
        pool_nslots = ShmAttachResponse.PayloadPools.poolNslots(group)
        stride_bytes = ShmAttachResponse.PayloadPools.strideBytes(group)
        region_uri = arena_store!(arena, ShmAttachResponse.PayloadPools.regionUri(group, StringView))
        push!(pools, DriverPoolView(pool_id, pool_nslots, stride_bytes, region_uri))
    end
    error_message = ShmAttachResponse.errorMessage(msg, StringView)
    error_ref = arena_store!(arena, error_message)
    return AttachResponseView(
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
        header_ref,
        pools,
        error_ref,
        poller.generation,
    )
end

function snapshot_detach_response(msg::ShmDetachResponse.Decoder, poller::DriverResponsePoller)
    arena = poller.arena
    error_message = ShmDetachResponse.errorMessage(msg, StringView)
    if arena_reserve!(arena, ncodeunits(error_message))
        poller.generation += 1
    end
    error_ref = arena_store!(arena, error_message)
    return DetachResponseView(
        ShmDetachResponse.correlationId(msg),
        ShmDetachResponse.code(msg),
        error_ref,
        poller.generation,
    )
end

function snapshot_lease_revoked(msg::ShmLeaseRevoked.Decoder, poller::DriverResponsePoller)
    arena = poller.arena
    error_message = ShmLeaseRevoked.errorMessage(msg, StringView)
    if arena_reserve!(arena, ncodeunits(error_message))
        poller.generation += 1
    end
    error_ref = arena_store!(arena, error_message)
    return LeaseRevokedView(
        ShmLeaseRevoked.timestampNs(msg),
        ShmLeaseRevoked.leaseId(msg),
        ShmLeaseRevoked.streamId(msg),
        ShmLeaseRevoked.clientId(msg),
        ShmLeaseRevoked.role(msg),
        ShmLeaseRevoked.reason(msg),
        error_ref,
        poller.generation,
    )
end

function snapshot_shutdown(msg::ShmDriverShutdown.Decoder, poller::DriverResponsePoller)
    arena = poller.arena
    error_message = ShmDriverShutdown.errorMessage(msg, StringView)
    if arena_reserve!(arena, ncodeunits(error_message))
        poller.generation += 1
    end
    error_ref = arena_store!(arena, error_message)
    return DriverShutdownView(
        ShmDriverShutdown.timestampNs(msg),
        ShmDriverShutdown.reason(msg),
        error_ref,
        poller.generation,
    )
end

"""
Materialize a driver response view into owned strings.
"""
function materialize(view::AttachResponseView, poller::DriverResponsePoller)
    require_generation(view.generation, poller.generation)
    pools = DriverPoolInfo[]
    for pool in view.pools
        push!(
            pools,
            DriverPoolInfo(
                pool.pool_id,
                pool.pool_nslots,
                pool.stride_bytes,
                string_ref_string(pool.region_uri),
            ),
        )
    end
    return AttachResponseInfo(
        view.correlation_id,
        view.code,
        view.lease_id,
        view.lease_expiry_ns,
        view.stream_id,
        view.epoch,
        view.layout_version,
        view.header_nslots,
        view.header_slot_bytes,
        view.max_dims,
        string_ref_string(view.header_region_uri),
        pools,
        string_ref_string(view.error_message),
    )
end

function materialize(view::DetachResponseView, poller::DriverResponsePoller)
    require_generation(view.generation, poller.generation)
    return DetachResponseInfo(
        view.correlation_id,
        view.code,
        string_ref_string(view.error_message),
    )
end

function materialize(view::LeaseRevokedView, poller::DriverResponsePoller)
    require_generation(view.generation, poller.generation)
    return LeaseRevokedInfo(
        view.timestamp_ns,
        view.lease_id,
        view.stream_id,
        view.client_id,
        view.role,
        view.reason,
        string_ref_string(view.error_message),
    )
end

function materialize(view::DriverShutdownView, poller::DriverResponsePoller)
    require_generation(view.generation, poller.generation)
    return DriverShutdownInfo(
        view.timestamp_ns,
        view.reason,
        string_ref_string(view.error_message),
    )
end

"""
Materialize the most recent responses from a poller.
"""
function materialize(poller::DriverResponsePoller)
    return (
        attach = poller.last_attach === nothing ? nothing : materialize(poller.last_attach, poller),
        detach = poller.last_detach === nothing ? nothing : materialize(poller.last_detach, poller),
        revoke = poller.last_revoke === nothing ? nothing : materialize(poller.last_revoke, poller),
        shutdown = poller.last_shutdown === nothing ? nothing : materialize(poller.last_shutdown, poller),
    )
end
