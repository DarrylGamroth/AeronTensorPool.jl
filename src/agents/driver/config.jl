using TOML

"""
Driver pool configuration (stride class).
"""
struct DriverPoolConfig
    pool_id::UInt16
    stride_bytes::UInt32
end

"""
Driver profile configuration (header + pools).
"""
struct DriverProfileConfig
    name::String
    header_nslots::UInt32
    header_slot_bytes::UInt16
    max_dims::UInt8
    payload_pools::Vector{DriverPoolConfig}
end

"""
Stream binding to a driver profile.
"""
struct DriverStreamConfig
    name::String
    stream_id::UInt32
    profile::String
end

"""
Policy configuration for the driver.
"""
struct DriverPolicyConfig
    allow_dynamic_streams::Bool
    default_profile::String
    announce_period_ms::UInt32
    lease_keepalive_interval_ms::UInt32
    lease_expiry_grace_intervals::UInt32
    prefault_shm::Bool
    reuse_existing_shm::Bool
    mlock_shm::Bool
    cleanup_shm_on_exit::Bool
    epoch_gc_enabled::Bool
    epoch_gc_keep::UInt32
    epoch_gc_min_age_ns::UInt64
    epoch_gc_on_startup::Bool
    shutdown_timeout_ms::UInt32
    shutdown_token::String
end

DriverPolicyConfig(
    allow_dynamic_streams::Bool,
    default_profile::String,
    announce_period_ms::UInt32,
    lease_keepalive_interval_ms::UInt32,
    lease_expiry_grace_intervals::UInt32,
    prefault_shm::Bool,
    reuse_existing_shm::Bool,
    mlock_shm::Bool,
    cleanup_shm_on_exit::Bool,
    shutdown_timeout_ms::UInt32,
    shutdown_token::String,
) = DriverPolicyConfig(
    allow_dynamic_streams,
    default_profile,
    announce_period_ms,
    lease_keepalive_interval_ms,
    lease_expiry_grace_intervals,
    prefault_shm,
    reuse_existing_shm,
    mlock_shm,
    cleanup_shm_on_exit,
    true,
    UInt32(2),
    UInt64(announce_period_ms) * 1_000_000 * 3,
    false,
    shutdown_timeout_ms,
    shutdown_token,
)

"""
Inclusive stream id allocation range.
"""
struct DriverStreamIdRange
    start_id::UInt32
    end_id::UInt32
end

"""
Shared-memory backend configuration for the driver.
"""
struct DriverShmConfig
    base_dir::String
    require_hugepages::Bool
    page_size_bytes::UInt32
    permissions_mode::String
    allowed_base_dirs::Vector{String}
end

"""
Driver Aeron endpoints and identity.
"""
struct DriverEndpoints
    instance_id::String
    aeron_dir::String
    control_channel::String
    control_stream_id::Int32
    announce_channel::String
    announce_stream_id::Int32
    qos_channel::String
    qos_stream_id::Int32
end

"""
Complete driver configuration loaded from TOML + env overrides.
"""
struct DriverConfig
    endpoints::DriverEndpoints
    shm::DriverShmConfig
    policies::DriverPolicyConfig
    stream_id_range::Union{DriverStreamIdRange, Nothing}
    descriptor_stream_id_range::Union{DriverStreamIdRange, Nothing}
    control_stream_id_range::Union{DriverStreamIdRange, Nothing}
    profiles::Dict{String, DriverProfileConfig}
    streams::Dict{String, DriverStreamConfig}
end

DriverConfig(
    endpoints::DriverEndpoints,
    shm::DriverShmConfig,
    policies::DriverPolicyConfig,
    profiles::Dict{String, DriverProfileConfig},
    streams::Dict{String, DriverStreamConfig};
    stream_id_range::Union{DriverStreamIdRange, Nothing} = nothing,
    descriptor_stream_id_range::Union{DriverStreamIdRange, Nothing} = nothing,
    control_stream_id_range::Union{DriverStreamIdRange, Nothing} = nothing,
) = DriverConfig(
    endpoints,
    shm,
    policies,
    stream_id_range,
    descriptor_stream_id_range,
    control_stream_id_range,
    profiles,
    streams,
)

env_key(key::AbstractString) = uppercase(replace(key, "." => "_"))

