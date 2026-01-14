"""
Return canonical allowed base directories for SHM containment checks.
"""
function canonical_allowed_dirs(base_dir::AbstractString, allowed_dirs::Vector{String})
    dirs = isempty(allowed_dirs) ? [base_dir] : allowed_dirs
    canonical = String[]
    for dir in dirs
        abs_dir = abspath(dir)
        ispath(abs_dir) || throw(ArgumentError("allowed_base_dir does not exist: $(abs_dir)"))
        abs_dir = realpath(abs_dir)
        push!(canonical, abs_dir)
    end
    return canonical
end

function path_allowed(path::AbstractString, allowed_dirs::Vector{String})
    abs_path = abspath(path)
    ispath(abs_path) || return false
    abs_path = realpath(abs_path)
    for dir in allowed_dirs
        if abs_path == dir || startswith(abs_path, dir * "/")
            return true
        end
    end
    return false
end

"""
Map SHM regions from a ShmPoolAnnounce message.

Arguments:
- `state`: consumer state.
- `msg`: decoded ShmPoolAnnounce message.

Returns:
- `true` on successful mapping, `false` otherwise.
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
    if !path_allowed(header_parsed.path, state.config.allowed_base_dirs)
        @tp_warn "announce header path not allowed" path = header_parsed.path
        return false
    end
    require_hugepages = header_parsed.require_hugepages || state.config.require_hugepages
    if require_hugepages && !is_hugetlbfs_path(header_parsed.path)
        return false
    end
    hugepage_size = require_hugepages ? hugepage_size_bytes() : 0
    require_hugepages && hugepage_size == 0 && return false
    header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(header_nslots))
    if state.config.mlock_shm
        mlock_buffer!(header_mmap, "consumer header")
    end

    sb_dec = state.runtime.superblock_decoder
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
        if !path_allowed(pool_parsed.path, state.config.allowed_base_dirs)
            @tp_warn "announce pool path not allowed" pool_id = pool.pool_id path = pool_parsed.path
            return false
        end
        pool_require_hugepages = pool_parsed.require_hugepages || require_hugepages
        if pool_require_hugepages && !is_hugetlbfs_path(pool_parsed.path)
            return false
        end
        validate_stride(pool.stride_bytes) || return false

        pool_mmap = mmap_shm(pool.uri, SUPERBLOCK_SIZE + Int(pool.nslots) * Int(pool.stride_bytes))
        if state.config.mlock_shm
            mlock_buffer!(pool_mmap, "consumer pool")
        end
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
    state.mappings.progress_last_frame = fill(UInt64(0), Int(header_nslots))
    state.mappings.progress_last_bytes = fill(UInt64(0), Int(header_nslots))
    state.mappings.mapped_epoch = ShmPoolAnnounce.epoch(msg)
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    state.metrics.remap_count += 1
    set_mapping_phase!(state, MAPPED)
    return true
end

"""
Map SHM regions from a driver attach response.

Arguments:
- `state`: consumer state.
- `attach`: attach response snapshot.

