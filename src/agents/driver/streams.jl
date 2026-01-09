function range_contains(range::DriverStreamIdRange, value::UInt32)
    return value >= range.start_id && value <= range.end_id
end

function allocate_stream_id!(state::DriverState, range::DriverStreamIdRange)
    next_id = state.next_stream_id
    if next_id < range.start_id || next_id > range.end_id
        next_id = range.start_id
    end
    start_id = next_id
    while true
        if !haskey(state.streams, next_id)
            state.next_stream_id = next_id == range.end_id ? range.start_id : next_id + 1
            return next_id
        end
        next_id = next_id == range.end_id ? range.start_id : next_id + 1
        next_id == start_id && break
    end
    return UInt32(0)
end

function allocate_consumer_stream_id!(
    assigned::Dict{UInt32, UInt32},
    range::DriverStreamIdRange,
    next_id::UInt32,
)
    start_id = next_id
    if start_id < range.start_id || start_id > range.end_id
        start_id = range.start_id
    end
    candidate = start_id
    while true
        in_use = false
        for entry in values(assigned)
            if entry == candidate
                in_use = true
                break
            end
        end
        if !in_use
            next_id = candidate == range.end_id ? range.start_id : candidate + 1
            return candidate, next_id
        end
        candidate = candidate == range.end_id ? range.start_id : candidate + 1
        candidate == start_id && break
    end
    return UInt32(0), next_id
end

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
        return stream_state, :ok
    end

    stream_config = nothing
    for entry in values(state.config.streams)
        if entry.stream_id == stream_id
            stream_config = entry
            break
        end
    end

    if isnothing(stream_config)
        if !state.config.policies.allow_dynamic_streams
            return nothing, :not_provisioned
        end
        if publish_mode != DriverPublishMode.EXISTING_OR_CREATE
            return nothing, :not_provisioned
        end
        range = state.config.stream_id_range
        range === nothing && return nothing, :range_missing
        allocated_id = allocate_stream_id!(state, range)
        allocated_id == 0 && return nothing, :range_exhausted
        stream_id = allocated_id
        profile_name = state.config.policies.default_profile
    else
        profile_name = stream_config.profile
    end
    profile = get(state.config.profiles, profile_name, nothing)
    isnothing(profile) && return nothing, :profile_missing

    stream_state = DriverStreamState(
        stream_id,
        profile,
        UInt64(0),
        Dict{UInt64, UInt64}(),
        "",
        Dict{UInt16, String}(),
        UInt64(0),
        Set{UInt64}(),
    )
    state.streams[stream_id] = stream_state
    return stream_state, :ok
end

function bump_epoch!(state::DriverState, stream_state::DriverStreamState)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    if stream_state.epoch == 0
        stream_state.epoch = max(UInt64(1), now_ns)
    else
        stream_state.epoch = max(stream_state.epoch + 1, now_ns)
    end
    stream_state.epoch_start_ns[stream_state.epoch] = now_ns
    provision_stream_epoch!(state, stream_state)
    gc_stream_epochs!(state, stream_state, now_ns)
    return nothing
end

function parse_epoch_dirname(name::AbstractString)
    m = match(r"^epoch-(\d+)$", name)
    m === nothing && return nothing
    return tryparse(UInt64, m.captures[1])
end

function epoch_dir_age_ns(path::AbstractString, now_ns::UInt64, epoch_start_ns::Union{UInt64, Nothing})
    if epoch_start_ns !== nothing
        return now_ns > epoch_start_ns ? now_ns - epoch_start_ns : UInt64(0)
    end
    stat_info = stat(path)
    mtime_ns = UInt64(floor(stat_info.mtime * 1_000_000_000))
    return now_ns > mtime_ns ? now_ns - mtime_ns : UInt64(0)
end

function read_epoch_superblock(path::AbstractString)
    isfile(path) || return nothing
    buf = Vector{UInt8}(undef, SUPERBLOCK_SIZE)
    try
        open(path, "r") do io
            read!(io, buf)
        end
    catch
        return nothing
    end
    dec = ShmRegionSuperblock.Decoder(buf)
    wrap_superblock!(dec, buf, 0)
    try
        return read_superblock(dec)
    catch
        return nothing
    end