function env_override(env::AbstractDict, key::AbstractString, fallback::AbstractString)
    return get(env, env_key(key), fallback)
end

function env_override(env::AbstractDict, key::AbstractString, fallback::UInt32)
    return parse(UInt32, get(env, env_key(key), string(fallback)))
end

function env_override(env::AbstractDict, key::AbstractString, fallback::UInt16)
    return parse(UInt16, get(env, env_key(key), string(fallback)))
end

function env_override(env::AbstractDict, key::AbstractString, fallback::UInt64)
    return parse(UInt64, get(env, env_key(key), string(fallback)))
end

function env_override(env::AbstractDict, key::AbstractString, fallback::Int32)
    return parse(Int32, get(env, env_key(key), string(fallback)))
end

function env_override(env::AbstractDict, key::AbstractString, fallback::Bool)
    return lowercase(get(env, env_key(key), string(fallback))) == "true"
end

"""
Load DriverConfig from a TOML file with optional environment overrides.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `DriverConfig`.
"""
function load_driver_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    driver_tbl = get(cfg, "driver", Dict{String, Any}())
    shm_tbl = get(cfg, "shm", Dict{String, Any}())
    policies_tbl = get(cfg, "policies", Dict{String, Any}())
    profiles_tbl = get(cfg, "profiles", Dict{String, Any}())
    streams_tbl = get(cfg, "streams", Dict{String, Any}())

    instance_id =
        String(env_override(env, "driver.instance_id", String(get(driver_tbl, "instance_id", "driver-01"))))
    aeron_dir = String(env_override(env, "driver.aeron_dir", String(get(driver_tbl, "aeron_dir", ""))))
    control_channel =
        String(env_override(env, "driver.control_channel", String(get(driver_tbl, "control_channel", "aeron:ipc"))))
    control_stream_id =
        Int32(env_override(env, "driver.control_stream_id", Int32(get(driver_tbl, "control_stream_id", 1000))))
    announce_channel =
        String(env_override(env, "driver.announce_channel", String(get(driver_tbl, "announce_channel", control_channel))))
    announce_stream_id =
        Int32(env_override(env, "driver.announce_stream_id", Int32(get(driver_tbl, "announce_stream_id", control_stream_id))))
    qos_channel =
        String(env_override(env, "driver.qos_channel", String(get(driver_tbl, "qos_channel", "aeron:ipc"))))
    qos_stream_id =
        Int32(env_override(env, "driver.qos_stream_id", Int32(get(driver_tbl, "qos_stream_id", 1200))))

    base_dir = String(env_override(env, "shm.base_dir", String(get(shm_tbl, "base_dir", "/dev/shm/tensorpool"))))
    require_hugepages = env_override(env, "shm.require_hugepages", Bool(get(shm_tbl, "require_hugepages", false)))
    page_size_bytes = env_override(env, "shm.page_size_bytes", UInt32(get(shm_tbl, "page_size_bytes", 4096)))
    permissions_mode = String(env_override(env, "shm.permissions_mode", String(get(shm_tbl, "permissions_mode", "660"))))
    allowed_base_dirs = get(shm_tbl, "allowed_base_dirs", Any[])
    allowed_dirs = String[]
    if isempty(allowed_base_dirs)
        push!(allowed_dirs, abspath(base_dir))
    else
        for dir in allowed_base_dirs
            push!(allowed_dirs, abspath(String(dir)))
        end
    end

    allow_dynamic_streams =
        env_override(env, "policies.allow_dynamic_streams", Bool(get(policies_tbl, "allow_dynamic_streams", false)))
    default_profile =
        String(env_override(env, "policies.default_profile", String(get(policies_tbl, "default_profile", ""))))
    announce_period_ms =
        env_override(env, "policies.announce_period_ms", UInt32(get(policies_tbl, "announce_period_ms", 1000)))
    lease_keepalive_interval_ms =
        env_override(env, "policies.lease_keepalive_interval_ms", UInt32(get(policies_tbl, "lease_keepalive_interval_ms", 1000)))
    lease_expiry_grace_intervals =
        env_override(env, "policies.lease_expiry_grace_intervals", UInt32(get(policies_tbl, "lease_expiry_grace_intervals", 3)))
    prefault_shm = env_override(env, "policies.prefault_shm", Bool(get(policies_tbl, "prefault_shm", true)))
    reuse_existing_shm =
        env_override(env, "policies.reuse_existing_shm", Bool(get(policies_tbl, "reuse_existing_shm", false)))
    mlock_shm = env_override(env, "policies.mlock_shm", Bool(get(policies_tbl, "mlock_shm", false)))
    cleanup_shm_on_exit =
        env_override(env, "policies.cleanup_shm_on_exit", Bool(get(policies_tbl, "cleanup_shm_on_exit", false)))
    epoch_gc_enabled =
        env_override(env, "policies.epoch_gc_enabled", Bool(get(policies_tbl, "epoch_gc_enabled", true)))
    epoch_gc_keep = env_override(env, "policies.epoch_gc_keep", UInt32(get(policies_tbl, "epoch_gc_keep", 2)))
    epoch_gc_min_age_ns = env_override(
        env,
        "policies.epoch_gc_min_age_ns",
        UInt64(get(policies_tbl, "epoch_gc_min_age_ns", 0)),
    )
    if epoch_gc_min_age_ns == 0
        epoch_gc_min_age_ns = UInt64(announce_period_ms) * 1_000_000 * 3
    end
    epoch_gc_on_startup =
        env_override(env, "policies.epoch_gc_on_startup", Bool(get(policies_tbl, "epoch_gc_on_startup", false)))
    shutdown_timeout_ms =
        env_override(env, "policies.shutdown_timeout_ms", UInt32(get(policies_tbl, "shutdown_timeout_ms", 2000)))
    shutdown_token = String(env_override(env, "policies.shutdown_token", String(get(policies_tbl, "shutdown_token", ""))))

    profiles = Dict{String, DriverProfileConfig}()
    for (name, entry) in profiles_tbl
        profile_tbl = Dict{String, Any}(entry)
        header_nslots = UInt32(get(profile_tbl, "header_nslots", 1024))
        header_slot_bytes = UInt16(get(profile_tbl, "header_slot_bytes", 256))
        max_dims = UInt8(MAX_DIMS)
        pools_tbl = get(profile_tbl, "payload_pools", Any[])
        pools = DriverPoolConfig[]
        for pool_entry in pools_tbl
            pool = Dict{String, Any}(pool_entry)
            pool_id = UInt16(pool["pool_id"])
            stride_bytes = UInt32(pool["stride_bytes"])
            push!(pools, DriverPoolConfig(pool_id, stride_bytes))
        end
        profiles[String(name)] = DriverProfileConfig(
            String(name),
            header_nslots,
            header_slot_bytes,
            max_dims,
            pools,
        )
    end

    streams = Dict{String, DriverStreamConfig}()
    for (name, entry) in streams_tbl
        stream_tbl = Dict{String, Any}(entry)
        stream_id = UInt32(stream_tbl["stream_id"])
        profile = String(stream_tbl["profile"])
        streams[String(name)] = DriverStreamConfig(String(name), stream_id, profile)
    end

    if isempty(default_profile) && !isempty(profiles)
        default_profile = first(keys(profiles))
    end

    stream_id_range = parse_stream_id_range(driver_tbl, env, "driver.stream_id_range")
    descriptor_stream_id_range =
        parse_stream_id_range(driver_tbl, env, "driver.descriptor_stream_id_range")
    control_stream_id_range =
        parse_stream_id_range(driver_tbl, env, "driver.control_stream_id_range")

    if !allow_dynamic_streams && isempty(streams)
        throw(ArgumentError("streams must be defined when allow_dynamic_streams=false"))
    end

    for (name, profile) in profiles
        ispow2(profile.header_nslots) || throw(ArgumentError("header_nslots must be power of two for profile $(name)"))
        profile.header_slot_bytes == HEADER_SLOT_BYTES ||
            throw(ArgumentError("header_slot_bytes must be $(HEADER_SLOT_BYTES) for profile $(name)"))
        isempty(profile.payload_pools) && throw(ArgumentError("profile $(name) must define payload_pools"))
        for pool in profile.payload_pools
            validate_stride(
                pool.stride_bytes;
                require_hugepages = require_hugepages,
                hugepage_size = require_hugepages ? hugepage_size_bytes() : 0,
            ) || throw(ArgumentError("invalid stride_bytes for profile $(name)"))
        end
    end

    endpoints = DriverEndpoints(
        instance_id,
        aeron_dir,
        control_channel,
        control_stream_id,
        announce_channel,
        announce_stream_id,
        qos_channel,
        qos_stream_id,
    )
    shm = DriverShmConfig(
        base_dir,
        require_hugepages,
        page_size_bytes,
        permissions_mode,
        allowed_dirs,
    )
    policies = DriverPolicyConfig(
        allow_dynamic_streams,
        default_profile,
        announce_period_ms,
        lease_keepalive_interval_ms,
        lease_expiry_grace_intervals,
        prefault_shm,
        reuse_existing_shm,
        mlock_shm,
        cleanup_shm_on_exit,
        epoch_gc_enabled,
        epoch_gc_keep,
        epoch_gc_min_age_ns,
        epoch_gc_on_startup,
        shutdown_timeout_ms,
        shutdown_token,
    )

    validate_stream_id_ranges!(
        stream_id_range,
        descriptor_stream_id_range,
        control_stream_id_range,
        endpoints,
        streams,
    )

    return DriverConfig(
        endpoints,
        shm,
        policies,
        stream_id_range,
        descriptor_stream_id_range,
        control_stream_id_range,
        profiles,
        streams,
    )
