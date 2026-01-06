"""
Initialize a bridge receiver for a single mapping.

Arguments:
- `config`: bridge configuration.
- `mapping`: bridge mapping definition.
- `producer_state`: optional producer state for rematerialization.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `BridgeReceiverState` initialized for receiving.
"""
function init_bridge_receiver(
    config::BridgeConfig,
    mapping::BridgeMapping;
    producer_state::Union{Nothing, ProducerState} = nothing,
    client::Aeron.Client,
    hooks::BridgeHooks = NOOP_BRIDGE_HOOKS,
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

    received = FixedSizeVectorDefault{Bool}(undef, max_chunks)
    fill!(received, false)
    assembly = BridgeAssembly(
        UInt64(0),
        UInt64(0),
        UInt32(0),
        UInt32(0),
        UInt32(0),
        FixedSizeVectorDefault{UInt8}(undef, HEADER_SLOT_BYTES),
        received,
        PolledTimer(config.assembly_timeout_ns),
        false,
        SlotClaim(0, Ptr{UInt8}(0), 0, 0, 0, 0),
        false,
    )

    source_info = BridgeSourceInfo(UInt32(0), UInt64(0), UInt32(0), UInt8(0), Dict{UInt16, UInt32}())

    dest_metadata_stream_id = ifelse(
        mapping.metadata_stream_id == 0,
        Int32(mapping.dest_stream_id),
        Int32(mapping.metadata_stream_id),
    )
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
        BridgeReceiverMetrics(UInt64(0), UInt64(0), UInt64(0), UInt64(0)),
        producer_state,
        source_info,
        assembly,
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
        TensorSlotHeaderMsg.Decoder(FixedSizeVectorDefault{UInt8}),
        FixedSizeVectorDefault{Int32}(undef, MAX_DIMS),
        FixedSizeVectorDefault{Int32}(undef, MAX_DIMS),
        false,
    )

    state.payload_assembler = make_bridge_payload_assembler(state; hooks = hooks)
    state.control_assembler = make_bridge_control_assembler(state)
    if sub_metadata !== nothing
        state.metadata_assembler = make_bridge_metadata_receiver_assembler(state)
    end
    return state
end

@inline function bridge_drop_chunk!(state::BridgeReceiverState)
    state.metrics.chunks_dropped += 1
    return false
end

"""
Write an assembled bridge frame into the destination SHM and publish a descriptor.

Arguments:
- `state`: bridge receiver state.
- `header`: decoded tensor slot header.
- `payload`: payload bytes.

Returns:
- `true` if the descriptor was published, `false` otherwise.
"""
function bridge_rematerialize!(
    state::BridgeReceiverState,
    header::TensorSlotHeader,
    payload::AbstractVector{UInt8},
)
    producer_state = state.producer_state
    producer_state === nothing && return false
    producer_driver_active(producer_state) || return false

    payload_len = Int(header.values_len_bytes)
    pool_idx = select_pool(producer_state.config.payload_pools, payload_len)
    pool_idx == 0 && return false
    pool = producer_state.config.payload_pools[pool_idx]

    seq = state.assembly.seq
    header_index = UInt32(seq & (UInt64(producer_state.config.nslots) - 1))

    payload_slot = header_index
    pool_id = pool.pool_id
    payload_mmap = producer_state.mappings.payload_mmaps[pool_id]
    payload_mmap === nothing && return false
    payload_offset = SUPERBLOCK_SIZE + Int(payload_slot) * Int(pool.stride_bytes)

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(producer_state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, seq)

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

    seqlock_commit_write!(commit_ptr, seq)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    shared_sent = let st = producer_state,
        seq = seq,
        header_index = header_index,
        meta_version = header.meta_version,
        now_ns = now_ns
        with_claimed_buffer!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
        end
    end
    per_consumer_sent = publish_descriptor_to_consumers!(producer_state, seq, header_index, header.meta_version, now_ns)
    (shared_sent || per_consumer_sent) || return false
    if producer_state.seq <= seq
        producer_state.seq = seq + 1
    end
    state.metrics.frames_rematerialized += 1
    return true
end