Returns:
- `true` on successful mapping, `false` otherwise.
"""
function map_from_attach_response!(state::ConsumerState, attach::AttachResponse)
    attach.code == DriverResponseCode.OK || return false
    if attach.lease_id == ShmAttachResponse.leaseId_null_value(ShmAttachResponse.Decoder) ||
       attach.stream_id == ShmAttachResponse.streamId_null_value(ShmAttachResponse.Decoder) ||
       attach.epoch == ShmAttachResponse.epoch_null_value(ShmAttachResponse.Decoder) ||
       attach.layout_version == ShmAttachResponse.layoutVersion_null_value(ShmAttachResponse.Decoder) ||
       attach.header_nslots == ShmAttachResponse.headerNslots_null_value(ShmAttachResponse.Decoder) ||
       attach.header_slot_bytes == ShmAttachResponse.headerSlotBytes_null_value(ShmAttachResponse.Decoder)
        @tp_warn "attach response missing required fields" stream_id = attach.stream_id
        return false
    end
    isempty(view(attach.header_region_uri)) && return false
    attach.pool_count > 0 || return false
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || return false
    @tp_info "consumer attach mapping" stream_id = attach.stream_id epoch = attach.epoch header_nslots =
        attach.header_nslots pool_count = attach.pool_count
    header_nslots = attach.header_nslots

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    stride_bytes = Dict{UInt16, UInt32}()

    header_uri = view(attach.header_region_uri)
    validate_uri(header_uri) || return false
    header_parsed = parse_shm_uri(header_uri)
    if !path_allowed(header_parsed.path, state.config.allowed_base_dirs)
        @tp_warn "attach header path not allowed" path = header_parsed.path
        return false
    end
    require_hugepages = state.config.require_hugepages
    if require_hugepages && !is_hugetlbfs_path(header_parsed.path)
        @tp_warn "attach header hugepage path invalid" path = header_parsed.path
        return false
    end
    hugepage_size = require_hugepages ? hugepage_size_bytes() : 0
    if require_hugepages && hugepage_size == 0
        @tp_warn "attach header hugepage size unavailable"
        return false
    end

    header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(header_nslots))
    if state.config.mlock_shm
        mlock_buffer!(header_mmap, "consumer header")
    end
    sb_dec = state.runtime.superblock_decoder
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
    if !header_ok
        @tp_warn "attach header superblock invalid" stream_id = attach.stream_id epoch = attach.epoch
        return false
    end

    for i in 1:attach.pool_count
        pool = attach.pools[i]
        pool.pool_nslots == header_nslots || return false
        pool_uri = view(pool.region_uri)
        validate_uri(pool_uri) || return false
        pool_parsed = parse_shm_uri(pool_uri)
        if !path_allowed(pool_parsed.path, state.config.allowed_base_dirs)
            @tp_warn "attach pool path not allowed" pool_id = pool.pool_id path = pool_parsed.path
            return false
        end
        pool_require_hugepages = pool_parsed.require_hugepages || require_hugepages
        if pool_require_hugepages && !is_hugetlbfs_path(pool_parsed.path)
            @tp_warn "attach pool hugepage path invalid" pool_id = pool.pool_id path = pool_parsed.path
            return false
        end
        validate_stride(pool.stride_bytes) || return false

        pool_mmap = mmap_shm(pool_uri, SUPERBLOCK_SIZE + Int(pool.pool_nslots) * Int(pool.stride_bytes))
        if state.config.mlock_shm
            mlock_buffer!(pool_mmap, "consumer pool")
        end
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
        if !pool_ok
            @tp_warn "attach pool superblock invalid" pool_id = pool.pool_id stride_bytes = pool.stride_bytes
            return false
        end

        payload_mmaps[pool.pool_id] = pool_mmap
        stride_bytes[pool.pool_id] = pool.stride_bytes
    end

    state.mappings.header_mmap = header_mmap
    state.mappings.payload_mmaps = payload_mmaps
    state.mappings.pool_stride_bytes = stride_bytes
    state.mappings.mapped_nslots = header_nslots
    state.mappings.mapped_pid = header_fields.pid
    state.mappings.last_commit_words = fill(UInt64(0), Int(header_nslots))
    state.mappings.progress_last_frame = fill(UInt64(0), Int(header_nslots))
    state.mappings.progress_last_bytes = fill(UInt64(0), Int(header_nslots))
    state.mappings.mapped_epoch = attach.epoch
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    state.metrics.remap_count += 1
    state.config.expected_layout_version = attach.layout_version
    set_mapping_phase!(state, MAPPED)
    @tp_info "consumer attach mapped" stream_id = attach.stream_id epoch = attach.epoch pools = attach.pool_count
    return true
end

function validate_mapped_superblocks!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    header_mmap = state.mappings.header_mmap
    header_mmap === nothing && return :mismatch

    expected_epoch = ShmPoolAnnounce.epoch(msg)
    sb_dec = state.runtime.superblock_decoder
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

Arguments:
- `state`: consumer state.

Returns:
- `nothing`.
"""
function reset_mappings!(state::ConsumerState)
    state.mappings.header_mmap = nothing
    empty!(state.mappings.payload_mmaps)
    empty!(state.mappings.pool_stride_bytes)
    state.mappings.mapped_nslots = UInt32(0)
    state.mappings.mapped_pid = UInt64(0)
    empty!(state.mappings.last_commit_words)
    empty!(state.mappings.progress_last_frame)
    empty!(state.mappings.progress_last_bytes)
    state.mappings.mapped_epoch = UInt64(0)
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    set_mapping_phase!(state, UNMAPPED)
    return nothing
end

"""
Handle ShmPoolAnnounce updates, remapping on epoch/layout changes.

Arguments:
- `state`: consumer state.
- `msg`: decoded ShmPoolAnnounce message.

Returns:
- `true` if handled, `false` otherwise.
"""
function handle_shm_pool_announce!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.config.stream_id || return false
    consumer_driver_active(state) || return false
    ShmPoolAnnounce.layoutVersion(msg) == state.config.expected_layout_version || return false
    announce_ts = ShmPoolAnnounce.announceTimestampNs(msg)
    clock_domain = ShmPoolAnnounce.announceClockDomain(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    if announce_ts == 0
        return false
    end
    @tp_info "consumer announce received" stream_id = ShmPoolAnnounce.streamId(msg) epoch =
        ShmPoolAnnounce.epoch(msg) layout_version = ShmPoolAnnounce.layoutVersion(msg) clock_domain = clock_domain

    if clock_domain == ClockDomain.MONOTONIC
        join_ns = state.announce_join_ns_ref[]
        if announce_ts + state.config.announce_freshness_ns < join_ns ||
           now_ns > announce_ts + state.config.announce_freshness_ns
            return false
        end
    elseif clock_domain == ClockDomain.REALTIME_SYNCED
        now_ns > announce_ts + state.config.announce_freshness_ns && return false
    else
        return false
    end

    if state.mappings.mapped_epoch != 0 && ShmPoolAnnounce.epoch(msg) != state.mappings.mapped_epoch
        @tp_warn "announce epoch change; remapping" old_epoch = state.mappings.mapped_epoch new_epoch =
            ShmPoolAnnounce.epoch(msg)
        reset_mappings!(state)
    end

    if state.mappings.header_mmap === nothing
        ok = map_from_announce!(state, msg)
        ok || @tp_warn "announce mapping failed" stream_id = ShmPoolAnnounce.streamId(msg) epoch =
            ShmPoolAnnounce.epoch(msg)
        if !ok && !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            set_mapping_phase!(state, FALLBACK)
            return true
        end
        ok && set_mapping_phase!(state, MAPPED)
        return ok
    end

    validation = validate_mapped_superblocks!(state, msg)
    if validation != :ok
        @tp_warn "announce validation failed" reason = validation
        reset_mappings!(state)
        if validation == :pid_changed
            return false
        end
        ok = map_from_announce!(state, msg)
        ok || @tp_warn "announce remap failed" stream_id = ShmPoolAnnounce.streamId(msg) epoch =
            ShmPoolAnnounce.epoch(msg)
        if !ok && !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            set_mapping_phase!(state, FALLBACK)
            return true
        end
        ok && set_mapping_phase!(state, MAPPED)
        return ok
    end
    return true
end