end

function parse_stream_id_range(tbl::AbstractDict, env::AbstractDict, key::AbstractString)
    key_name = split(key, ".")[end]
    env_val = get(env, env_key(key), nothing)
    raw = env_val === nothing ? get(tbl, key_name, nothing) : String(env_val)
    raw === nothing && return nothing
    if raw isa AbstractString
        raw_str = strip(String(raw))
        isempty(raw_str) && return nothing
        if occursin("-", raw_str)
            parts = split(raw_str, "-")
            length(parts) == 2 || throw(ArgumentError("invalid range format for $(key)"))
            start_id = UInt32(parse(Int, strip(parts[1])))
            end_id = UInt32(parse(Int, strip(parts[2])))
            start_id <= end_id || throw(ArgumentError("invalid range bounds for $(key)"))
            return DriverStreamIdRange(start_id, end_id)
        end
        if occursin(",", raw_str)
            parts = split(raw_str, ",")
            length(parts) == 2 || throw(ArgumentError("invalid range format for $(key)"))
            start_id = UInt32(parse(Int, strip(parts[1])))
            end_id = UInt32(parse(Int, strip(parts[2])))
            start_id <= end_id || throw(ArgumentError("invalid range bounds for $(key)"))
            return DriverStreamIdRange(start_id, end_id)
        end
        return nothing
    end
    if raw isa AbstractVector && length(raw) == 2
        start_id = UInt32(raw[1])
        end_id = UInt32(raw[2])
        start_id <= end_id || throw(ArgumentError("invalid range bounds for $(key)"))
        return DriverStreamIdRange(start_id, end_id)
    end
    throw(ArgumentError("invalid range format for $(key)"))