"""
Commit a claimed destination slot and publish a descriptor.

Arguments:
- `state`: bridge receiver state.
- `header`: decoded tensor slot header.
- `claim`: slot claim for destination payload.

Returns:
- `true` if the descriptor was published, `false` otherwise.
"""
function bridge_commit_claim!(
    state::BridgeReceiverState,
    header::TensorSlotHeader,
    claim::SlotClaim,
)
    producer_state = state.producer_state
    producer_state === nothing && return false
    producer_driver_active(producer_state) || return false

    payload_len = Int(header.values_len_bytes)
    payload_len <= claim.stride_bytes || return false
    claim.header_index == UInt32(claim.seq & (UInt64(producer_state.config.nslots) - 1)) || return false

    header_offset = header_slot_offset(claim.header_index)
    commit_ptr = header_commit_ptr_from_offset(producer_state.mappings.header_mmap, header_offset)

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
        header.timestamp_ns,
        header.meta_version,
        UInt32(payload_len),
        claim.payload_slot,
        UInt32(0),
        claim.pool_id,
        header.dtype,
        header.major_order,
        header.ndims,
        dims,
        strides,
    )

    seqlock_commit_write!(commit_ptr, claim.seq)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    shared_sent = let st = producer_state,
        seq = claim.seq,
        header_index = claim.header_index,
        meta_version = header.meta_version,
        now_ns = now_ns
        with_claimed_buffer!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
        end
    end
    per_consumer_sent = publish_descriptor_to_consumers!(producer_state, claim.seq, claim.header_index, header.meta_version, now_ns)
    (shared_sent || per_consumer_sent) || return false
    if producer_state.seq <= claim.seq
        producer_state.seq = claim.seq + 1
    end
    state.metrics.frames_rematerialized += 1
    return true
end

"""
Apply a forwarded ShmPoolAnnounce to update source info.

Arguments:
- `state`: bridge receiver state.
- `msg`: decoded ShmPoolAnnounce message.

Returns:
- `true` if applied, `false` otherwise.
"""
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
    ShmPoolAnnounce.headerRegionUri(msg, StringView)
    state.have_announce = true
    return true
end

