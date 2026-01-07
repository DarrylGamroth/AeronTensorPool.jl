using TOML
using UUIDs

"""
Bundled producer/consumer/supervisor configuration.
"""
struct SystemConfig
    producer::ProducerConfig
    consumer::ConsumerConfig
    supervisor::SupervisorConfig
end

"""
Bundled bridge configuration with mappings.
"""
struct BridgeSystemConfig
    bridge::BridgeConfig
    mappings::Vector{BridgeMapping}
end

function expand_vars(value::AbstractString, env::AbstractDict)
    user = get(env, "USER", "")
    out = replace(value, "\${USER}" => user)
    out = replace(out, "\$USER" => user)
    return out
end

function env_default(env::AbstractDict, key::AbstractString, fallback::AbstractString)
    return expand_vars(get(env, key, fallback), env)
end

function env_default(env::AbstractDict, key::AbstractString, fallback::UInt32)
    return parse(UInt32, get(env, key, string(fallback)))
end

function env_default(env::AbstractDict, key::AbstractString, fallback::UInt16)
    return parse(UInt16, get(env, key, string(fallback)))
end

function env_default(env::AbstractDict, key::AbstractString, fallback::UInt64)
    return parse(UInt64, get(env, key, string(fallback)))
end

function env_default(env::AbstractDict, key::AbstractString, fallback::Int32)
    return parse(Int32, get(env, key, string(fallback)))
end

function env_default(env::AbstractDict, key::AbstractString, fallback::Bool)
    return lowercase(get(env, key, string(fallback))) == "true"
end

function parse_payload_pools(tbl::Dict, env::AbstractDict)
    pools_tbl = get(tbl, "payload_pools", Any[])
    pools = PayloadPoolConfig[]
    for pool in pools_tbl
        uri = String(get(pool, "uri", ""))
        push!(
            pools,
            PayloadPoolConfig(
                UInt16(pool["pool_id"]),
                expand_vars(uri, env),
                UInt32(pool["stride_bytes"]),
                UInt32(pool["nslots"]),
            ),
        )
    end
    return pools
end

function parse_bridge_mappings(cfg::Dict, env::AbstractDict)
    mappings_tbl = get(cfg, "mappings", Any[])
    mappings = BridgeMapping[]
    for mapping in mappings_tbl
        profile = expand_vars(String(get(mapping, "profile", "")), env)
        metadata_stream_id = UInt32(get(mapping, "metadata_stream_id", 0))
        source_control_stream_id = Int32(get(mapping, "source_control_stream_id", 0))
        dest_control_stream_id = Int32(get(mapping, "dest_control_stream_id", 0))
        push!(
            mappings,
            BridgeMapping(
                UInt32(mapping["source_stream_id"]),
                UInt32(mapping["dest_stream_id"]),
                profile,
                metadata_stream_id,
                source_control_stream_id,
                dest_control_stream_id,
            ),
        )
    end
    return mappings
end

function parse_bridge_stream_id_range(bridge::Dict, env::AbstractDict)
    raw = get(bridge, "dest_stream_id_range", nothing)
    raw === nothing && return nothing
    if raw isa AbstractString
        raw_str = strip(expand_vars(String(raw), env))
        isempty(raw_str) && return nothing
        if occursin("-", raw_str)
            parts = split(raw_str, "-")
            length(parts) == 2 || throw(ArgumentError("invalid dest_stream_id_range format"))
            start_id = UInt32(parse(Int, strip(parts[1])))
            end_id = UInt32(parse(Int, strip(parts[2])))
            start_id <= end_id || throw(ArgumentError("invalid dest_stream_id_range bounds"))
            return BridgeStreamIdRange(start_id, end_id)
        end
        if occursin(",", raw_str)
            parts = split(raw_str, ",")
            length(parts) == 2 || throw(ArgumentError("invalid dest_stream_id_range format"))
            start_id = UInt32(parse(Int, strip(parts[1])))
            end_id = UInt32(parse(Int, strip(parts[2])))
            start_id <= end_id || throw(ArgumentError("invalid dest_stream_id_range bounds"))
            return BridgeStreamIdRange(start_id, end_id)
        end
        return nothing
    end
    if raw isa AbstractVector && length(raw) == 2
        start_id = UInt32(raw[1])
        end_id = UInt32(raw[2])
        start_id <= end_id || throw(ArgumentError("invalid dest_stream_id_range bounds"))
        return BridgeStreamIdRange(start_id, end_id)
    end
    return nothing
end

