"""
Initialize a bridge receiver for a single mapping.
"""
function init_bridge_receiver(
    config::BridgeConfig,
    mapping::BridgeMapping;
    producer_state::Union{Nothing, ProducerState} = nothing,
    client::Aeron.Client,
)
    if (config.forward_progress || config.forward_qos) &&
       (mapping.source_control_stream_id == 0 || mapping.dest_control_stream_id == 0)
        throw(ArgumentError("bridge mapping requires nonzero control stream IDs for progress/QoS forwarding"))
    end
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

    dest_metadata_stream_id =
        mapping.metadata_stream_id == 0 ? Int32(mapping.dest_stream_id) : Int32(mapping.metadata_stream_id)
    pub_metadata_local = nothing
    sub_metadata = nothing
    metadata_assembler = nothing
    if config.forward_metadata && !isempty(config.metadata_channel)
        sub_metadata = Aeron.add_subscription(client, config.metadata_channel, config.metadata_stream_id)
        pub_metadata_local = Aeron.add_publication(client, "aeron:ipc", dest_metadata_stream_id)
    end
    pub_control_local = nothing
    if (config.forward_qos || config.forward_progress) && mapping.dest_control_stream_id != 0
        pub_control_local = Aeron.add_publication(client, "aeron:ipc", mapping.dest_control_stream_id)
    end

    state = BridgeReceiverState(
        config,
        mapping,
        client,
        clock,
        UInt64(0),
        producer_state,
        sub_payload,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        sub_control,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        sub_metadata,
        metadata_assembler,
        pub_metadata_local,
        Aeron.BufferClaim(),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        pub_control_local,
        Aeron.BufferClaim(),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        BridgeFrameChunk.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeader256.Decoder(Vector{UInt8}),
        Vector{Int32}(undef, MAX_DIMS),
        Vector{Int32}(undef, MAX_DIMS),
        source_info,
        assembly,
        false,
    )

    state.payload_assembler = make_bridge_payload_assembler(state)
    state.control_assembler = make_bridge_control_assembler(state)
    if sub_metadata !== nothing
        state.metadata_assembler = make_bridge_metadata_receiver_assembler(state)
    end
    return state
end

function bridge_rematerialize!(
    state::BridgeReceiverState,
    header::TensorSlotHeader,
    payload::AbstractVector{UInt8},
)
    producer_state = state.producer_state
    producer_state === nothing && return false
    producer_driver_active(producer_state) || return false

    pool_id = header.pool_id
    payload_len = Int(header.values_len_bytes)
    pool = payload_pool_config(producer_state, pool_id)
    pool === nothing && return false
    payload_len <= Int(pool.stride_bytes) || return false

    seq = state.assembly.seq
    frame_id = seq
    header_index = UInt32(seq & (UInt64(producer_state.config.nslots) - 1))

    payload_slot = header_index
    payload_mmap = producer_state.mappings.payload_mmaps[pool_id]
    payload_offset = SUPERBLOCK_SIZE + Int(payload_slot) * Int(pool.stride_bytes)

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(producer_state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, frame_id)

    copyto!(payload_mmap, payload_offset + 1, payload, 1, payload_len)

    wrap_tensor_header!(producer_state.runtime.header_encoder, producer_state.mappings.header_mmap, header_offset)
    dims = state.scratch_dims
    strides = state.scratch_strides
    fill!(dims, Int32(0))
    fill!(strides, Int32(0))
    ndims = Int(header.ndims)
    for i in 1:ndims
        dims[i] = header.dims[i]
        strides[i] = header.strides[i]
    end
    write_tensor_slot_header!(
        producer_state.runtime.header_encoder,
        frame_id,
        header.timestamp_ns,
        header.meta_version,
        UInt32(payload_len),
        payload_slot,
        UInt32(0),
        pool_id,
        header.dtype,
        header.major_order,
        header.ndims,
        dims,
        strides,
    )

    seqlock_commit_write!(commit_ptr, frame_id)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    shared_sent = let st = producer_state,
        seq = seq,
        header_index = header_index,
        meta_version = header.meta_version,
        now_ns = now_ns
        try_claim_sbe!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
        end
    end
    per_consumer_sent = publish_descriptor_to_consumers!(producer_state, seq, header_index, header.meta_version, now_ns)
    (shared_sent || per_consumer_sent) || return false
    if producer_state.seq <= seq
        producer_state.seq = seq + 1
    end
    return true
