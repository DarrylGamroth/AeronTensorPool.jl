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