function assign_bridge_dest_stream_ids(
    mappings::Vector{BridgeMapping},
    range::Union{BridgeStreamIdRange, Nothing},
    reserved::Set{UInt32},
)
    range === nothing && return mappings
    used = Set{UInt32}()
    for mapping in mappings
        if mapping.dest_stream_id != 0
            push!(used, mapping.dest_stream_id)
        end
    end
    assigned = BridgeMapping[]
    next_id = range.start_id
    for mapping in mappings
        if mapping.dest_stream_id != 0
            push!(assigned, mapping)
            continue
        end
        start_id = next_id
        candidate = start_id
        found = false
        while true
            if candidate != mapping.source_stream_id &&
               !(candidate in used) &&
               !(candidate in reserved)
                found = true
                break
            end
            candidate = candidate == range.end_id ? range.start_id : candidate + 1
            candidate == start_id && break
        end
        found || throw(BridgeConfigError("bridge dest_stream_id_range exhausted"))
        next_id = candidate == range.end_id ? range.start_id : candidate + 1
        push!(used, candidate)
        push!(
            assigned,
            BridgeMapping(
                mapping.source_stream_id,
                candidate,
                mapping.profile,
                mapping.metadata_stream_id,
                mapping.source_control_stream_id,
                mapping.dest_control_stream_id,
            ),
        )
    end
    return assigned
end

function resolve_producer_paths(
    header_uri::String,
    payload_pools::Vector{PayloadPoolConfig},
    shm_base_dir::String,
    shm_namespace::String,
    producer_instance_id::String,
    epoch::UInt64,
)
    isempty(shm_base_dir) && return header_uri, payload_pools
    isempty(shm_namespace) && return header_uri, payload_pools
    isempty(producer_instance_id) && return header_uri, payload_pools

    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, producer_instance_id, epoch)
    resolved_header_uri = header_uri
    if isempty(resolved_header_uri)
        resolved_header_uri = "shm:file?path=$(joinpath(epoch_dir, "header.ring"))"
    end

    resolved_pools = PayloadPoolConfig[]
    for pool in payload_pools
        uri = pool.uri
        if isempty(uri)
            uri = "shm:file?path=$(joinpath(epoch_dir, "payload-$(pool.pool_id).pool"))"
        end
        push!(resolved_pools, PayloadPoolConfig(pool.pool_id, uri, pool.stride_bytes, pool.nslots))
    end
    return resolved_header_uri, resolved_pools
end

function parse_allowed_base_dirs(tbl::Dict, env::AbstractDict)
    dirs_tbl = get(tbl, "allowed_base_dirs", Any[])
    dirs = String[]
    for dir in dirs_tbl
        push!(dirs, expand_vars(String(dir), env))
    end
    return dirs
end

"""
Load ProducerConfig from a TOML file with optional environment overrides.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `ProducerConfig`.
"""
function load_producer_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    prod = get(cfg, "producer", Dict{String, Any}())

    aeron_dir = env_default(env, "AERON_DIR", String(get(prod, "aeron_dir", "")))
    aeron_uri = env_default(env, "AERON_URI", String(get(prod, "aeron_uri", "aeron:ipc")))
    descriptor_stream_id = Int32(get(prod, "descriptor_stream_id", 1100))
    control_stream_id = Int32(get(prod, "control_stream_id", 1000))
    qos_stream_id = Int32(get(prod, "qos_stream_id", 1200))
    metadata_stream_id = Int32(get(prod, "metadata_stream_id", 1300))
    stream_id = env_default(env, "TP_STREAM_ID", UInt32(get(prod, "stream_id", 1)))
    producer_id = env_default(env, "TP_PRODUCER_ID", UInt32(get(prod, "producer_id", 1)))
    layout_version = env_default(env, "TP_LAYOUT_VERSION", UInt32(get(prod, "layout_version", 1)))
    nslots = env_default(env, "TP_N_SLOTS", UInt32(get(prod, "nslots", 1024)))
    shm_base_dir = expand_vars(String(get(prod, "shm_base_dir", "")), env)
    shm_namespace = expand_vars(String(get(prod, "shm_namespace", "tensorpool")), env)
    producer_instance_id = expand_vars(String(get(prod, "producer_instance_id", "")), env)
    if isempty(producer_instance_id)
        producer_instance_id = string(uuid4())
    end
    header_uri = env_default(env, "TP_HEADER_URI", String(get(prod, "header_uri", "")))
    payload_pools = parse_payload_pools(prod, env)
    max_dims = UInt8(MAX_DIMS)
    announce_interval_ns = UInt64(get(prod, "announce_interval_ns", 1_000_000_000))
    qos_interval_ns = UInt64(get(prod, "qos_interval_ns", 1_000_000_000))
    progress_interval_ns = UInt64(get(prod, "progress_interval_ns", 250_000))
    progress_bytes_delta = UInt64(get(prod, "progress_bytes_delta", 65536))
    mlock_shm = Bool(get(prod, "mlock_shm", false))

    header_uri, payload_pools = resolve_producer_paths(
        header_uri,
        payload_pools,
        shm_base_dir,
        shm_namespace,
        producer_instance_id,
        UInt64(1),
    )

    return ProducerConfig(
        aeron_dir,
        aeron_uri,
        descriptor_stream_id,
        control_stream_id,
        qos_stream_id,
        metadata_stream_id,
        stream_id,
        producer_id,
        layout_version,
        nslots,
        shm_base_dir,
        shm_namespace,
        producer_instance_id,
        header_uri,
        payload_pools,
        max_dims,
        announce_interval_ns,
        qos_interval_ns,
        progress_interval_ns,
        progress_bytes_delta,
        mlock_shm,
    )