end

function pid_alive(pid::UInt64)
    pid == 0 && return false
    Sys.isunix() || return false
    res = Libc.kill(Cint(pid), 0)
    res == 0 && return true
    return Libc.errno() == Libc.EPERM
end

function gc_stream_epochs!(
    state::DriverState,
    stream_state::DriverStreamState,
    now_ns::UInt64;
    min_age_ns::Union{UInt64, Nothing} = nothing,
)
    policy = state.config.policies
    policy.epoch_gc_enabled || return 0
    keep = max(1, Int(policy.epoch_gc_keep))
    effective_min_age = min_age_ns === nothing ? policy.epoch_gc_min_age_ns : min_age_ns
    root_dir = canonical_epoch_root_dir(
        state.config.shm.base_dir,
        "stream-$(stream_state.stream_id)",
        state.config.endpoints.instance_id,
    )
    isdir(root_dir) || return 0

    epochs = UInt64[]
    for entry in readdir(root_dir)
        ep = parse_epoch_dirname(entry)
        ep === nothing && continue
        push!(epochs, ep)
    end
    isempty(epochs) && return 0

    current_epoch = stream_state.epoch == 0 ? maximum(epochs) : stream_state.epoch
    min_keep_epoch = current_epoch > keep - 1 ? current_epoch - (keep - 1) : UInt64(0)
    removed = 0
    for ep in epochs
        ep >= min_keep_epoch && continue
        path = joinpath(root_dir, "epoch-$(ep)")
        path_allowed(path, state.config.shm.allowed_base_dirs) || continue
        age_ns = epoch_dir_age_ns(path, now_ns, get(stream_state.epoch_start_ns, ep, nothing))
        header_path = joinpath(path, "header.ring")
        fields = read_epoch_superblock(header_path)
        activity_ns = fields === nothing ? UInt64(0) : fields.activity_timestamp_ns
        activity_age = activity_ns == 0 ? age_ns : (now_ns > activity_ns ? now_ns - activity_ns : UInt64(0))
        activity_age < effective_min_age && continue
        if fields !== nothing && pid_alive(fields.pid)
            continue
        end
        rm(path; recursive = true, force = true)
        delete!(stream_state.epoch_start_ns, ep)
        removed += 1
    end
    removed > 0 && @tp_info "epoch GC removed directories" stream_id=stream_state.stream_id removed keep min_keep_epoch
    return removed
end

