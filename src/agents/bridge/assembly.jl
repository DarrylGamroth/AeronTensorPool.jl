"""
Compute the effective bridge chunk size in bytes.

Arguments:
- `config`: bridge configuration.

Returns:
- Effective chunk size in bytes (0 if disabled).
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

Arguments:
- `header_len`: header byte length.
- `payload_len`: payload byte length.

Returns:
- Total message length in bytes.
"""
@inline function bridge_chunk_message_length(header_len::Int, payload_len::Int)
    block_len = Int(BridgeFrameChunk.sbe_block_length(BridgeFrameChunk.Encoder))
    return BRIDGE_MESSAGE_HEADER_LEN + block_len + 4 + header_len + 4 + payload_len
end

"""
Reset assembly state for a new frame.

Arguments:
- `assembly`: bridge assembly state.
- `seq`: frame sequence number.
- `epoch`: frame epoch.
- `chunk_count`: expected number of chunks.
- `payload_length`: total payload length in bytes.
- `now_ns`: current time in nanoseconds.

Returns:
- `nothing`.
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
    assembly.claim_ready = false
    assembly.slot_claim = SlotClaim(0, Ptr{UInt8}(0), 0, 0, 0, 0)
    reset!(assembly.assembly_timer, now_ns)
    fill!(assembly.received, false)
    return nothing
end

"""
Clear assembly state without an active frame.

Arguments:
- `assembly`: bridge assembly state.
- `now_ns`: current time in nanoseconds.

Returns:
- `nothing`.
"""
@inline function clear_bridge_assembly!(assembly::BridgeAssembly, now_ns::UInt64)
    assembly.seq = 0
    assembly.epoch = 0
    assembly.chunk_count = 0
    assembly.payload_length = 0
    assembly.received_chunks = 0
    assembly.header_present = false
    assembly.claim_ready = false
    assembly.slot_claim = SlotClaim(0, Ptr{UInt8}(0), 0, 0, 0, 0)
    reset!(assembly.assembly_timer, now_ns)
    fill!(assembly.received, false)
    return nothing
end
