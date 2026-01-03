"""
Initialize a bridge sender using an existing consumer mapping.
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
    source_control = mapping.source_control_stream_id == 0 ? consumer_state.config.control_stream_id :
        mapping.source_control_stream_id
    sub_control = Aeron.add_subscription(client, consumer_state.config.aeron_uri, source_control)
    pub_metadata = nothing
    sub_metadata = nothing
    metadata_assembler = nothing
    if config.forward_metadata && !isempty(config.metadata_channel)
        pub_metadata = Aeron.add_publication(client, config.metadata_channel, config.metadata_stream_id)
        sub_metadata = Aeron.add_subscription(client, consumer_state.config.aeron_uri, config.source_metadata_stream_id)
    end
    state = BridgeSenderState(
        consumer_state,
        config,
        mapping,
        client,
        pub_payload,
        pub_control,
        pub_metadata,
        BridgeFrameChunk.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeader256.Decoder(Vector{UInt8}),
        FixedSizeVectorDefault{UInt8}(undef, HEADER_SLOT_BYTES),
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
"""
function bridge_send_frame!(state::BridgeSenderState, desc::FrameDescriptor.Decoder)
    FrameDescriptor.epoch(desc) == state.consumer_state.mappings.mapped_epoch || return false
    header_index = FrameDescriptor.headerIndex(desc)
    header_index >= state.consumer_state.mappings.mapped_nslots && return false

    header_offset = header_slot_offset(header_index)
    header_mmap = state.consumer_state.mappings.header_mmap
    header_mmap === nothing && return false
    header_mmap_vec = header_mmap::Vector{UInt8}

    commit_ptr = header_commit_ptr_from_offset(header_mmap_vec, header_offset)
    first = seqlock_read_begin(commit_ptr)
    seqlock_is_write_in_progress(first) && return false

    header = try
        wrap_tensor_header!(state.header_decoder, header_mmap_vec, header_offset)
        read_tensor_slot_header(state.header_decoder)
    catch
        return false
    end

    second = seqlock_read_end(commit_ptr)
    if first != second || seqlock_is_write_in_progress(second)
        return false
    end

    if seqlock_frame_id(second) != header.frame_id || header.frame_id != FrameDescriptor.seq(desc)
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
    chunk_count = UInt32(cld(total_payload_bytes, chunk_bytes))

    for chunk_index in 0:(chunk_count - 1)
        payload_pos = payload_offset + chunk_index * chunk_bytes
        remaining = total_payload_bytes - chunk_index * chunk_bytes
        payload_chunk_len = min(chunk_bytes, remaining)
        header_included = chunk_index == 0
        header_len = header_included ? HEADER_SLOT_BYTES : 0
        msg_len = bridge_chunk_message_length(header_len, payload_chunk_len)
        sent = let st = state,
            header_included = header_included,
            header_len = header_len,
            payload_chunk_len = payload_chunk_len,
            header = header,
            payload_mmap_vec = payload_mmap_vec,
            payload_pos = payload_pos,
            chunk_index = chunk_index,
            chunk_count = chunk_count
            with_claimed_buffer!(st.pub_payload, st.chunk_claim, msg_len) do buf
                BridgeFrameChunk.wrap_and_apply_header!(st.chunk_encoder, buf, 0)
                BridgeFrameChunk.streamId!(st.chunk_encoder, st.mapping.dest_stream_id)
                BridgeFrameChunk.epoch!(st.chunk_encoder, FrameDescriptor.epoch(desc))
                BridgeFrameChunk.seq!(st.chunk_encoder, FrameDescriptor.seq(desc))
                BridgeFrameChunk.chunkIndex!(st.chunk_encoder, UInt32(chunk_index))
                BridgeFrameChunk.chunkCount!(st.chunk_encoder, chunk_count)
                BridgeFrameChunk.payloadLength!(st.chunk_encoder, UInt32(total_payload_bytes))
                BridgeFrameChunk.headerIncluded!(
                    st.chunk_encoder,
                    header_included ? BridgeBool.TRUE : BridgeBool.FALSE,
                )
                if header_included
                    header_src = state.header_buf
                    copyto!(header_src, 1, header_mmap_vec, header_offset + 1, HEADER_SLOT_BYTES)
                    BridgeFrameChunk.headerBytes!(st.chunk_encoder, header_src)
                else
                    BridgeFrameChunk.headerBytes!(st.chunk_encoder, nothing)
                end
                BridgeFrameChunk.payloadBytes!(
                    st.chunk_encoder,
                    view(payload_mmap_vec, payload_pos + 1:payload_pos + payload_chunk_len),
                )
            end
        end
        sent || return false
    end

    return true
end