function gc_orphan_epochs_for_stream!(
    state::DriverState,
    stream_id::UInt32,
    now_ns::UInt64,
    min_age_ns::Union{UInt64, Nothing} = nothing,
)
    policy = state.config.policies
    policy.epoch_gc_enabled || return 0
    keep = max(1, Int(policy.epoch_gc_keep))
    effective_min_age = min_age_ns === nothing ? policy.epoch_gc_min_age_ns : min_age_ns
    root_dir = canonical_epoch_root_dir(
        state.config.shm.base_dir,
        "stream-$(stream_id)",
        state.config.endpoints.instance_id,
    )
    isdir(root_dir) || return 0
    epochs = UInt64[]
    for entry in readdir(root_dir)
        ep = parse_epoch_dirname(entry)
        ep === nothing && continue
        push!(epochs, ep)
    end
    isempty(epochs) && return 0
    current_epoch = maximum(epochs)
    min_keep_epoch = current_epoch > keep - 1 ? current_epoch - (keep - 1) : UInt64(0)
    removed = 0
    for ep in epochs
        ep >= min_keep_epoch && continue
        path = joinpath(root_dir, "epoch-$(ep)")
        path_allowed(path, state.config.shm.allowed_base_dirs) || continue
        age_ns = epoch_dir_age_ns(path, now_ns, nothing)
        header_path = joinpath(path, "header.ring")
        fields = read_epoch_superblock(header_path)
        activity_ns = fields === nothing ? UInt64(0) : fields.activity_timestamp_ns
        activity_age = activity_ns == 0 ? age_ns : (now_ns > activity_ns ? now_ns - activity_ns : UInt64(0))
        activity_age < effective_min_age && continue
        if fields !== nothing && pid_alive(fields.pid)
            continue
        end
        rm(path; recursive = true, force = true)
        removed += 1
    end
    removed > 0 && @tp_info "epoch GC removed orphan directories" stream_id removed keep min_keep_epoch
    return removed
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
    ensure_shm_capacity!(state, stream_state, header_path, header_size)
    created = ensure_shm_file!(
        state,
        header_path,
        header_size,
        state.config.shm.permissions_mode,
        state.config.policies.reuse_existing_shm,
    )
    header_mmap = created ? mmap_shm(header_uri, header_size; write = true) :
                  mmap_shm_existing(header_uri, header_size; write = true)
    if created && state.config.policies.prefault_shm
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
        ensure_shm_capacity!(state, stream_state, pool_path, pool_size; pool_id = pool.pool_id)
        created = ensure_shm_file!(
            state,
            pool_path,
            pool_size,
            state.config.shm.permissions_mode,
            state.config.policies.reuse_existing_shm,
        )
        pool_mmap = created ? mmap_shm(pool_uri, pool_size; write = true) :
                    mmap_shm_existing(pool_uri, pool_size; write = true)
        if created && state.config.policies.prefault_shm
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

function ensure_shm_capacity!(
    state::DriverState,
    stream_state::DriverStreamState,
    path::AbstractString,
    size::Int;
    pool_id::Union{UInt16, Nothing} = nothing,
)
    stat_path = ispath(path) ? path : state.config.shm.base_dir
    available = shm_available_bytes(stat_path)
    if available >= size
        return nothing
    end
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    gc_stream_epochs!(state, stream_state, now_ns; min_age_ns = UInt64(0))
    available = shm_available_bytes(stat_path)
    if available < size
        if pool_id === nothing
            throw(ArgumentError("insufficient shm space for header region: need $(size) bytes, have $(available)"))
        end
        throw(ArgumentError("insufficient shm space for payload pool $(pool_id): need $(size) bytes, have $(available)"))
    end
    return nothing
end

parse_mode(mode_str::AbstractString) = parse(UInt32, mode_str; base = 8)

function ensure_shm_file!(
    state::DriverState,
    path::AbstractString,
    size::Int,
    mode_str::AbstractString,
    reuse_existing::Bool,
)
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
    created = !isfile(path)
    if !created && reuse_existing
        Shm.open_shm_nofollow(path, Shm.SHM_O_RDWR) do io
            filesize(io) >= size || throw(ArgumentError("SHM file smaller than expected size"))
        end
    else
        Shm.open_shm_nofollow(path, Shm.SHM_O_RDWR | Shm.SHM_O_CREAT) do io
            truncate(io, size)
        end
    end
    isfile(path) || throw(ArgumentError("SHM path not a regular file"))
    chmod(path, parse_mode(mode_str))
    return created
end

add_hugepage_flag(uri::AbstractString) = "$(uri)|require_hugepages=true"

function path_allowed(path::AbstractString, allowed_dirs::AbstractVector{<:AbstractString})
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

function cleanup_shm_on_exit!(state::DriverState)
    state.config.policies.cleanup_shm_on_exit || return nothing
    for stream_state in values(state.streams)
        if !isempty(stream_state.header_uri)
            header_path = parse_shm_uri(stream_state.header_uri).path
            if path_allowed(header_path, state.config.shm.allowed_base_dirs)
                rm(header_path; force = true)
            end
        end
        for uri in values(stream_state.pool_uris)
            pool_path = parse_shm_uri(uri).path
            if path_allowed(pool_path, state.config.shm.allowed_base_dirs)
                rm(pool_path; force = true)
            end
        end
    end
    return nothing
end
