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
Write header/payload var-data bytes without allocating views.
"""
@inline function bridge_write_var_data!(
    encoder::BridgeFrameChunk.Encoder,
    header_buf::Vector{UInt8},
    header_len::Int,
    payload_buf::AbstractVector{UInt8},
    payload_offset::Int,
    payload_len::Int,
)
    buf = BridgeFrameChunk.sbe_buffer(encoder)
    pos = BridgeFrameChunk.sbe_position(encoder)
    SBE.encode_value_le(UInt32, buf, pos, UInt32(header_len))
    pos += 4
    if header_len > 0
        copyto!(buf, pos + 1, header_buf, 1, header_len)
    end
    pos += header_len
    SBE.encode_value_le(UInt32, buf, pos, UInt32(payload_len))
    pos += 4
    if payload_len > 0
        copyto!(buf, pos + 1, payload_buf, payload_offset + 1, payload_len)
    end
    pos += payload_len
    BridgeFrameChunk.sbe_position!(encoder, pos)
    return nothing
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

"""
Initialize a bridge sender using an existing consumer mapping.
"""
function init_bridge_sender(consumer_state::ConsumerState, config::BridgeConfig, mapping::BridgeMapping)
    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_payload = Aeron.add_publication(client, config.payload_channel, config.payload_stream_id)
    pub_control = Aeron.add_publication(client, config.control_channel, config.control_stream_id)

    return BridgeSenderState(
        consumer_state,
        config,
        mapping,
        ctx,
        client,
        pub_payload,
        pub_control,
        BridgeFrameChunk.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        TensorSlotHeader256.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Vector{UInt8}(undef, HEADER_SLOT_BYTES),
        Vector{Int32}(undef, MAX_DIMS),
        Vector{Int32}(undef, MAX_DIMS),
        UInt64(0),
    )
end

"""
Initialize a bridge receiver for a single mapping.
"""
function init_bridge_receiver(config::BridgeConfig, mapping::BridgeMapping)
    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    sub_payload = Aeron.add_subscription(client, config.payload_channel, config.payload_stream_id)
    sub_control = Aeron.add_subscription(client, config.control_channel, config.control_stream_id)

    chunk_bytes = bridge_effective_chunk_bytes(config)
    max_payload = Int(config.max_payload_bytes)
    max_chunk = max(chunk_bytes, 1)
    max_chunks = max_payload == 0 ? 0 : cld(max_payload, max_chunk)

    assembly = BridgeAssembly(
        UInt64(0),
        UInt64(0),
        UInt32(0),
        UInt32(0),
        UInt32(0),
        false,
        Vector{UInt8}(undef, HEADER_SLOT_BYTES),
        Vector{UInt8}(undef, max_payload),
        fill(false, max_chunks),
        UInt64(0),
    )

    source_info = BridgeSourceInfo(UInt32(0), UInt64(0), UInt32(0), UInt8(0), Dict{UInt16, UInt32}())

    state = BridgeReceiverState(
        config,
        mapping,
        ctx,
        client,
        clock,
        UInt64(0),
        sub_payload,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        sub_control,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        BridgeFrameChunk.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeader256.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        source_info,
        assembly,
        false,
    )

    state.payload_assembler = make_bridge_payload_assembler(state)
    state.control_assembler = make_bridge_control_assembler(state)
    return state
end

"""
Forward a ShmPoolAnnounce on the bridge control channel.
"""
function bridge_forward_announce!(state::BridgeSenderState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(ShmPoolAnnounce.sbe_decoded_length(msg))
    payloads = ShmPoolAnnounce.payloadPools(msg)
    payload_count = length(payloads)

    sent = try_claim_sbe!(state.pub_control, state.control_claim, msg_len) do buf
        enc = state.announce_encoder
        ShmPoolAnnounce.wrap_and_apply_header!(enc, buf, 0)
        ShmPoolAnnounce.streamId!(enc, ShmPoolAnnounce.streamId(msg))
        ShmPoolAnnounce.producerId!(enc, ShmPoolAnnounce.producerId(msg))
        ShmPoolAnnounce.epoch!(enc, ShmPoolAnnounce.epoch(msg))
        ShmPoolAnnounce.layoutVersion!(enc, ShmPoolAnnounce.layoutVersion(msg))
        ShmPoolAnnounce.headerNslots!(enc, ShmPoolAnnounce.headerNslots(msg))
        ShmPoolAnnounce.headerSlotBytes!(enc, ShmPoolAnnounce.headerSlotBytes(msg))
        ShmPoolAnnounce.maxDims!(enc, ShmPoolAnnounce.maxDims(msg))

        group = ShmPoolAnnounce.payloadPools!(enc, payload_count)
        for pool in payloads
            entry = ShmPoolAnnounce.PayloadPools.next!(group)
            ShmPoolAnnounce.PayloadPools.poolId!(entry, ShmPoolAnnounce.PayloadPools.poolId(pool))
            ShmPoolAnnounce.PayloadPools.poolNslots!(entry, ShmPoolAnnounce.PayloadPools.poolNslots(pool))
            ShmPoolAnnounce.PayloadPools.strideBytes!(entry, ShmPoolAnnounce.PayloadPools.strideBytes(pool))
            ShmPoolAnnounce.PayloadPools.regionUri!(entry, String(ShmPoolAnnounce.PayloadPools.regionUri(pool)))
        end
        ShmPoolAnnounce.headerRegionUri!(enc, String(ShmPoolAnnounce.headerRegionUri(msg)))
    end
    sent || return false
    state.last_announce_epoch = ShmPoolAnnounce.epoch(msg)
    return true
end

"""
Publish BridgeFrameChunk messages for the descriptor's frame.
"""
function bridge_send_frame!(state::BridgeSenderState, desc::FrameDescriptor.Decoder)
    consumer_driver_active(state.consumer_state) || return false
    state.consumer_state.mappings.header_mmap === nothing && return false
    FrameDescriptor.epoch(desc) == state.consumer_state.mappings.mapped_epoch || return false
    FrameDescriptor.streamId(desc) == state.mapping.source_stream_id || return false

    header_index = FrameDescriptor.headerIndex(desc)
    header_mmap = state.consumer_state.mappings.header_mmap::Vector{UInt8}
    if state.consumer_state.mappings.mapped_nslots == 0 ||
       header_index >= state.consumer_state.mappings.mapped_nslots
        return false
    end

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
    first = seqlock_read_begin(commit_ptr)
    seqlock_is_write_in_progress(first) && return false

    copyto!(state.header_buf, 1, header_mmap, header_offset + 1, HEADER_SLOT_BYTES)
    wrap_tensor_header!(state.header_decoder, header_mmap, header_offset)

    frame_id = TensorSlotHeader256.frameId(state.header_decoder)
    payload_len = Int(TensorSlotHeader256.valuesLenBytes(state.header_decoder))
    payload_slot = TensorSlotHeader256.payloadSlot(state.header_decoder)
    payload_offset = TensorSlotHeader256.payloadOffset(state.header_decoder)
    pool_id = TensorSlotHeader256.poolId(state.header_decoder)

    if frame_id != FrameDescriptor.seq(desc) || payload_offset != 0
        return false
    end
    payload_slot == header_index || return false
    payload_slot < state.consumer_state.mappings.mapped_nslots || return false

    pool_stride = get(state.consumer_state.mappings.pool_stride_bytes, pool_id, UInt32(0))
    pool_stride == 0 && return false
    payload_len <= Int(pool_stride) || return false
    payload_len <= Int(state.config.max_payload_bytes) || return false

    payload_mmap = get(state.consumer_state.mappings.payload_mmaps, pool_id, nothing)
    payload_mmap === nothing && return false

    second = seqlock_read_end(commit_ptr)
    if first != second || seqlock_is_write_in_progress(second)
        return false
    end

    chunk_bytes = bridge_effective_chunk_bytes(state.config)
    chunk_bytes > 0 || return false
    chunk_count = cld(payload_len, chunk_bytes)
    chunk_count > 0 || return false
    chunk_count <= 65535 || return false

    payload_base = payload_slot_offset(pool_stride, payload_slot)
    seq = FrameDescriptor.seq(desc)
    epoch = FrameDescriptor.epoch(desc)

    for chunk_index in 0:(chunk_count - 1)
        chunk_offset = chunk_index * chunk_bytes
        chunk_len = min(chunk_bytes, payload_len - chunk_offset)
        header_included = chunk_index == 0
        header_len = header_included ? HEADER_SLOT_BYTES : 0
        msg_len = bridge_chunk_message_length(header_len, chunk_len)

        sent = try_claim_sbe!(state.pub_payload, state.chunk_claim, msg_len) do buf
            BridgeFrameChunk.wrap_and_apply_header!(state.chunk_encoder, buf, 0)
            BridgeFrameChunk.streamId!(state.chunk_encoder, state.mapping.source_stream_id)
            BridgeFrameChunk.epoch!(state.chunk_encoder, epoch)
            BridgeFrameChunk.seq!(state.chunk_encoder, seq)
            BridgeFrameChunk.chunkIndex!(state.chunk_encoder, UInt32(chunk_index))
            BridgeFrameChunk.chunkCount!(state.chunk_encoder, UInt32(chunk_count))
            BridgeFrameChunk.chunkOffset!(state.chunk_encoder, UInt32(chunk_offset))
            BridgeFrameChunk.chunkLength!(state.chunk_encoder, UInt32(chunk_len))
            BridgeFrameChunk.payloadLength!(state.chunk_encoder, UInt32(payload_len))
            BridgeFrameChunk.headerIncluded!(
                state.chunk_encoder,
                header_included ? BridgeBool.TRUE : BridgeBool.FALSE,
            )
            bridge_write_var_data!(
                state.chunk_encoder,
                state.header_buf,
                header_len,
                payload_mmap,
                payload_base + chunk_offset,
                chunk_len,
            )
        end
        sent || return false
    end
    return true
end

"""
Update receiver state with the latest forwarded announce.
"""
function bridge_apply_source_announce!(state::BridgeReceiverState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.mapping.source_stream_id || return false
    pool_stride_bytes = state.source_info.pool_stride_bytes
    empty!(pool_stride_bytes)
    pools = ShmPoolAnnounce.payloadPools(msg)
    for pool in pools
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_stride_bytes[pool_id] = pool_stride
    end
    state.source_info.stream_id = ShmPoolAnnounce.streamId(msg)
    state.source_info.epoch = ShmPoolAnnounce.epoch(msg)
    state.source_info.layout_version = ShmPoolAnnounce.layoutVersion(msg)
    state.source_info.max_dims = ShmPoolAnnounce.maxDims(msg)
    state.have_announce = true
    return true
end

"""
Assemble a BridgeFrameChunk into an in-flight frame.
"""
function bridge_receive_chunk!(
    state::BridgeReceiverState,
    chunk::BridgeFrameChunk.Decoder,
    now_ns::UInt64,
)
    state.have_announce || return nothing
    BridgeFrameChunk.streamId(chunk) == state.mapping.source_stream_id || return nothing

    seq = BridgeFrameChunk.seq(chunk)
    epoch = BridgeFrameChunk.epoch(chunk)
    epoch == state.source_info.epoch || return nothing

    chunk_index = UInt32(BridgeFrameChunk.chunkIndex(chunk))
    chunk_count = UInt32(BridgeFrameChunk.chunkCount(chunk))
    chunk_offset = UInt32(BridgeFrameChunk.chunkOffset(chunk))
    chunk_length = UInt32(BridgeFrameChunk.chunkLength(chunk))
    payload_length = UInt32(BridgeFrameChunk.payloadLength(chunk))
    header_included = BridgeFrameChunk.headerIncluded(chunk) == BridgeBool.TRUE

    chunk_count == 0 && return nothing
    chunk_count <= 65535 || return nothing
    chunk_index < chunk_count || return nothing
    payload_length <= state.config.max_payload_bytes || return nothing
    payload_length <= UInt32(length(state.assembly.payload)) || return nothing
    chunk_count <= UInt32(length(state.assembly.received)) || return nothing

    header_len, header_pos, payload_len, payload_pos = bridge_chunk_var_data_positions(chunk)
    header_included && header_len != HEADER_SLOT_BYTES && return nothing
    !header_included && header_len != 0 && return nothing
    payload_len != Int(chunk_length) && return nothing
    (chunk_index == 0) == header_included || return nothing

    max_chunk = bridge_effective_chunk_bytes(state.config)
    max_chunk > 0 || return nothing
    Int(chunk_length) <= max_chunk || return nothing

    if chunk_index == 0 && chunk_offset != 0
        return nothing
    end
    Int(chunk_offset) + Int(chunk_length) <= Int(payload_length) || return nothing

    assembly = state.assembly
    timeout_ns = state.config.assembly_timeout_ns
    if timeout_ns > 0 && now_ns > assembly.last_update_ns &&
       now_ns - assembly.last_update_ns > timeout_ns
        reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
    end

    if assembly.seq != seq || assembly.epoch != epoch || assembly.chunk_count != chunk_count ||
       assembly.payload_length != payload_length
        if payload_length > UInt32(length(assembly.payload)) ||
           chunk_count > UInt32(length(assembly.received))
            return nothing
        end
        reset_bridge_assembly!(assembly, seq, epoch, chunk_count, payload_length, now_ns)
    end

    if assembly.received[Int(chunk_index) + 1]
        buf = BridgeFrameChunk.sbe_buffer(chunk)
        mismatch = false
        @inbounds for i in 1:Int(chunk_length)
            if assembly.payload[Int(chunk_offset) + i] != buf[payload_pos + i]
                mismatch = true
                break
            end
        end
        if mismatch
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
        end
        return nothing
    end

    if header_included
        copyto!(
            assembly.header_bytes,
            1,
            BridgeFrameChunk.sbe_buffer(chunk),
            header_pos + 1,
            header_len,
        )
        assembly.header_present = true
    end

    if chunk_length > 0
        copyto!(
            assembly.payload,
            Int(chunk_offset) + 1,
            BridgeFrameChunk.sbe_buffer(chunk),
            payload_pos + 1,
            Int(chunk_length),
        )
    end

    assembly.received[Int(chunk_index) + 1] = true
    assembly.received_chunks += UInt32(1)
    assembly.last_update_ns = now_ns

    if assembly.received_chunks == assembly.chunk_count && assembly.header_present
        wrap_tensor_header!(state.header_decoder, assembly.header_bytes, 0)
        values_len = TensorSlotHeader256.valuesLenBytes(state.header_decoder)
        if values_len != assembly.payload_length
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
        ndims = TensorSlotHeader256.ndims(state.header_decoder)
        dtype = TensorSlotHeader256.dtype(state.header_decoder)
        major_order = TensorSlotHeader256.majorOrder(state.header_decoder)
        if ndims > state.source_info.max_dims || !valid_dtype(dtype) || !valid_major_order(major_order)
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
        pool_id = TensorSlotHeader256.poolId(state.header_decoder)
        stride = get(state.source_info.pool_stride_bytes, pool_id, UInt32(0))
        if stride == 0 || assembly.payload_length > stride
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
        frame_id = TensorSlotHeader256.frameId(state.header_decoder)
        if frame_id != assembly.seq
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
    return BridgeAssembledFrame(
            assembly.seq,
            assembly.epoch,
            assembly.payload_length,
            assembly.header_bytes,
            assembly.payload,
        )
    end

    return nothing
end

"""
Create a FragmentAssembler for bridge payload chunks.
"""
function make_bridge_payload_assembler(state::BridgeReceiverState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = BridgeMessageHeader.Decoder(buffer, 0)
        if BridgeMessageHeader.templateId(header) == TEMPLATE_BRIDGE_FRAME_CHUNK
            BridgeFrameChunk.wrap!(st.chunk_decoder, buffer, 0; header = header)
            bridge_receive_chunk!(st, st.chunk_decoder, st.now_ns)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a FragmentAssembler for forwarded control messages.
"""
function make_bridge_control_assembler(state::BridgeReceiverState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.announce_decoder, buffer, 0; header = header)
            bridge_apply_source_announce!(st, st.announce_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll bridge receiver subscriptions and return work count.
"""
function bridge_receiver_do_work!(
    state::BridgeReceiverState;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    work_count = 0
    fetch!(state.clock)
    state.now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count += Aeron.poll(state.sub_control, state.control_assembler, fragment_limit)
    work_count += Aeron.poll(state.sub_payload, state.payload_assembler, fragment_limit)
    return work_count
end