end

function validate_stream_id_ranges!(
    stream_range::Union{DriverStreamIdRange, Nothing},
    descriptor_range::Union{DriverStreamIdRange, Nothing},
    control_range::Union{DriverStreamIdRange, Nothing},
    endpoints::DriverEndpoints,
    streams::Dict{String, DriverStreamConfig},
)
    ranges = [stream_range, descriptor_range, control_range]
    for rng in ranges
        rng === nothing && continue
        rng.start_id <= rng.end_id || throw(ArgumentError("invalid stream id range"))
    end
    for rng in ranges
        rng === nothing && continue
        for other in ranges
            other === nothing && continue
            rng === other && continue
            if !(rng.end_id < other.start_id || other.end_id < rng.start_id)
                throw(ArgumentError("stream id ranges overlap"))
            end
        end
    end
    reserved = Set{UInt32}()
    push!(reserved, UInt32(endpoints.control_stream_id))
    push!(reserved, UInt32(endpoints.announce_stream_id))
    push!(reserved, UInt32(endpoints.qos_stream_id))
    for entry in values(streams)
        push!(reserved, entry.stream_id)
    end
    for rng in ranges
        rng === nothing && continue
        for id in reserved
            if id >= rng.start_id && id <= rng.end_id
                throw(ArgumentError("stream id ranges overlap with configured ids"))
            end
        end
    end
    return nothing
end
