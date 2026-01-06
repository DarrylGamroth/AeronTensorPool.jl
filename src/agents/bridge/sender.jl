"""
Initialize a bridge sender using an existing consumer mapping.

Arguments:
- `consumer_state`: consumer state providing SHM mappings.
- `config`: bridge configuration.
- `mapping`: bridge mapping definition.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `BridgeSenderState` initialized for forwarding.
"""
function init_bridge_sender(
    consumer_state::ConsumerState,
    config::BridgeConfig,
    mapping::BridgeMapping;
    client::Aeron.Client,
)
    if (config.forward_progress || config.forward_qos) &&
       (mapping.source_control_stream_id == 0 || mapping.dest_control_stream_id == 0)
        throw(ArgumentError("bridge mapping requires nonzero control stream IDs for progress/QoS forwarding"))
    end
    pub_payload = Aeron.add_publication(client, config.payload_channel, config.payload_stream_id)
    pub_control = Aeron.add_publication(client, config.control_channel, config.control_stream_id)
    source_control = ifelse(
        mapping.source_control_stream_id == 0,
        consumer_state.config.control_stream_id,
        mapping.source_control_stream_id,
    )
    sub_control = Aeron.add_subscription(client, consumer_state.config.aeron_uri, source_control)
    pub_metadata = nothing
    sub_metadata = nothing
    metadata_assembler = nothing
    if config.forward_metadata && !isempty(config.metadata_channel)
        pub_metadata = Aeron.add_publication(client, config.metadata_channel, config.metadata_stream_id)
        sub_metadata = Aeron.add_subscription(client, consumer_state.config.aeron_uri, config.source_metadata_stream_id)
    end
    chunk_encoder = BridgeFrameChunk.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
    chunk_fill = BridgeChunkFill(
        chunk_encoder,
        mapping.dest_stream_id,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        Vector{UInt8}(undef, 0),
        0,
        Vector{UInt8}(undef, 0),
        0,
        0,
    )
    state = BridgeSenderState(
        consumer_state,
        config,
        mapping,
        BridgeSenderMetrics(UInt64(0), UInt64(0), UInt64(0), UInt64(0)),
        client,
        pub_payload,
        pub_control,
        pub_metadata,
        chunk_encoder,
        Aeron.BufferClaim(),
        chunk_fill,
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeaderMsg.Decoder(Vector{UInt8}),
        FixedSizeVectorDefault{Int32}(undef, MAX_DIMS),
        FixedSizeVectorDefault{Int32}(undef, MAX_DIMS),
        UInt64(0),
        sub_control,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        sub_metadata,
        metadata_assembler,
        DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    if sub_metadata !== nothing
        state.metadata_assembler = make_bridge_metadata_sender_assembler(state)
    end
    state.control_assembler = make_bridge_control_sender_assembler(state)
    return state
end

"""
Chunk and forward a frame payload based on a FrameDescriptor.

Arguments:
- `state`: bridge sender state.
- `desc`: decoded frame descriptor.

Returns:
- `true` if any chunks were published, `false` otherwise.
"""
function bridge_send_frame!(state::BridgeSenderState, desc::FrameDescriptor.Decoder)
    FrameDescriptor.streamId(desc) == state.mapping.source_stream_id || return false
    FrameDescriptor.epoch(desc) == state.consumer_state.mappings.mapped_epoch || return false
    header_index = FrameDescriptor.headerIndex(desc)
    header_index >= state.consumer_state.mappings.mapped_nslots && return false

    header_offset = header_slot_offset(header_index)
    header_mmap = state.consumer_state.mappings.header_mmap
    header_mmap === nothing && return false
    header_mmap_vec = header_mmap::Vector{UInt8}

    commit_ptr = header_commit_ptr_from_offset(header_mmap_vec, header_offset)
    first = seqlock_read_begin(commit_ptr)
    seqlock_is_committed(first) || return false

    header_offset + HEADER_SLOT_BYTES <= length(header_mmap_vec) || return false
    wrap_tensor_header!(state.header_decoder, header_mmap_vec, header_offset)
    header = read_tensor_slot_header(state.header_decoder)

    second = seqlock_read_end(commit_ptr)
    if first != second || !seqlock_is_committed(second)
        return false
    end

    if header.seq_commit != second
        return false
    end
    if seqlock_sequence(second) != FrameDescriptor.seq(desc)
        return false
    end

    pool_stride = get(state.consumer_state.mappings.pool_stride_bytes, header.pool_id, UInt32(0))
    pool_stride == 0 && return false
    payload_mmap = get(state.consumer_state.mappings.payload_mmaps, header.pool_id, nothing)
    payload_mmap === nothing && return false

    payload_len = Int(header.values_len_bytes)
    payload_len <= Int(pool_stride) || return false

    payload_offset = SUPERBLOCK_SIZE + Int(header.payload_slot) * Int(pool_stride)
    payload_mmap_vec = payload_mmap::Vector{UInt8}

    header_included = false
    total_payload_bytes = payload_len
    chunk_bytes = bridge_effective_chunk_bytes(state.config)
    chunk_bytes > 0 || return false
    chunk_bytes = min(chunk_bytes, total_payload_bytes)
    chunk_count = cld(total_payload_bytes, chunk_bytes)
    chunk_count_u32 = UInt32(chunk_count)
    fill = state.chunk_fill
    fill.dest_stream_id = state.mapping.dest_stream_id
    fill.epoch = FrameDescriptor.epoch(desc)
    fill.seq = FrameDescriptor.seq(desc)
    fill.payload_length = UInt32(total_payload_bytes)
    fill.header_mmap_vec = header_mmap_vec
    fill.header_offset = header_offset
    fill.payload_mmap_vec = payload_mmap_vec

    for chunk_index in 0:(chunk_count - 1)
        payload_pos = payload_offset + chunk_index * chunk_bytes
        remaining = total_payload_bytes - chunk_index * chunk_bytes
        payload_chunk_len = min(chunk_bytes, remaining)
        header_included = chunk_index == 0
        header_len = ifelse(header_included, HEADER_SLOT_BYTES, 0)
        msg_len = bridge_chunk_message_length(header_len, payload_chunk_len)
        fill.chunk_index = UInt32(chunk_index)
        fill.chunk_count = chunk_count_u32
        fill.chunk_offset = UInt32(chunk_index * chunk_bytes)
        fill.chunk_length = UInt32(payload_chunk_len)
        fill.header_included = header_included
        fill.payload_pos = payload_pos
        fill.payload_chunk_len = payload_chunk_len
        sent = with_claimed_buffer!(fill, state.pub_payload, state.chunk_claim, msg_len)
        if sent
            state.metrics.chunks_sent += 1
        else
            state.metrics.chunks_dropped += 1
            @tp_warn "bridge payload claim failed" stream_id = state.mapping.dest_stream_id
            return false
        end
    end

    state.metrics.frames_forwarded += 1
    return true
end
