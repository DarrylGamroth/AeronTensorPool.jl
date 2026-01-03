"""
Validate stride_bytes against alignment and hugepage requirements.
"""
function validate_stride(
    stride_bytes::UInt32;
    require_hugepages::Bool,
    page_size_bytes::Int = page_size_bytes(),
    hugepage_size::Int = 0,
)
    ispow2(stride_bytes) || return false
    (stride_bytes % UInt32(page_size_bytes)) == 0 || return false
    if require_hugepages
        hugepage_size > 0 || return false
        (stride_bytes % UInt32(hugepage_size)) == 0 || return false
    end
    return true
end

"""
Map SHM regions from a ShmPoolAnnounce message.
"""
function map_from_announce!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    state.config.use_shm || return false
    ShmPoolAnnounce.headerSlotBytes(msg) == UInt16(HEADER_SLOT_BYTES) || return false
    header_nslots = ShmPoolAnnounce.headerNslots(msg)

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    stride_bytes = Dict{UInt16, UInt32}()
    pool_specs = Vector{PayloadPoolConfig}()

    pools = ShmPoolAnnounce.payloadPools(msg)
    for pool in pools
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_nslots = ShmPoolAnnounce.PayloadPools.poolNslots(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_uri = String(ShmPoolAnnounce.PayloadPools.regionUri(pool))
        push!(pool_specs, PayloadPoolConfig(pool_id, pool_uri, pool_stride, pool_nslots))
    end
    header_uri = String(ShmPoolAnnounce.headerRegionUri(msg))
    validate_uri(header_uri) || return false
    header_parsed = parse_shm_uri(header_uri)
    require_hugepages = header_parsed.require_hugepages || state.config.require_hugepages
    if require_hugepages && !is_hugetlbfs_path(header_parsed.path)
        return false
    end
    hugepage_size = require_hugepages ? hugepage_size_bytes() : 0
    require_hugepages && hugepage_size == 0 && return false
    header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(header_nslots))

    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return false
    end

    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
        expected_epoch = ShmPoolAnnounce.epoch(msg),
        expected_stream_id = ShmPoolAnnounce.streamId(msg),
        expected_nslots = header_nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return false

    for pool in pool_specs
        pool.nslots == header_nslots || return false
        validate_uri(pool.uri) || return false
        pool_parsed = parse_shm_uri(pool.uri)
        pool_require_hugepages = pool_parsed.require_hugepages || require_hugepages
        if pool_require_hugepages && !is_hugetlbfs_path(pool_parsed.path)
            return false
        end
        validate_stride(
            pool.stride_bytes;
            require_hugepages = pool_require_hugepages,
            hugepage_size = hugepage_size,
        ) || return false

        pool_mmap = mmap_shm(pool.uri, SUPERBLOCK_SIZE + Int(pool.nslots) * Int(pool.stride_bytes))
        wrap_superblock!(sb_dec, pool_mmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return false
        end

        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
            expected_epoch = ShmPoolAnnounce.epoch(msg),
            expected_stream_id = ShmPoolAnnounce.streamId(msg),
            expected_nslots = pool.nslots,
            expected_slot_bytes = pool.stride_bytes,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool.pool_id,
        )
        pool_ok || return false

        payload_mmaps[pool.pool_id] = pool_mmap
        stride_bytes[pool.pool_id] = pool.stride_bytes
    end

    state.mappings.header_mmap = header_mmap
    state.mappings.payload_mmaps = payload_mmaps
    state.mappings.pool_stride_bytes = stride_bytes
    state.mappings.mapped_nslots = header_nslots
    state.mappings.mapped_pid = header_fields.pid
    state.mappings.last_commit_words = fill(UInt64(0), Int(header_nslots))
    state.mappings.mapped_epoch = ShmPoolAnnounce.epoch(msg)
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    state.metrics.remap_count += 1
    return true
end