end

"""
Load ConsumerConfig from a TOML file with optional environment overrides.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `ConsumerConfig`.
"""
function load_consumer_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    cons = get(cfg, "consumer", Dict{String, Any}())

    aeron_dir = env_default(env, "AERON_DIR", String(get(cons, "aeron_dir", "")))
    aeron_uri = env_default(env, "AERON_URI", String(get(cons, "aeron_uri", "aeron:ipc")))
    descriptor_stream_id = Int32(get(cons, "descriptor_stream_id", 1100))
    control_stream_id = Int32(get(cons, "control_stream_id", 1000))
    qos_stream_id = Int32(get(cons, "qos_stream_id", 1200))
    stream_id = env_default(env, "TP_STREAM_ID", UInt32(get(cons, "stream_id", 1)))
    consumer_id = env_default(env, "TP_CONSUMER_ID", UInt32(get(cons, "consumer_id", 1)))
    expected_layout_version = UInt32(get(cons, "expected_layout_version", 1))
    max_dims = UInt8(MAX_DIMS)
    mode_raw = get(cons, "mode", "STREAM")
    mode = mode_raw == "RATE_LIMITED" ? Mode.RATE_LIMITED :
           mode_raw == "STREAM" ? Mode.STREAM :
           error("invalid consumer mode: $mode_raw (use STREAM or RATE_LIMITED)")
    max_outstanding_seq_gap = UInt32(get(cons, "max_outstanding_seq_gap", 0))
    use_shm = Bool(get(cons, "use_shm", true))
    supports_shm = Bool(get(cons, "supports_shm", true))
    supports_progress = Bool(get(cons, "supports_progress", false))
    max_rate_hz = UInt16(get(cons, "max_rate_hz", 0))
    requested_descriptor_channel =
        expand_vars(String(get(cons, "request_descriptor_channel", "")), env)
    requested_descriptor_stream_id = UInt32(get(cons, "request_descriptor_stream_id", 0))
    requested_control_channel =
        expand_vars(String(get(cons, "request_control_channel", "")), env)
    requested_control_stream_id = UInt32(get(cons, "request_control_stream_id", 0))
    payload_fallback_uri = expand_vars(String(get(cons, "payload_fallback_uri", "")), env)
    shm_base_dir = expand_vars(String(get(cons, "shm_base_dir", "")), env)
    allowed_base_dirs = parse_allowed_base_dirs(cons, env)
    if isempty(allowed_base_dirs) && !isempty(shm_base_dir)
        push!(allowed_base_dirs, shm_base_dir)
    end
    require_hugepages = Bool(get(cons, "require_hugepages", false))
    progress_interval_us = UInt32(get(cons, "progress_interval_us", 250))
    progress_bytes_delta = UInt32(get(cons, "progress_bytes_delta", 65536))
    progress_rows_delta = UInt32(get(cons, "progress_rows_delta", 0))
    hello_interval_ns = UInt64(get(cons, "hello_interval_ns", 1_000_000_000))
    qos_interval_ns = UInt64(get(cons, "qos_interval_ns", 1_000_000_000))
    announce_freshness_ns = UInt64(get(cons, "announce_freshness_ns", 3_000_000_000))
    mlock_shm = Bool(get(cons, "mlock_shm", false))

    return ConsumerConfig(
        aeron_dir,
        aeron_uri,
        descriptor_stream_id,
        control_stream_id,
        qos_stream_id,
        stream_id,
        consumer_id,
        expected_layout_version,
        max_dims,
        mode,
        max_outstanding_seq_gap,
        use_shm,
        supports_shm,
        supports_progress,
        max_rate_hz,
        payload_fallback_uri,
        shm_base_dir,
        allowed_base_dirs,
        require_hugepages,
        progress_interval_us,
        progress_bytes_delta,
        progress_rows_delta,
        hello_interval_ns,
        qos_interval_ns,
        announce_freshness_ns,
        requested_descriptor_channel,
        requested_descriptor_stream_id,
        requested_control_channel,
        requested_control_stream_id,
        mlock_shm,
    )
