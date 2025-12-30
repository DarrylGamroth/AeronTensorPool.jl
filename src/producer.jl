mutable struct ProducerState
    config::ProducerConfig
    clock::Clocks.AbstractClock
    client::Aeron.Client
    pub_descriptor::Aeron.Publication
    pub_control::Aeron.Publication
    pub_qos::Aeron.Publication
    pub_metadata::Aeron.Publication
    header_mmap::Vector{UInt8}
    payload_mmaps::Dict{UInt16, Vector{UInt8}}
    epoch::UInt64
    seq::UInt64
    supports_progress::Bool
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
    last_progress_ns::UInt64
    last_announce_ns::UInt64
    last_qos_ns::UInt64
    descriptor_buf::Vector{UInt8}
    progress_buf::Vector{UInt8}
    announce_buf::Vector{UInt8}
    qos_buf::Vector{UInt8}
    superblock_encoder::ShmRegionSuperblock.Encoder{Vector{UInt8}}
    header_encoder::TensorSlotHeader256.Encoder{Vector{UInt8}}
    descriptor_encoder::FrameDescriptor.Encoder{Vector{UInt8}}
    progress_encoder::FrameProgress.Encoder{Vector{UInt8}}
    announce_encoder::ShmPoolAnnounce.Encoder{Vector{UInt8}}
    qos_encoder::QosProducer.Encoder{Vector{UInt8}}
end

function init_producer(config::ProducerConfig)
    is_pow2(config.nslots) || throw(ArgumentError("header nslots must be power of two"))
    for pool in config.payload_pools
        pool.nslots == config.nslots || throw(ArgumentError("payload nslots must match header nslots"))
    end

    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    header_size = SUPERBLOCK_SIZE + Int(config.nslots) * HEADER_SLOT_BYTES
    header_mmap = mmap_shm(config.header_uri, header_size; write = true)

    sb_encoder = ShmRegionSuperblock.Encoder(Vector{UInt8})
    wrap_superblock!(sb_encoder, header_mmap, 0)
    now_ns = UInt64(Clocks.time_nanos(clock))
    write_superblock!(
        sb_encoder,
        SuperblockFields(
            MAGIC_TPOLSHM1,
            config.layout_version,
            UInt64(1),
            config.stream_id,
            RegionType.HEADER_RING,
            UInt16(0),
            config.nslots,
            UInt32(HEADER_SLOT_BYTES),
            UInt32(0),
            UInt64(getpid()),
            now_ns,
            now_ns,
        ),
    )

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    for pool in config.payload_pools
        pool_size = SUPERBLOCK_SIZE + Int(pool.nslots) * Int(pool.stride_bytes)
        pmmap = mmap_shm(pool.uri, pool_size; write = true)
        wrap_superblock!(sb_encoder, pmmap, 0)
        write_superblock!(
            sb_encoder,
            SuperblockFields(
                MAGIC_TPOLSHM1,
                config.layout_version,
                UInt64(1),
                config.stream_id,
                RegionType.PAYLOAD_POOL,
                pool.pool_id,
                pool.nslots,
                pool.stride_bytes,
                pool.stride_bytes,
                UInt64(getpid()),
                now_ns,
                now_ns,
            ),
        )
        payload_mmaps[pool.pool_id] = pmmap
    end

    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)
    pub_metadata = Aeron.add_publication(client, config.aeron_uri, config.metadata_stream_id)

    state = ProducerState(
        config,
        clock,
        client,
        pub_descriptor,
        pub_control,
        pub_qos,
        pub_metadata,
        header_mmap,
        payload_mmaps,
        UInt64(1),
        UInt64(0),
        false,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        UInt64(0),
        UInt64(0),
        UInt64(0),
        Vector{UInt8}(undef, 512),
        Vector{UInt8}(undef, 512),
        Vector{UInt8}(undef, 1024),
        Vector{UInt8}(undef, 512),
        sb_encoder,
        TensorSlotHeader256.Encoder(Vector{UInt8}),
        FrameDescriptor.Encoder(Vector{UInt8}),
        FrameProgress.Encoder(Vector{UInt8}),
        ShmPoolAnnounce.Encoder(Vector{UInt8}),
        QosProducer.Encoder(Vector{UInt8}),
    )

    emit_announce!(state)

    return state
end

