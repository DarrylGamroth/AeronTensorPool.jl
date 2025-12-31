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
struct DriverPolicies
    allow_dynamic_streams::Bool
    default_profile::String
    announce_period_ms::UInt32
    lease_keepalive_interval_ms::UInt32
    lease_expiry_grace_intervals::UInt32
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
    policies::DriverPolicies
    profiles::Dict{String, DriverProfileConfig}
    streams::Dict{String, DriverStreamConfig}
end

@inline function env_key(key::String)
    return uppercase(replace(key, "." => "_"))
end

@inline function env_override(env::AbstractDict, key::String, fallback::String)
    return get(env, env_key(key), fallback)
end

@inline function env_override(env::AbstractDict, key::String, fallback::UInt32)
    return parse(UInt32, get(env, env_key(key), string(fallback)))
end

@inline function env_override(env::AbstractDict, key::String, fallback::UInt16)
    return parse(UInt16, get(env, env_key(key), string(fallback)))
end

@inline function env_override(env::AbstractDict, key::String, fallback::Int32)
    return parse(Int32, get(env, env_key(key), string(fallback)))
end

@inline function env_override(env::AbstractDict, key::String, fallback::Bool)
    return lowercase(get(env, env_key(key), string(fallback))) == "true"
end

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
        push!(allowed_dirs, base_dir)
    else
        for dir in allowed_base_dirs
            push!(allowed_dirs, String(dir))
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

    profiles = Dict{String, DriverProfileConfig}()
    for (name, entry) in profiles_tbl
        profile_tbl = Dict{String, Any}(entry)
        header_nslots = UInt32(get(profile_tbl, "header_nslots", 1024))
        header_slot_bytes = UInt16(get(profile_tbl, "header_slot_bytes", 256))
        max_dims = UInt8(get(profile_tbl, "max_dims", MAX_DIMS))
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

    for (name, profile) in profiles
        ispow2(profile.header_nslots) || throw(ArgumentError("header_nslots must be power of two for profile $(name)"))
        profile.header_slot_bytes == HEADER_SLOT_BYTES ||
            throw(ArgumentError("header_slot_bytes must be $(HEADER_SLOT_BYTES) for profile $(name)"))
        isempty(profile.payload_pools) && throw(ArgumentError("profile $(name) must define payload_pools"))
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
    policies = DriverPolicies(
        allow_dynamic_streams,
        default_profile,
        announce_period_ms,
        lease_keepalive_interval_ms,
        lease_expiry_grace_intervals,
    )

    return DriverConfig(endpoints, shm, policies, profiles, streams)
end