end

"""
Load SupervisorConfig from a TOML file with optional environment overrides.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `SupervisorConfig`.
"""
function load_supervisor_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    sup = get(cfg, "supervisor", Dict{String, Any}())

    aeron_dir = env_default(env, "AERON_DIR", String(get(sup, "aeron_dir", "")))
    aeron_uri = env_default(env, "AERON_URI", String(get(sup, "aeron_uri", "aeron:ipc")))
    control_stream_id = Int32(get(sup, "control_stream_id", 1000))
    qos_stream_id = Int32(get(sup, "qos_stream_id", 1200))
    stream_id = env_default(env, "TP_STREAM_ID", UInt32(get(sup, "stream_id", 1)))
    liveness_timeout_ns = UInt64(get(sup, "liveness_timeout_ns", 5_000_000_000))
    liveness_check_interval_ns = UInt64(get(sup, "liveness_check_interval_ns", 1_000_000_000))

    return SupervisorConfig(
        aeron_dir,
        aeron_uri,
        control_stream_id,
        qos_stream_id,
        stream_id,
        liveness_timeout_ns,
        liveness_check_interval_ns,
    )
end

"""
Load SystemConfig (producer/consumer/supervisor) from a TOML file.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `SystemConfig` with producer, consumer, and supervisor settings.
"""
function load_system_config(path::AbstractString; env::AbstractDict = ENV)
    return SystemConfig(
        load_producer_config(path; env = env),
        load_consumer_config(path; env = env),
        load_supervisor_config(path; env = env),
    )
end

"""
Load BridgeConfig and mappings from a TOML file.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `BridgeSystemConfig` with bridge config and mappings.
"""
function load_bridge_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    bridge = get(cfg, "bridge", Dict{String, Any}())

    instance_id = expand_vars(String(get(bridge, "instance_id", "bridge")), env)
    aeron_dir = env_default(env, "AERON_DIR", String(get(bridge, "aeron_dir", "")))
    payload_channel = expand_vars(String(get(bridge, "payload_channel", "")), env)
    payload_stream_id = Int32(get(bridge, "payload_stream_id", 0))
    control_channel = expand_vars(String(get(bridge, "control_channel", "")), env)
    control_stream_id = Int32(get(bridge, "control_stream_id", 0))
    metadata_channel = expand_vars(String(get(bridge, "metadata_channel", "")), env)
    metadata_stream_id = Int32(get(bridge, "metadata_stream_id", 0))
    source_metadata_stream_id = Int32(get(bridge, "source_metadata_stream_id", metadata_stream_id))
    mtu_bytes = UInt32(get(bridge, "mtu_bytes", 0))
    chunk_bytes = UInt32(get(bridge, "chunk_bytes", 0))
    max_chunk_bytes = UInt32(get(bridge, "max_chunk_bytes", 65535))
    max_payload_bytes = UInt32(get(bridge, "max_payload_bytes", 1073741824))
    forward_metadata = Bool(get(bridge, "forward_metadata", true))
    forward_qos = Bool(get(bridge, "forward_qos", false))
    forward_progress = Bool(get(bridge, "forward_progress", false))
    assembly_timeout_ms = UInt64(get(bridge, "assembly_timeout_ms", 250))
    dest_stream_id_range = parse_bridge_stream_id_range(bridge, env)

    bridge_config = BridgeConfig(
        instance_id,
        aeron_dir,
        payload_channel,
        payload_stream_id,
        control_channel,
        control_stream_id,
        metadata_channel,
        metadata_stream_id,
        source_metadata_stream_id,
        mtu_bytes,
        chunk_bytes,
        max_chunk_bytes,
        max_payload_bytes,
        assembly_timeout_ms * UInt64(1_000_000),
        forward_metadata,
        forward_qos,
        forward_progress,
        dest_stream_id_range,
    )

    mappings = parse_bridge_mappings(cfg, env)
    reserved = Set{UInt32}()
    payload_stream_id != 0 && push!(reserved, UInt32(payload_stream_id))
    control_stream_id != 0 && push!(reserved, UInt32(control_stream_id))
    metadata_stream_id != 0 && push!(reserved, UInt32(metadata_stream_id))
    for mapping in mappings
        mapping.metadata_stream_id != 0 && push!(reserved, mapping.metadata_stream_id)
        mapping.dest_control_stream_id != 0 && push!(reserved, UInt32(mapping.dest_control_stream_id))
    end
    mappings = assign_bridge_dest_stream_ids(mappings, dest_stream_id_range, reserved)
    validate_bridge_config(bridge_config, mappings)
    return BridgeSystemConfig(bridge_config, mappings)
end
