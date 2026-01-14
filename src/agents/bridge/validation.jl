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
    if config.forward_metadata || config.forward_tracelink
        isempty(config.metadata_channel) &&
            throw(BridgeConfigError("bridge metadata_channel must be set when forwarding metadata/tracelink"))
        config.metadata_stream_id == 0 &&
            throw(BridgeConfigError("bridge metadata_stream_id must be nonzero when forwarding metadata/tracelink"))
        config.source_metadata_stream_id == 0 &&
            throw(BridgeConfigError("bridge source_metadata_stream_id must be nonzero when forwarding metadata/tracelink"))
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
        if payload_id >= range.start_id && payload_id <= range.end_id
            throw(BridgeConfigError("bridge dest_stream_id_range overlaps payload_stream_id"))
        end
        if control_id >= range.start_id && control_id <= range.end_id
            throw(BridgeConfigError("bridge dest_stream_id_range overlaps control_stream_id"))
        end
        if metadata_id >= range.start_id && metadata_id <= range.end_id
            throw(BridgeConfigError("bridge dest_stream_id_range overlaps metadata_stream_id"))
        end
    end
    pairs = Set{Tuple{UInt32, UInt32}}()
    for mapping in mappings
        mapping.source_stream_id == 0 && throw(BridgeConfigError("bridge mapping source_stream_id must be nonzero"))
        if config.dest_stream_id_range === nothing
            mapping.dest_stream_id == 0 &&
                throw(BridgeConfigError("bridge mapping dest_stream_id must be nonzero without dest_stream_id_range"))
            mapping.source_stream_id == mapping.dest_stream_id &&
                throw(BridgeConfigError("bridge mapping source_stream_id must differ from dest_stream_id"))
        end
        if config.dest_stream_id_range !== nothing
            range = config.dest_stream_id_range
            mapping.dest_stream_id != 0 &&
                throw(BridgeConfigError("bridge mapping dest_stream_id must be zero when dest_stream_id_range set"))
            if mapping.dest_control_stream_id != 0
                dcid = UInt32(mapping.dest_control_stream_id)
                dcid >= range.start_id && dcid <= range.end_id &&
                    throw(BridgeConfigError("bridge dest_stream_id_range overlaps dest_control_stream_id"))
            end
            if mapping.metadata_stream_id != 0
                mid = UInt32(mapping.metadata_stream_id)
                mid >= range.start_id && mid <= range.end_id &&
                    throw(BridgeConfigError("bridge dest_stream_id_range overlaps metadata_stream_id"))
            end
        end
        if config.forward_qos || config.forward_progress
            if mapping.source_control_stream_id == 0 || mapping.dest_control_stream_id == 0
                throw(BridgeConfigError("bridge mapping requires control stream IDs when forwarding QoS/progress"))
            end
        end
        pair = (mapping.source_stream_id, mapping.dest_stream_id)
        pair in pairs && throw(BridgeConfigError("duplicate bridge mapping for stream_id pair $(pair)"))
        push!(pairs, pair)
    end
    return true
end

"""
Compute CRC32C for a bridge chunk.

Arguments:
- `header_bytes`: header byte vector (ignored when `header_included=false`).
- `payload_bytes`: payload byte vector.
- `header_included`: whether the header bytes are part of the CRC input.

Returns:
- CRC32C of `header_bytes || payload_bytes` when `header_included=true`,
  otherwise CRC32C of `payload_bytes` only.
"""
function bridge_chunk_crc32c(
    header_bytes::AbstractVector{UInt8},
    payload_bytes::AbstractVector{UInt8},
    header_included::Bool,
)
    if header_included
        crc = CRC32c.crc32c(header_bytes)
        return CRC32c.crc32c(payload_bytes, crc)
    end
    return CRC32c.crc32c(payload_bytes)
end
