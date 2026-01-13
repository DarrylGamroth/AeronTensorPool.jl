using TOML

const DEFAULT_AERON_URI = "aeron:ipc?term-length=4m"

env_key(key::AbstractString) = uppercase(replace(key, "." => "_"))

function env_override(env::AbstractDict, key::AbstractString, fallback::AbstractString)
    return get(env, env_key(key), fallback)
end

function env_override(env::AbstractDict, key::AbstractString, fallback::UInt32)
    return parse(UInt32, get(env, env_key(key), string(fallback)))
end

function env_override(env::AbstractDict, key::AbstractString, fallback::Int32)
    return parse(Int32, get(env, env_key(key), string(fallback)))
end

function env_override(env::AbstractDict, key::AbstractString, fallback::UInt64)
    return parse(UInt64, get(env, env_key(key), string(fallback)))
end

function env_override(env::AbstractDict, key::AbstractString, fallback::Bool)
    return lowercase(get(env, env_key(key), string(fallback))) == "true"
end

function parse_rate_limiter_mapping(tbl::AbstractDict, default_rate_hz::UInt32)
    source_stream_id = UInt32(get(tbl, "source_stream_id", 0))
    dest_stream_id = UInt32(get(tbl, "dest_stream_id", 0))
    metadata_stream_id = UInt32(get(tbl, "metadata_stream_id", dest_stream_id))
    max_rate_hz = UInt32(get(tbl, "max_rate_hz", default_rate_hz))
    return RateLimiterMapping(
        source_stream_id,
        dest_stream_id,
        metadata_stream_id,
        max_rate_hz,
    )
end