function publish_frame!(
    state::ProducerState,
    payload_data::AbstractVector{UInt8},
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    fetch!(state.clock)

    seq = state.seq
    frame_id = seq
    header_index = UInt32(seq & (UInt64(state.config.nslots) - 1))

    values_len = length(payload_data)
    pool = select_pool(state.config.payload_pools, values_len)
    pool === nothing && return false

    payload_slot = header_index
    payload_mmap = state.payload_mmaps[pool.pool_id]
    payload_offset = SUPERBLOCK_SIZE + Int(payload_slot) * Int(pool.stride_bytes)

    header_offset = header_slot_offset(header_index)
    commit_ptr = Ptr{UInt64}(pointer(state.header_mmap, header_offset + 1))
    atomic_store_u64!(commit_ptr, (frame_id << 1) | 1)

    copyto!(view(payload_mmap, payload_offset + 1:payload_offset + values_len), payload_data)

    wrap_tensor_header!(state.header_encoder, state.header_mmap, header_offset)
    write_tensor_slot_header!(
        state.header_encoder;
        frame_id = frame_id,
        timestamp_ns = UInt64(Clocks.time_nanos(state.clock)),
        meta_version = meta_version,
        values_len_bytes = UInt32(values_len),
        payload_slot = payload_slot,
        payload_offset = UInt32(0),
        pool_id = pool.pool_id,
        dtype = dtype,
        major_order = MajorOrder.ROW,
        ndims = UInt8(length(shape)),
        dims = shape,
        strides = strides,
    )

    atomic_store_u64!(commit_ptr, frame_id << 1)

    wrap_and_apply_header!(state.descriptor_encoder, state.descriptor_buf, 0)
    FrameDescriptor.streamId!(state.descriptor_encoder, state.config.stream_id)
    FrameDescriptor.epoch!(state.descriptor_encoder, state.epoch)
    FrameDescriptor.seq!(state.descriptor_encoder, seq)
    FrameDescriptor.headerIndex!(state.descriptor_encoder, header_index)
    FrameDescriptor.timestampNs!(state.descriptor_encoder, UInt64(Clocks.time_nanos(state.clock)))
    FrameDescriptor.metaVersion!(state.descriptor_encoder, meta_version)
    Aeron.offer(
        state.pub_descriptor,
        view(state.descriptor_buf, 1:sbe_encoded_length(state.descriptor_encoder)),
    )

    if state.supports_progress
        emit_progress_complete!(state, frame_id, header_index, UInt64(values_len))
    end

    state.seq += 1
    return true
end

function emit_progress_complete!(
    state::ProducerState,
    frame_id::UInt64,
    header_index::UInt32,
    bytes_filled::UInt64,
)
    wrap_and_apply_header!(state.progress_encoder, state.progress_buf, 0)
    FrameProgress.streamId!(state.progress_encoder, state.config.stream_id)
    FrameProgress.epoch!(state.progress_encoder, state.epoch)
    FrameProgress.frameId!(state.progress_encoder, frame_id)
    FrameProgress.headerIndex!(state.progress_encoder, header_index)
    FrameProgress.payloadBytesFilled!(state.progress_encoder, bytes_filled)
    FrameProgress.state!(state.progress_encoder, FrameProgressState.COMPLETE)
    Aeron.offer(
        state.pub_control,
        view(state.progress_buf, 1:sbe_encoded_length(state.progress_encoder)),
    )
    return nothing
end

function emit_announce!(state::ProducerState)
    wrap_and_apply_header!(state.announce_encoder, state.announce_buf, 0)
    ShmPoolAnnounce.streamId!(state.announce_encoder, state.config.stream_id)
    ShmPoolAnnounce.producerId!(state.announce_encoder, state.config.producer_id)
    ShmPoolAnnounce.epoch!(state.announce_encoder, state.epoch)
    ShmPoolAnnounce.layoutVersion!(state.announce_encoder, state.config.layout_version)
    ShmPoolAnnounce.headerNslots!(state.announce_encoder, state.config.nslots)
    ShmPoolAnnounce.headerSlotBytes!(state.announce_encoder, UInt16(HEADER_SLOT_BYTES))
    ShmPoolAnnounce.maxDims!(state.announce_encoder, state.config.max_dims)

    pools_group = ShmPoolAnnounce.payloadPools!(state.announce_encoder, length(state.config.payload_pools))
    for pool in state.config.payload_pools
        entry = next!(pools_group)
        ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
        ShmPoolAnnounce.PayloadPools.poolNslots!(entry, pool.nslots)
        ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
        ShmPoolAnnounce.PayloadPools.regionUri!(entry, pool.uri)
    end
    ShmPoolAnnounce.headerRegionUri!(state.announce_encoder, state.config.header_uri)

    Aeron.offer(
        state.pub_control,
        view(state.announce_buf, 1:sbe_encoded_length(state.announce_encoder)),
    )
    return nothing
end

function emit_qos!(state::ProducerState)
    wrap_and_apply_header!(state.qos_encoder, state.qos_buf, 0)
    QosProducer.streamId!(state.qos_encoder, state.config.stream_id)
    QosProducer.producerId!(state.qos_encoder, state.config.producer_id)
    QosProducer.epoch!(state.qos_encoder, state.epoch)
    QosProducer.currentSeq!(state.qos_encoder, state.seq)
    Aeron.offer(state.pub_qos, view(state.qos_buf, 1:sbe_encoded_length(state.qos_encoder)))
    return nothing
end

function handle_consumer_hello!(state::ProducerState, msg::ConsumerHello.Decoder)
    if ConsumerHello.supportsProgress(msg) == Bool_.TRUE
        state.supports_progress = true
        interval = ConsumerHello.progressIntervalUs(msg)
        bytes_delta = ConsumerHello.progressBytesDelta(msg)

        if interval != typemax(UInt32)
            state.progress_interval_ns = min(state.progress_interval_ns, UInt64(interval) * 1000)
        end
        if bytes_delta != typemax(UInt32)
            state.progress_bytes_delta = min(state.progress_bytes_delta, UInt64(bytes_delta))
        end
    end
    return nothing
end

function refresh_activity_timestamps!(state::ProducerState)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    wrap_superblock!(state.superblock_encoder, state.header_mmap, 0)
    ShmRegionSuperblock.activityTimestampNs!(state.superblock_encoder, now_ns)

    for pmmap in values(state.payload_mmaps)
        wrap_superblock!(state.superblock_encoder, pmmap, 0)
        ShmRegionSuperblock.activityTimestampNs!(state.superblock_encoder, now_ns)
    end
    return nothing
end

function emit_periodic!(state::ProducerState)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_done = false

    if now_ns - state.last_announce_ns >= state.config.announce_interval_ns
        emit_announce!(state)
        refresh_activity_timestamps!(state)
        state.last_announce_ns = now_ns
        work_done = true
    end

    if now_ns - state.last_qos_ns >= state.config.qos_interval_ns
        emit_qos!(state)
        state.last_qos_ns = now_ns
        work_done = true
    end

    return work_done
end
