"""
Validate discovery endpoints do not overlap the driver control endpoint.

Arguments:
- `control_channel`: driver control channel.
- `control_stream_id`: driver control stream id.
- `request_channel`: discovery request channel.
- `request_stream_id`: discovery request stream id.
- `response_channel`: discovery response channel.
- `response_stream_id`: discovery response stream id.

Returns:
- `true` if endpoints are valid.

Raises:
- `ArgumentError` if discovery endpoints overlap driver control.
"""
function validate_discovery_endpoints(
    control_channel::AbstractString,
    control_stream_id::Int32,
    request_channel::AbstractString,
    request_stream_id::Int32,
    response_channel::AbstractString,
    response_stream_id::UInt32,
)
    if request_channel == control_channel && request_stream_id == control_stream_id
        throw(DiscoveryConfigError("discovery request endpoint overlaps driver control"))
    end
    if response_channel == control_channel && Int32(response_stream_id) == control_stream_id
        throw(DiscoveryConfigError("discovery response endpoint overlaps driver control"))
    end
    return true
end

"""
Validate bridge configuration and mapping entries.

Arguments:
- `config`: bridge configuration.
- `mappings`: bridge stream mappings.

Returns:
- `true` if configuration is valid.

Raises:
- `BridgeConfigError` if configuration is invalid.
"""
function validate_bridge_config(config::BridgeConfig, mappings::Vector{BridgeMapping})
    isempty(config.payload_channel) && throw(BridgeConfigError("bridge payload_channel must be set"))
    config.payload_stream_id == 0 && throw(BridgeConfigError("bridge payload_stream_id must be nonzero"))
    isempty(config.control_channel) && throw(BridgeConfigError("bridge control_channel must be set"))
    config.control_stream_id == 0 && throw(BridgeConfigError("bridge control_stream_id must be nonzero"))
    if config.forward_metadata
        isempty(config.metadata_channel) && throw(BridgeConfigError("bridge metadata_channel must be set when forward_metadata=true"))
        config.metadata_stream_id == 0 && throw(BridgeConfigError("bridge metadata_stream_id must be nonzero when forward_metadata=true"))
    end
    if config.max_payload_bytes == 0
        throw(BridgeConfigError("bridge max_payload_bytes must be nonzero"))
    end
    if config.chunk_bytes == 0 && config.max_chunk_bytes == 0 && config.mtu_bytes == 0
        throw(BridgeConfigError("bridge chunk sizing must specify chunk_bytes, max_chunk_bytes, or mtu_bytes"))
    end
    mtu_limit = config.mtu_bytes > 0 ? max(config.mtu_bytes - 128, 0) : UInt32(0)
    if mtu_limit > 0 && config.max_chunk_bytes > 0 && config.max_chunk_bytes > mtu_limit
        throw(BridgeConfigError("bridge max_chunk_bytes exceeds MTU-derived limit"))
    end
    if mtu_limit > 0 && config.chunk_bytes > 0 && config.chunk_bytes > mtu_limit
        throw(BridgeConfigError("bridge chunk_bytes exceeds MTU-derived limit"))
    end
    if config.max_chunk_bytes > 0 && config.chunk_bytes > 0 && config.chunk_bytes > config.max_chunk_bytes
        throw(BridgeConfigError("bridge chunk_bytes exceeds max_chunk_bytes"))
    end
    if config.max_payload_bytes > 0 && config.chunk_bytes > 0 && config.max_payload_bytes < config.chunk_bytes
        throw(BridgeConfigError("bridge max_payload_bytes smaller than chunk_bytes"))
    end
    if config.dest_stream_id_range !== nothing
        range = config.dest_stream_id_range
        range.start_id > range.end_id && throw(BridgeConfigError("bridge dest_stream_id_range invalid bounds"))
        payload_id = UInt32(config.payload_stream_id)
        control_id = UInt32(config.control_stream_id)
        metadata_id = UInt32(config.metadata_stream_id)
        if payload_id != 0 && payload_id >= range.start_id && payload_id <= range.end_id
            throw(BridgeConfigError("bridge dest_stream_id_range overlaps payload_stream_id"))
        end
        if control_id != 0 && control_id >= range.start_id && control_id <= range.end_id
            throw(BridgeConfigError("bridge dest_stream_id_range overlaps control_stream_id"))
        end
        if metadata_id != 0 && metadata_id >= range.start_id && metadata_id <= range.end_id
            throw(BridgeConfigError("bridge dest_stream_id_range overlaps metadata_stream_id"))
        end
    end

    seen = Set{Tuple{UInt32, UInt32}}()
    for mapping in mappings
        mapping.source_stream_id == 0 && throw(BridgeConfigError("bridge mapping source_stream_id must be nonzero"))
        if mapping.dest_stream_id == 0 && config.dest_stream_id_range === nothing
            throw(BridgeConfigError("bridge mapping dest_stream_id must be nonzero without dest_stream_id_range"))
        end
        if mapping.source_stream_id == mapping.dest_stream_id
            throw(BridgeConfigError("bridge mapping source_stream_id must differ from dest_stream_id"))
        end
        if config.dest_stream_id_range !== nothing
            range = config.dest_stream_id_range
            if mapping.dest_control_stream_id != 0 &&
               UInt32(mapping.dest_control_stream_id) >= range.start_id &&
               UInt32(mapping.dest_control_stream_id) <= range.end_id
                throw(BridgeConfigError("bridge dest_stream_id_range overlaps dest_control_stream_id"))
            end
            if mapping.metadata_stream_id != 0 &&
               mapping.metadata_stream_id >= range.start_id &&
               mapping.metadata_stream_id <= range.end_id
                throw(BridgeConfigError("bridge dest_stream_id_range overlaps metadata_stream_id"))
            end
        end
        if (config.forward_qos || config.forward_progress) &&
           (mapping.source_control_stream_id == 0 || mapping.dest_control_stream_id == 0)
            throw(BridgeConfigError("bridge mapping requires control stream IDs when forwarding QoS/progress"))
        end
        pair = (mapping.source_stream_id, mapping.dest_stream_id)
        if pair in seen
            throw(BridgeConfigError("duplicate bridge mapping for stream_id pair $(pair)"))
        end
        push!(seen, pair)
    end
    return true
end