"""
Load rate limiter configuration and mappings from TOML with optional env overrides.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `(RateLimiterConfig, Vector{RateLimiterMapping})`.
"""
function load_rate_limiter_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    rl_tbl = get(cfg, "rate_limiter", Dict{String, Any}())
    mappings_tbl = get(cfg, "mappings", Any[])

    instance_id = String(env_override(env, "rate_limiter.instance_id", String(get(rl_tbl, "instance_id", "rl-01"))))
    aeron_dir = String(env_override(env, "rate_limiter.aeron_dir", String(get(rl_tbl, "aeron_dir", ""))))
    aeron_uri = String(env_override(env, "rate_limiter.aeron_uri", String(get(rl_tbl, "aeron_uri", DEFAULT_AERON_URI))))
    shm_base_dir = String(env_override(env, "rate_limiter.shm_base_dir", String(get(rl_tbl, "shm_base_dir", "/dev/shm"))))

    driver_control_channel = String(env_override(
        env,
        "rate_limiter.driver_control_channel",
        String(get(rl_tbl, "driver_control_channel", "")),
    ))
    driver_control_stream_id = Int32(env_override(
        env,
        "rate_limiter.driver_control_stream_id",
        Int32(get(rl_tbl, "driver_control_stream_id", 0)),
    ))

    descriptor_channel = String(env_override(
        env,
        "rate_limiter.descriptor_channel",
        String(get(rl_tbl, "descriptor_channel", "")),
    ))
    descriptor_stream_id = Int32(env_override(
        env,
        "rate_limiter.descriptor_stream_id",
        Int32(get(rl_tbl, "descriptor_stream_id", 0)),
    ))
    control_channel = String(env_override(
        env,
        "rate_limiter.control_channel",
        String(get(rl_tbl, "control_channel", "aeron:ipc?term-length=1m")),
    ))
    control_stream_id = Int32(env_override(
        env,
        "rate_limiter.control_stream_id",
        Int32(get(rl_tbl, "control_stream_id", 0)),
    ))
    qos_channel = String(env_override(
        env,
        "rate_limiter.qos_channel",
        String(get(rl_tbl, "qos_channel", "aeron:ipc?term-length=1m")),
    ))
    qos_stream_id = Int32(env_override(
        env,
        "rate_limiter.qos_stream_id",
        Int32(get(rl_tbl, "qos_stream_id", 0)),
    ))
    metadata_channel = String(env_override(
        env,
        "rate_limiter.metadata_channel",
        String(get(rl_tbl, "metadata_channel", "")),
    ))
    metadata_stream_id = Int32(env_override(
        env,
        "rate_limiter.metadata_stream_id",
        Int32(get(rl_tbl, "metadata_stream_id", 0)),
    ))
    forward_metadata = env_override(env, "rate_limiter.forward_metadata", Bool(get(rl_tbl, "forward_metadata", true)))
    forward_progress = env_override(env, "rate_limiter.forward_progress", Bool(get(rl_tbl, "forward_progress", false)))
    forward_qos = env_override(env, "rate_limiter.forward_qos", Bool(get(rl_tbl, "forward_qos", false)))
    max_rate_hz = UInt32(env_override(env, "rate_limiter.max_rate_hz", UInt32(get(rl_tbl, "max_rate_hz", 0))))
    source_control_stream_id = Int32(env_override(
        env,
        "rate_limiter.source_control_stream_id",
        Int32(get(rl_tbl, "source_control_stream_id", 0)),
    ))
    dest_control_stream_id = Int32(env_override(
        env,
        "rate_limiter.dest_control_stream_id",
        Int32(get(rl_tbl, "dest_control_stream_id", 0)),
    ))
    source_qos_stream_id = Int32(env_override(
        env,
        "rate_limiter.source_qos_stream_id",
        Int32(get(rl_tbl, "source_qos_stream_id", 0)),
    ))
    dest_qos_stream_id = Int32(env_override(
        env,
        "rate_limiter.dest_qos_stream_id",
        Int32(get(rl_tbl, "dest_qos_stream_id", 0)),
    ))
    keepalive_interval_ns = UInt64(env_override(
        env,
        "rate_limiter.keepalive_interval_ns",
        UInt64(get(rl_tbl, "keepalive_interval_ns", 1_000_000_000)),
    ))
    attach_timeout_ns = UInt64(env_override(
        env,
        "rate_limiter.attach_timeout_ns",
        UInt64(get(rl_tbl, "attach_timeout_ns", 5_000_000_000)),
    ))
    attach_retry_interval_ns = UInt64(env_override(
        env,
        "rate_limiter.attach_retry_interval_ns",
        UInt64(get(rl_tbl, "attach_retry_interval_ns", 1_000_000_000)),
    ))

    config = RateLimiterConfig(
        instance_id,
        aeron_dir,
        aeron_uri,
        shm_base_dir,
        driver_control_channel,
        driver_control_stream_id,
        descriptor_channel,
        descriptor_stream_id,
        control_channel,
        control_stream_id,
        qos_channel,
        qos_stream_id,
        metadata_channel,
        metadata_stream_id,
        forward_metadata,
        forward_progress,
        forward_qos,
        max_rate_hz,
        source_control_stream_id,
        dest_control_stream_id,
        source_qos_stream_id,
        dest_qos_stream_id,
        keepalive_interval_ns,
        attach_timeout_ns,
        attach_retry_interval_ns,
    )

    mappings = RateLimiterMapping[]
    for entry in mappings_tbl
        entry isa AbstractDict || throw(ArgumentError("rate_limiter mappings must be tables"))
        push!(mappings, parse_rate_limiter_mapping(entry, max_rate_hz))
    end
    validate_rate_limiter_config!(config)

    return config, mappings
end

function validate_rate_limiter_config!(config::RateLimiterConfig)
    if config.forward_progress &&
       (config.source_control_stream_id == 0 || config.dest_control_stream_id == 0)
        throw(ArgumentError("forward_progress requires nonzero source_control_stream_id and dest_control_stream_id"))
    end
    if config.forward_qos && (config.source_qos_stream_id == 0 || config.dest_qos_stream_id == 0)
        throw(ArgumentError("forward_qos requires nonzero source_qos_stream_id and dest_qos_stream_id"))
    end
    return config
end
