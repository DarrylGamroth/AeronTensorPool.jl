"""
Lookup or create stream state based on config and publishMode.
"""
function get_or_create_stream!(
    state::DriverState,
    stream_id::UInt32,
    publish_mode::DriverPublishMode.SbeEnum,
)
    stream_state = get(state.streams, stream_id, nothing)
    if !isnothing(stream_state)
        return stream_state
    end

    stream_config = nothing
    for entry in values(state.config.streams)
        if entry.stream_id == stream_id
            stream_config = entry
            break
        end
    end

    if isnothing(stream_config) && !state.config.policies.allow_dynamic_streams
        return nothing
    end
    if isnothing(stream_config)
        if publish_mode != DriverPublishMode.EXISTING_OR_CREATE
            return nothing
        end
        profile_name = state.config.policies.default_profile
    else
        profile_name = stream_config.profile
    end
    profile = get(state.config.profiles, profile_name, nothing)
    isnothing(profile) && return nothing

    stream_state = DriverStreamState(
        stream_id,
        profile,
        UInt64(0),
        "",
        Dict{UInt16, String}(),
        UInt64(0),
        Set{UInt64}(),
    )
    state.streams[stream_id] = stream_state
    return stream_state
end

function bump_epoch!(state::DriverState, stream_state::DriverStreamState)
    now_ns = UInt64(time_ns())
    if stream_state.epoch == 0
        stream_state.epoch = max(UInt64(1), now_ns)
    else
        stream_state.epoch = max(stream_state.epoch + 1, now_ns)
    end
    provision_stream_epoch!(state, stream_state)
    return nothing
end

function provision_stream_epoch!(state::DriverState, stream_state::DriverStreamState)
    pool_ids = [pool.pool_id for pool in stream_state.profile.payload_pools]
    header_uri, pool_uris = canonical_shm_paths(
        state.config.shm.base_dir,
        "stream-$(stream_state.stream_id)",
        state.config.endpoints.instance_id,
        stream_state.epoch,
        pool_ids,
    )
    if state.config.shm.require_hugepages
        header_uri = add_hugepage_flag(header_uri)
        for (pool_id, uri) in pool_uris
            pool_uris[pool_id] = add_hugepage_flag(uri)
        end
    end
    stream_state.header_uri = header_uri
    stream_state.pool_uris = pool_uris

    header_path = parse_shm_uri(header_uri).path
    header_size = SUPERBLOCK_SIZE + Int(stream_state.profile.header_nslots) * HEADER_SLOT_BYTES
    ensure_shm_file!(state, header_path, header_size, state.config.shm.permissions_mode)
    header_mmap = mmap_shm(header_uri, header_size; write = true)
    if state.config.policies.prefault_shm
        fill!(header_mmap, 0x00)
    end
    if state.config.policies.mlock_shm
        mlock_buffer!(header_mmap, "header")
    end
    wrap_superblock!(state.runtime.superblock_encoder, header_mmap, 0)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    write_superblock!(
        state.runtime.superblock_encoder,
        SuperblockFields(
            MAGIC_TPOLSHM1,
            UInt32(1),
            stream_state.epoch,
            stream_state.stream_id,
            RegionType.HEADER_RING,
            UInt16(0),
            stream_state.profile.header_nslots,
            UInt32(HEADER_SLOT_BYTES),
            UInt32(0),
            UInt64(getpid()),
            now_ns,
            now_ns,
        ),
    )

    for pool in stream_state.profile.payload_pools
        pool_uri = stream_state.pool_uris[pool.pool_id]
        pool_path = parse_shm_uri(pool_uri).path
        pool_size = SUPERBLOCK_SIZE + Int(stream_state.profile.header_nslots) * Int(pool.stride_bytes)
        ensure_shm_file!(state, pool_path, pool_size, state.config.shm.permissions_mode)
        pool_mmap = mmap_shm(pool_uri, pool_size; write = true)
        if state.config.policies.prefault_shm
            fill!(pool_mmap, 0x00)
        end
        if state.config.policies.mlock_shm
            mlock_buffer!(pool_mmap, "pool")
        end
        wrap_superblock!(state.runtime.superblock_encoder, pool_mmap, 0)
        write_superblock!(
            state.runtime.superblock_encoder,
            SuperblockFields(
                MAGIC_TPOLSHM1,
                UInt32(1),
                stream_state.epoch,
                stream_state.stream_id,
                RegionType.PAYLOAD_POOL,
                pool.pool_id,
                stream_state.profile.header_nslots,
                pool.stride_bytes,
                pool.stride_bytes,
                UInt64(getpid()),
                now_ns,
                now_ns,
            ),
        )
    end
    return nothing
end

function mlock_buffer!(buffer::AbstractVector{UInt8}, label::String)
    ptr = Ptr{UInt8}(pointer(buffer))
    res = Libc.mlock(ptr, length(buffer))
    res == 0 || throw(ArgumentError("mlock failed for $(label) (errno=$(Libc.errno()))"))
    return nothing
end

@inline function parse_mode(mode_str::String)
    return parse(UInt32, mode_str; base = 8)
end

function ensure_shm_file!(state::DriverState, path::String, size::Int, mode_str::String)
    isabspath(path) || throw(ArgumentError("SHM path must be absolute"))
    path_allowed(path, state.config.shm.allowed_base_dirs) ||
        throw(ArgumentError("SHM path not within allowed_base_dirs"))
    if state.config.shm.require_hugepages && !is_hugetlbfs_path(path)
        throw(ArgumentError("SHM path not on hugetlbfs"))
    end
    mkpath(dirname(path))
    if ispath(path) && !isfile(path)
        throw(ArgumentError("SHM path must be a regular file"))
    end
    open(path, "w+") do io
        truncate(io, size)
    end
    isfile(path) || throw(ArgumentError("SHM path not a regular file"))
    chmod(path, parse_mode(mode_str))
    return nothing
end

@inline function add_hugepage_flag(uri::String)
    return "$(uri)|require_hugepages=true"
end

function path_allowed(path::String, allowed_dirs::Vector{String})
    abs_path = abspath(path)
    abs_path = ispath(abs_path) ? realpath(abs_path) : abs_path
    for dir in allowed_dirs
        abs_dir = abspath(dir)
        abs_dir = ispath(abs_dir) ? realpath(abs_dir) : abs_dir
        if abs_path == abs_dir || startswith(abs_path, abs_dir * "/")
            return true
        end
    end
    return false
end
