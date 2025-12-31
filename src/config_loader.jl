using TOML

"""
Bundled producer/consumer/supervisor configuration.
"""
struct SystemConfig
    producer::ProducerConfig
    consumer::ConsumerConfig
    supervisor::SupervisorConfig
end

@inline function expand_vars(value::String, env::AbstractDict)
    user = get(env, "USER", "")
    out = replace(value, "\${USER}" => user)
    out = replace(out, "\$USER" => user)
    return out
end

@inline function env_default(env::AbstractDict, key::String, fallback::String)
    return expand_vars(get(env, key, fallback), env)
end

@inline function env_default(env::AbstractDict, key::String, fallback::UInt32)
    return parse(UInt32, get(env, key, string(fallback)))
end

@inline function env_default(env::AbstractDict, key::String, fallback::UInt16)
    return parse(UInt16, get(env, key, string(fallback)))
end

@inline function env_default(env::AbstractDict, key::String, fallback::UInt64)
    return parse(UInt64, get(env, key, string(fallback)))
end

@inline function env_default(env::AbstractDict, key::String, fallback::Int32)
    return parse(Int32, get(env, key, string(fallback)))
end

@inline function env_default(env::AbstractDict, key::String, fallback::Bool)
    return lowercase(get(env, key, string(fallback))) == "true"
end

function parse_payload_pools(tbl::Dict, env::AbstractDict)
    pools_tbl = get(tbl, "payload_pools", Any[])
    pools = PayloadPoolConfig[]
    for pool in pools_tbl
        push!(
            pools,
            PayloadPoolConfig(
                UInt16(pool["pool_id"]),
                expand_vars(String(pool["uri"]), env),
                UInt32(pool["stride_bytes"]),
                UInt32(pool["nslots"]),
            ),
        )
    end
    return pools
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
"""
function load_producer_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    prod = get(cfg, "producer", Dict{String, Any}())

    aeron_dir = env_default(env, "AERON_DIR", String(get(prod, "aeron_dir", "/dev/shm/aeron-\$USER")))
    aeron_uri = env_default(env, "AERON_URI", String(get(prod, "aeron_uri", "aeron:ipc")))
    descriptor_stream_id = Int32(get(prod, "descriptor_stream_id", 1100))
    control_stream_id = Int32(get(prod, "control_stream_id", 1000))
    qos_stream_id = Int32(get(prod, "qos_stream_id", 1200))
    metadata_stream_id = Int32(get(prod, "metadata_stream_id", 1300))
    stream_id = env_default(env, "TP_STREAM_ID", UInt32(get(prod, "stream_id", 1)))
    producer_id = env_default(env, "TP_PRODUCER_ID", UInt32(get(prod, "producer_id", 1)))
    layout_version = env_default(env, "TP_LAYOUT_VERSION", UInt32(get(prod, "layout_version", 1)))
    nslots = env_default(env, "TP_N_SLOTS", UInt32(get(prod, "nslots", 1024)))
    header_uri = env_default(env, "TP_HEADER_URI", String(get(prod, "header_uri", "")))
    payload_pools = parse_payload_pools(prod, env)
    max_dims = UInt8(get(prod, "max_dims", MAX_DIMS))
    announce_interval_ns = UInt64(get(prod, "announce_interval_ns", 1_000_000_000))
    qos_interval_ns = UInt64(get(prod, "qos_interval_ns", 1_000_000_000))
    progress_interval_ns = UInt64(get(prod, "progress_interval_ns", 250_000))
    progress_bytes_delta = UInt64(get(prod, "progress_bytes_delta", 65536))

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
        header_uri,
        payload_pools,
        max_dims,
        announce_interval_ns,
        qos_interval_ns,
        progress_interval_ns,
        progress_bytes_delta,
    )
end

"""
Load ConsumerConfig from a TOML file with optional environment overrides.
"""
function load_consumer_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    cons = get(cfg, "consumer", Dict{String, Any}())

    aeron_dir = env_default(env, "AERON_DIR", String(get(cons, "aeron_dir", "/dev/shm/aeron-\$USER")))
    aeron_uri = env_default(env, "AERON_URI", String(get(cons, "aeron_uri", "aeron:ipc")))
    descriptor_stream_id = Int32(get(cons, "descriptor_stream_id", 1100))
    control_stream_id = Int32(get(cons, "control_stream_id", 1000))
    qos_stream_id = Int32(get(cons, "qos_stream_id", 1200))
    stream_id = env_default(env, "TP_STREAM_ID", UInt32(get(cons, "stream_id", 1)))
    consumer_id = env_default(env, "TP_CONSUMER_ID", UInt32(get(cons, "consumer_id", 1)))
    expected_layout_version = UInt32(get(cons, "expected_layout_version", 1))
    max_dims = UInt8(get(cons, "max_dims", MAX_DIMS))
    mode = get(cons, "mode", "STREAM") == "LATEST" ? Mode.LATEST :
           get(cons, "mode", "STREAM") == "DECIMATED" ? Mode.DECIMATED : Mode.STREAM
    decimation = UInt16(get(cons, "decimation", 1))
    max_outstanding_seq_gap = UInt32(get(cons, "max_outstanding_seq_gap", 0))
    use_shm = Bool(get(cons, "use_shm", true))
    supports_shm = Bool(get(cons, "supports_shm", true))
    supports_progress = Bool(get(cons, "supports_progress", false))
    max_rate_hz = UInt16(get(cons, "max_rate_hz", 0))
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
        decimation,
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
    )
end

"""
Load SupervisorConfig from a TOML file with optional environment overrides.
"""
function load_supervisor_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    sup = get(cfg, "supervisor", Dict{String, Any}())

    aeron_dir = env_default(env, "AERON_DIR", String(get(sup, "aeron_dir", "/dev/shm/aeron-\$USER")))
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
"""
function load_system_config(path::AbstractString; env::AbstractDict = ENV)
    return SystemConfig(
        load_producer_config(path; env = env),
        load_consumer_config(path; env = env),
        load_supervisor_config(path; env = env),
    )
end
