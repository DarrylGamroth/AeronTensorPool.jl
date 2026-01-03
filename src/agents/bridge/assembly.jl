"""
Compute the effective bridge chunk size in bytes.
"""
@inline function bridge_effective_chunk_bytes(config::BridgeConfig)
    mtu = Int(config.mtu_bytes)
    max_chunk = Int(config.max_chunk_bytes)
    chunk = Int(config.chunk_bytes)

    base = mtu > 0 ? max(mtu - 128, 0) : 0
    if chunk > 0
        base = base == 0 ? chunk : min(chunk, base)
    elseif base == 0
        base = max_chunk
    end
    if max_chunk > 0
        base = min(base, max_chunk)
    end
    return base
end

"""
Return total byte length for a BridgeFrameChunk message.
"""
@inline function bridge_chunk_message_length(header_len::Int, payload_len::Int)
    block_len = Int(BridgeFrameChunk.sbe_block_length(BridgeFrameChunk.Encoder))
    return BRIDGE_MESSAGE_HEADER_LEN + block_len + 4 + header_len + 4 + payload_len
end

"""
Return var-data positions for header/payload bytes in a BridgeFrameChunk decoder.
"""
@inline function bridge_chunk_var_data_positions(decoder::BridgeFrameChunk.Decoder)
    buf = BridgeFrameChunk.sbe_buffer(decoder)
    pos = BridgeFrameChunk.sbe_position(decoder)
    header_len = Int(SBE.decode_value_le(UInt32, buf, pos))
    header_pos = pos + 4
    payload_len_pos = header_pos + header_len
    payload_len = Int(SBE.decode_value_le(UInt32, buf, payload_len_pos))
    payload_pos = payload_len_pos + 4
    return header_len, header_pos, payload_len, payload_pos
end

"""
Reset assembly state for a new frame.
"""
@inline function reset_bridge_assembly!(
    assembly::BridgeAssembly,
    seq::UInt64,
    epoch::UInt64,
    chunk_count::UInt32,
    payload_length::UInt32,
    now_ns::UInt64,
)
    assembly.seq = seq
    assembly.epoch = epoch
    assembly.chunk_count = chunk_count
    assembly.payload_length = payload_length
    assembly.received_chunks = 0
    assembly.header_present = false
    assembly.last_update_ns = now_ns
    fill!(assembly.received, false)
    return nothing
end