"""
Map SHM regions from a driver attach response.
"""
function map_from_attach_response!(state::ConsumerState, attach::AttachResponseInfo)
    attach.code == DriverResponseCode.OK || return false
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || return false
    header_nslots = attach.header_nslots

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    stride_bytes = Dict{UInt16, UInt32}()

    header_uri = attach.header_region_uri
    validate_uri(header_uri) || return false
    header_parsed = parse_shm_uri(header_uri)
    require_hugepages = state.config.require_hugepages
    if require_hugepages && !is_hugetlbfs_path(header_parsed.path)
        return false
    end
    hugepage_size = require_hugepages ? hugepage_size_bytes() : 0
    require_hugepages && hugepage_size == 0 && return false

    header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(header_nslots))
    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return false
    end

    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = attach.layout_version,
        expected_epoch = attach.epoch,
        expected_stream_id = attach.stream_id,
        expected_nslots = header_nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return false

    for pool in attach.pools
        pool.pool_nslots == header_nslots || return false
        validate_uri(pool.region_uri) || return false
        pool_parsed = parse_shm_uri(pool.region_uri)
        pool_require_hugepages = pool_parsed.require_hugepages || require_hugepages
        if pool_require_hugepages && !is_hugetlbfs_path(pool_parsed.path)
            return false
        end
        validate_stride(
            pool.stride_bytes;
            require_hugepages = pool_require_hugepages,
            hugepage_size = hugepage_size,
        ) || return false

        pool_mmap =
            mmap_shm(pool.region_uri, SUPERBLOCK_SIZE + Int(pool.pool_nslots) * Int(pool.stride_bytes))
        wrap_superblock!(sb_dec, pool_mmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return false
        end
        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = attach.layout_version,
            expected_epoch = attach.epoch,
            expected_stream_id = attach.stream_id,
            expected_nslots = pool.pool_nslots,
            expected_slot_bytes = pool.stride_bytes,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool.pool_id,
        )
        pool_ok || return false

        payload_mmaps[pool.pool_id] = pool_mmap
        stride_bytes[pool.pool_id] = pool.stride_bytes
    end

    state.mappings.header_mmap = header_mmap
    state.mappings.payload_mmaps = payload_mmaps
    state.mappings.pool_stride_bytes = stride_bytes
    state.mappings.mapped_nslots = header_nslots
    state.mappings.mapped_pid = header_fields.pid
    state.mappings.last_commit_words = fill(UInt64(0), Int(header_nslots))
    state.mappings.mapped_epoch = attach.epoch
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    state.metrics.remap_count += 1
    state.config.expected_layout_version = attach.layout_version
    state.config.max_dims = attach.max_dims
    return true
end

function validate_mapped_superblocks!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    header_mmap = state.mappings.header_mmap
    header_mmap === nothing && return :mismatch

    expected_epoch = ShmPoolAnnounce.epoch(msg)
    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return :mismatch
    end

    header_expected_nslots = ShmPoolAnnounce.headerNslots(msg)
    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
        expected_epoch = expected_epoch,
        expected_stream_id = ShmPoolAnnounce.streamId(msg),
        expected_nslots = header_expected_nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return :mismatch
    if state.mappings.mapped_pid != 0 && header_fields.pid != state.mappings.mapped_pid
        return :pid_changed
    end

    pools = ShmPoolAnnounce.payloadPools(msg)
    pool_count = 0
    for pool in pools
        pool_count += 1
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_nslots = ShmPoolAnnounce.PayloadPools.poolNslots(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_mmap = get(state.mappings.payload_mmaps, pool_id, nothing)
        pool_mmap === nothing && return :mismatch

        wrap_superblock!(sb_dec, pool_mmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return :mismatch
        end

        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
            expected_epoch = expected_epoch,
            expected_stream_id = ShmPoolAnnounce.streamId(msg),
            expected_nslots = pool_nslots,
            expected_slot_bytes = pool_stride,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool_id,
        )
        pool_ok || return :mismatch
    end

    pool_count == length(state.mappings.payload_mmaps) || return :mismatch
    return :ok
end

"""
Drop all SHM mappings and reset mapping state.
"""
function reset_mappings!(state::ConsumerState)
    state.mappings.header_mmap = nothing
    empty!(state.mappings.payload_mmaps)
    empty!(state.mappings.pool_stride_bytes)
    state.mappings.mapped_nslots = UInt32(0)
    state.mappings.mapped_pid = UInt64(0)
    empty!(state.mappings.last_commit_words)
    state.mappings.mapped_epoch = UInt64(0)
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    return nothing
end

"""
Handle ShmPoolAnnounce updates, remapping on epoch/layout changes.
"""
function handle_shm_pool_announce!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.config.stream_id || return false
    consumer_driver_active(state) || return false
    ShmPoolAnnounce.layoutVersion(msg) == state.config.expected_layout_version || return false
    announce_ts = ShmPoolAnnounce.announceTimestampNs(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    if announce_ts == 0
        return false
    end
    if announce_ts + state.config.announce_freshness_ns < state.announce_join_ns ||
       now_ns > announce_ts + state.config.announce_freshness_ns
        return false
    end
    if ShmPoolAnnounce.maxDims(msg) != state.config.max_dims
        if !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            return true
        end
        return false
    end

    if state.mappings.mapped_epoch != 0 && ShmPoolAnnounce.epoch(msg) != state.mappings.mapped_epoch
        reset_mappings!(state)
    end

    if state.mappings.header_mmap === nothing
        ok = map_from_announce!(state, msg)
        if !ok && !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            return true
        end
        return ok
    end

    validation = validate_mapped_superblocks!(state, msg)
    if validation != :ok
        reset_mappings!(state)
        if validation == :pid_changed
            return false
        end
        ok = map_from_announce!(state, msg)
        if !ok && !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            return true
        end
        return ok
    end
    return true
end
