using TOML

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

function parse_bridge_stream_id_range(tbl::AbstractDict, env::AbstractDict, key::AbstractString)
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
            return BridgeStreamIdRange(start_id, end_id)
        end
        if occursin(",", raw_str)
            parts = split(raw_str, ",")
            length(parts) == 2 || throw(ArgumentError("invalid range format for $(key)"))
            start_id = UInt32(parse(Int, strip(parts[1])))
            end_id = UInt32(parse(Int, strip(parts[2])))
            start_id <= end_id || throw(ArgumentError("invalid range bounds for $(key)"))
            return BridgeStreamIdRange(start_id, end_id)
        end
        return nothing
    end
    if raw isa AbstractVector && length(raw) == 2
        start_id = UInt32(raw[1])
        end_id = UInt32(raw[2])
        start_id <= end_id || throw(ArgumentError("invalid range bounds for $(key)"))
        return BridgeStreamIdRange(start_id, end_id)
    end
    throw(ArgumentError("invalid range format for $(key)"))
end

function parse_bridge_mapping(tbl::AbstractDict)
    source_stream_id = UInt32(get(tbl, "source_stream_id", 0))
    dest_stream_id = UInt32(get(tbl, "dest_stream_id", 0))
    profile = String(get(tbl, "profile", ""))
    metadata_stream_id = UInt32(get(tbl, "metadata_stream_id", dest_stream_id))
    source_control_stream_id = Int32(get(tbl, "source_control_stream_id", 0))
    dest_control_stream_id = Int32(get(tbl, "dest_control_stream_id", 0))
    return BridgeMapping(
        source_stream_id,
        dest_stream_id,
        profile,
        metadata_stream_id,
        source_control_stream_id,
        dest_control_stream_id,
    )
end

"""
Load bridge configuration and mappings from a TOML file with optional env overrides.

Arguments:
- `path`: TOML file path.
- `env`: environment dictionary for overrides (default: ENV).

Returns:
- `(BridgeConfig, Vector{BridgeMapping})`.
"""
function load_bridge_config(path::AbstractString; env::AbstractDict = ENV)
    cfg = TOML.parsefile(path)
    bridge_tbl = get(cfg, "bridge", Dict{String, Any}())
    mappings_tbl = get(cfg, "mappings", Any[])

    instance_id = String(env_override(env, "bridge.instance_id", String(get(bridge_tbl, "instance_id", "bridge-01"))))
    aeron_dir = String(env_override(env, "bridge.aeron_dir", String(get(bridge_tbl, "aeron_dir", ""))))
    payload_channel =
        String(env_override(env, "bridge.payload_channel", String(get(bridge_tbl, "payload_channel", ""))))
    payload_stream_id =
        Int32(env_override(env, "bridge.payload_stream_id", Int32(get(bridge_tbl, "payload_stream_id", 0))))
    control_channel =
        String(env_override(env, "bridge.control_channel", String(get(bridge_tbl, "control_channel", ""))))
    control_stream_id =
        Int32(env_override(env, "bridge.control_stream_id", Int32(get(bridge_tbl, "control_stream_id", 0))))
    metadata_channel =
        String(env_override(env, "bridge.metadata_channel", String(get(bridge_tbl, "metadata_channel", ""))))
    metadata_stream_id =
        Int32(env_override(env, "bridge.metadata_stream_id", Int32(get(bridge_tbl, "metadata_stream_id", 0))))
    source_metadata_stream_id =
        Int32(env_override(env, "bridge.source_metadata_stream_id", Int32(get(bridge_tbl, "source_metadata_stream_id", 0))))
    mtu_bytes = UInt32(env_override(env, "bridge.mtu_bytes", UInt32(get(bridge_tbl, "mtu_bytes", 0))))
    chunk_bytes = UInt32(env_override(env, "bridge.chunk_bytes", UInt32(get(bridge_tbl, "chunk_bytes", 0))))
    max_chunk_bytes =
        UInt32(env_override(env, "bridge.max_chunk_bytes", UInt32(get(bridge_tbl, "max_chunk_bytes", 65535))))
    max_payload_bytes =
        UInt32(env_override(env, "bridge.max_payload_bytes", UInt32(get(bridge_tbl, "max_payload_bytes", 1073741824))))
    assembly_timeout_ms =
        UInt32(env_override(env, "bridge.assembly_timeout_ms", UInt32(get(bridge_tbl, "assembly_timeout_ms", 250))))
    forward_metadata =
        env_override(env, "bridge.forward_metadata", Bool(get(bridge_tbl, "forward_metadata", true)))
    forward_qos = env_override(env, "bridge.forward_qos", Bool(get(bridge_tbl, "forward_qos", false)))
    forward_progress =
        env_override(env, "bridge.forward_progress", Bool(get(bridge_tbl, "forward_progress", false)))
    forward_tracelink =
        env_override(env, "bridge.forward_tracelink", Bool(get(bridge_tbl, "forward_tracelink", false)))
    dest_stream_id_range = parse_bridge_stream_id_range(bridge_tbl, env, "bridge.dest_stream_id_range")

    config = BridgeConfig(
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
        UInt64(assembly_timeout_ms) * 1_000_000,
        forward_metadata,
        forward_qos,
        forward_progress,
        forward_tracelink,
        dest_stream_id_range,
    )

    mappings = BridgeMapping[]
    for entry in mappings_tbl
        entry isa AbstractDict || throw(ArgumentError("bridge mappings must be tables"))
        push!(mappings, parse_bridge_mapping(entry))
    end
    return config, mappings
end