end

function bridge_apply_source_announce!(state::BridgeReceiverState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.mapping.dest_stream_id || return false
    state.source_info.stream_id = ShmPoolAnnounce.streamId(msg)
    state.source_info.epoch = ShmPoolAnnounce.epoch(msg)
    state.source_info.layout_version = ShmPoolAnnounce.layoutVersion(msg)
    state.source_info.max_dims = ShmPoolAnnounce.maxDims(msg)
    empty!(state.source_info.pool_stride_bytes)
    pools = ShmPoolAnnounce.payloadPools(msg)
    for pool in pools
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        state.source_info.pool_stride_bytes[pool_id] = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
    end
    state.have_announce = true
    return true
end

function bridge_receive_chunk!(
    state::BridgeReceiverState,
    decoder::BridgeFrameChunk.Decoder,
    now_ns::UInt64,
)
    BridgeFrameChunk.streamId(decoder) == state.mapping.dest_stream_id || return false

    chunk_index = BridgeFrameChunk.chunkIndex(decoder)
    chunk_count = BridgeFrameChunk.chunkCount(decoder)
    chunk_count == 0 && return false
    chunk_index < chunk_count || return false

    header_included = BridgeFrameChunk.headerIncluded(decoder) == BridgeBool.TRUE
    payload_length = BridgeFrameChunk.payloadLength(decoder)
    header_bytes = BridgeFrameChunk.headerBytes(decoder)
    header_len = length(header_bytes)
    payload_bytes = BridgeFrameChunk.payloadBytes(decoder)
    payload_len = length(payload_bytes)

    header_included && header_len != HEADER_SLOT_BYTES && return false
    !header_included && header_len != 0 && return false

    (chunk_index == 0) == header_included || return false

    if state.assembly.seq != BridgeFrameChunk.seq(decoder) ||
       state.assembly.epoch != BridgeFrameChunk.epoch(decoder)
        reset_bridge_assembly!(
            state.assembly,
            BridgeFrameChunk.seq(decoder),
            BridgeFrameChunk.epoch(decoder),
            chunk_count,
            payload_length,
            now_ns,
        )
    elseif state.assembly.chunk_count != chunk_count ||
           state.assembly.payload_length != payload_length
        reset_bridge_assembly!(
            state.assembly,
            BridgeFrameChunk.seq(decoder),
            BridgeFrameChunk.epoch(decoder),
            chunk_count,
            payload_length,
            now_ns,
        )
    end

    if payload_length > length(state.assembly.payload)
        return false
    end

    if chunk_index >= length(state.assembly.received)
        return false
    end

    if state.assembly.received[chunk_index + 1]
        return false
    end

    if header_included
        copyto!(
            state.assembly.header_bytes,
            1,
            header_bytes,
            1,
            HEADER_SLOT_BYTES,
        )
        state.assembly.header_present = true
    end

    payload_start = chunk_index * bridge_effective_chunk_bytes(state.config)
    if payload_start + payload_len > length(state.assembly.payload)
        return false
    end

    copyto!(
        state.assembly.payload,
        payload_start + 1,
        payload_bytes,
        1,
        payload_len,
    )
    state.assembly.received[chunk_index + 1] = true
    state.assembly.received_chunks += 1
    state.assembly.last_update_ns = now_ns

    if state.assembly.received_chunks != state.assembly.chunk_count ||
       !state.assembly.header_present
        return false
    end

    wrap_tensor_header!(state.header_decoder, state.assembly.header_bytes, 0)
    header = read_tensor_slot_header(state.header_decoder)

    header.frame_id == state.assembly.seq || return false
    header.ndims <= state.source_info.max_dims || return false

    state.assembly.payload_length <= length(state.assembly.payload) || return false
    return bridge_rematerialize!(
        state,
        header,
        view(state.assembly.payload, 1:Int(state.assembly.payload_length)),
    )
end