"""
Receive a frame chunk and rematerialize when complete.

Arguments:
- `state`: bridge receiver state.
- `decoder`: decoded BridgeFrameChunk message.
- `now_ns`: current time in nanoseconds.

Returns:
- `true` if a frame was rematerialized, `false` otherwise.
"""
function bridge_receive_chunk!(
    state::BridgeReceiverState,
    decoder::BridgeFrameChunk.Decoder,
    now_ns::UInt64,
)
    state.have_announce || return bridge_drop_chunk!(state)
    BridgeFrameChunk.streamId(decoder) == state.mapping.dest_stream_id || return bridge_drop_chunk!(state)
    BridgeFrameChunk.epoch(decoder) == state.source_info.epoch || return bridge_drop_chunk!(state)

    chunk_index = Int(BridgeFrameChunk.chunkIndex(decoder))
    chunk_count = Int(BridgeFrameChunk.chunkCount(decoder))
    chunk_count == 0 && return bridge_drop_chunk!(state)
    chunk_index < chunk_count || return bridge_drop_chunk!(state)

    header_included = BridgeFrameChunk.headerIncluded(decoder) == BridgeBool.TRUE
    chunk_offset = UInt32(BridgeFrameChunk.chunkOffset(decoder))
    chunk_length = UInt32(BridgeFrameChunk.chunkLength(decoder))
    payload_length = UInt32(BridgeFrameChunk.payloadLength(decoder))
    payload_length == 0 && return bridge_drop_chunk!(state)
    payload_length > state.config.max_payload_bytes && return bridge_drop_chunk!(state)
    chunk_length == 0 && return bridge_drop_chunk!(state)
    chunk_length > payload_length && return bridge_drop_chunk!(state)
    chunk_offset > payload_length && return bridge_drop_chunk!(state)
    chunk_offset + chunk_length > payload_length && return bridge_drop_chunk!(state)
    chunk_limit = UInt32(bridge_effective_chunk_bytes(state.config))
    chunk_limit == 0 && return bridge_drop_chunk!(state)
    expected_offset = UInt32(chunk_index) * chunk_limit
    expected_offset > payload_length && return bridge_drop_chunk!(state)
    expected_len = min(chunk_limit, payload_length - expected_offset)
    chunk_offset == expected_offset || return bridge_drop_chunk!(state)
    chunk_length == expected_len || return bridge_drop_chunk!(state)

    header_bytes = BridgeFrameChunk.headerBytes(decoder)
    header_len = length(header_bytes)
    payload_bytes = BridgeFrameChunk.payloadBytes(decoder)
    payload_len = length(payload_bytes)
    UInt32(payload_len) == chunk_length || return bridge_drop_chunk!(state)

    header_included && header_len != HEADER_SLOT_BYTES && return bridge_drop_chunk!(state)
    !header_included && header_len != 0 && return bridge_drop_chunk!(state)

    (chunk_index == 0) == header_included || return bridge_drop_chunk!(state)

    if state.assembly.seq != BridgeFrameChunk.seq(decoder) ||
       state.assembly.epoch != BridgeFrameChunk.epoch(decoder)
        state.metrics.assemblies_reset += 1
        reset_bridge_assembly!(
            state.assembly,
            BridgeFrameChunk.seq(decoder),
            BridgeFrameChunk.epoch(decoder),
            UInt32(chunk_count),
            payload_length,
            now_ns,
        )
    elseif state.assembly.chunk_count != UInt32(chunk_count) ||
           state.assembly.payload_length != payload_length
        state.metrics.assemblies_reset += 1
        reset_bridge_assembly!(
            state.assembly,
            BridgeFrameChunk.seq(decoder),
            BridgeFrameChunk.epoch(decoder),
            UInt32(chunk_count),
            payload_length,
            now_ns,
        )
    end

    if chunk_index >= length(state.assembly.received)
        return bridge_drop_chunk!(state)
    end

    if state.assembly.received[chunk_index + 1]
        return bridge_drop_chunk!(state)
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

    if !state.assembly.claim_ready
        state.assembly.header_present || return bridge_drop_chunk!(state)
        producer_state = state.producer_state
        producer_state === nothing && return bridge_drop_chunk!(state)
        producer_driver_active(producer_state) || return bridge_drop_chunk!(state)

        wrap_tensor_header!(state.header_decoder, state.assembly.header_bytes, 0)
        header = read_tensor_slot_header(state.header_decoder)
        seqlock_is_committed(header.seq_commit) || return bridge_drop_chunk!(state)
        seqlock_sequence(header.seq_commit) == state.assembly.seq || return bridge_drop_chunk!(state)
        header.ndims <= state.source_info.max_dims || return bridge_drop_chunk!(state)
        UInt32(header.values_len_bytes) == payload_length || return bridge_drop_chunk!(state)
        source_stride = get(state.source_info.pool_stride_bytes, header.pool_id, UInt32(0))
        source_stride == 0 && return bridge_drop_chunk!(state)
        payload_length <= source_stride || return bridge_drop_chunk!(state)

        pool_idx = select_pool(producer_state.config.payload_pools, Int(payload_length))
        pool_idx == 0 && return bridge_drop_chunk!(state)
        pool = producer_state.config.payload_pools[pool_idx]
        payload_length <= pool.stride_bytes || return bridge_drop_chunk!(state)
        producer_state.seq > state.assembly.seq && return bridge_drop_chunk!(state)
        producer_state.seq = state.assembly.seq

        claim = try_claim_slot!(producer_state, pool.pool_id)
        payload_length <= claim.stride_bytes || return bridge_drop_chunk!(state)
        state.assembly.slot_claim = claim
        state.assembly.claim_ready = true
    end

    claim = state.assembly.slot_claim
    payload_start = Int(chunk_offset)
    payload_start + payload_len > claim.stride_bytes && return bridge_drop_chunk!(state)
    dest_ptr = claim.ptr + payload_start
    unsafe_copyto!(dest_ptr, pointer(payload_bytes), payload_len)
    state.assembly.received[chunk_index + 1] = true
    state.assembly.received_chunks += 1
    reset!(state.assembly.assembly_timer, now_ns)

    if state.assembly.received_chunks != state.assembly.chunk_count ||
       !state.assembly.header_present
        return false
    end

    wrap_tensor_header!(state.header_decoder, state.assembly.header_bytes, 0)
    header = read_tensor_slot_header(state.header_decoder)

    seqlock_is_committed(header.seq_commit) || return bridge_drop_chunk!(state)
    seqlock_sequence(header.seq_commit) == state.assembly.seq || return bridge_drop_chunk!(state)
    header.ndims <= state.source_info.max_dims || return bridge_drop_chunk!(state)
    UInt32(header.values_len_bytes) == payload_length || return bridge_drop_chunk!(state)
    source_stride = get(state.source_info.pool_stride_bytes, header.pool_id, UInt32(0))
    source_stride == 0 && return bridge_drop_chunk!(state)
    payload_length <= source_stride || return bridge_drop_chunk!(state)

    return bridge_commit_claim!(state, header, state.assembly.slot_claim)
end
