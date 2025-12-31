mutable struct ProducerState
    config::ProducerConfig
    clock::Clocks.AbstractClock
    client::Aeron.Client
    pub_descriptor::Aeron.Publication
    pub_control::Aeron.Publication
    pub_qos::Aeron.Publication
    pub_metadata::Aeron.Publication
    sub_control::Aeron.Subscription
    header_mmap::Vector{UInt8}
    payload_mmaps::Dict{UInt16, Vector{UInt8}}
    epoch::UInt64
    seq::UInt64
    supports_progress::Bool
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
    last_progress_ns::UInt64
    last_progress_bytes::UInt64
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
    descriptor_claim::Aeron.BufferClaim
    progress_claim::Aeron.BufferClaim
    qos_claim::Aeron.BufferClaim
    hello_decoder::ConsumerHello.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

@inline function should_emit_progress!(state::ProducerState, bytes_filled::UInt64, final::Bool)
    if final
        return true
    end
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    if now_ns - state.last_progress_ns < state.progress_interval_ns &&
       bytes_filled - state.last_progress_bytes < state.progress_bytes_delta
        return false
    end
    return true
end

function init_producer(config::ProducerConfig)
    ispow2(config.nslots) || throw(ArgumentError("header nslots must be power of two"))
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
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)

    state = ProducerState(
        config,
        clock,
        client,
        pub_descriptor,
        pub_control,
        pub_qos,
        pub_metadata,
        sub_control,
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
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )

    emit_announce!(state)

    return state
end

function encode_frame_descriptor!(
    enc::FrameDescriptor.Encoder,
    state::ProducerState,
    seq::UInt64,
    header_index::UInt32,
    meta_version::UInt32,
    now_ns::UInt64,
)
    FrameDescriptor.streamId!(enc, state.config.stream_id)
    FrameDescriptor.epoch!(enc, state.epoch)
    FrameDescriptor.seq!(enc, seq)
    FrameDescriptor.headerIndex!(enc, header_index)
    FrameDescriptor.timestampNs!(enc, now_ns)
    FrameDescriptor.metaVersion!(enc, meta_version)
    return nothing
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

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    sent = try_claim_sbe!(state.pub_descriptor, state.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, buf, 0)
        encode_frame_descriptor!(state.descriptor_encoder, state, seq, header_index, meta_version, now_ns)
    end
    if !sent
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, state.descriptor_buf, 0)
        encode_frame_descriptor!(state.descriptor_encoder, state, seq, header_index, meta_version, now_ns)
        Aeron.offer(
            state.pub_descriptor,
            view(state.descriptor_buf, 1:sbe_message_length(state.descriptor_encoder)),
        )
    end

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
        emit_progress_complete!(state, frame_id, header_index, UInt64(values_len))
    end

    state.seq += 1
    return true
end

@inline function next_header_index(state::ProducerState)
    return UInt32(state.seq & (UInt64(state.config.nslots) - 1))
end

function payload_pool_config(state::ProducerState, pool_id::UInt16)
    for pool in state.config.payload_pools
        if pool.pool_id == pool_id
            return pool
        end
    end
    return nothing
end

function payload_slot_ptr(state::ProducerState, pool_id::UInt16, slot::UInt32)
    pool = payload_pool_config(state, pool_id)
    pool === nothing && error("Unknown pool_id: $pool_id")
    slot < pool.nslots || error("Slot out of range: $slot")
    payload_mmap = state.payload_mmaps[pool.pool_id]
    return payload_slot_ptr(payload_mmap, pool.stride_bytes, slot)
end

function payload_slot_view(
    state::ProducerState,
    pool_id::UInt16,
    slot::UInt32;
    len::Integer = -1,
)
    pool = payload_pool_config(state, pool_id)
    pool === nothing && error("Unknown pool_id: $pool_id")
    slot < pool.nslots || error("Slot out of range: $slot")
    payload_mmap = state.payload_mmaps[pool.pool_id]
    view_len = len < 0 ? Int(pool.stride_bytes) : Int(len)
    return payload_slot_view(payload_mmap, pool.stride_bytes, slot, view_len)
end

struct SlotReservation
    seq::UInt64
    header_index::UInt32
    pool_id::UInt16
    payload_slot::UInt32
    ptr::Ptr{UInt8}
    stride_bytes::Int
end

mutable struct InflightQueue
    items::Vector{SlotReservation}
    head::Int
    tail::Int
    count::Int
end

function InflightQueue(capacity::Integer)
    capacity > 0 || throw(ArgumentError("capacity must be > 0"))
    return InflightQueue(Vector{SlotReservation}(undef, capacity), 1, 1, 0)
end

@inline function inflight_empty(q::InflightQueue)
    return q.count == 0
end

@inline function inflight_full(q::InflightQueue)
    return q.count == length(q.items)
end

function inflight_push!(q::InflightQueue, reservation::SlotReservation)
    inflight_full(q) && return false
    q.items[q.tail] = reservation
    q.tail = q.tail == length(q.items) ? 1 : q.tail + 1
    q.count += 1
    return true
end

function inflight_peek(q::InflightQueue)
    inflight_empty(q) && return nothing
    return q.items[q.head]
end

function inflight_pop!(q::InflightQueue)
    inflight_empty(q) && return nothing
    item = q.items[q.head]
    q.head = q.head == length(q.items) ? 1 : q.head + 1
    q.count -= 1
    return item
end

function reserve_slot!(state::ProducerState, pool_id::UInt16)
    pool = payload_pool_config(state, pool_id)
    pool === nothing && error("Unknown pool_id: $pool_id")

    seq = state.seq
    header_index = next_header_index(state)
    payload_slot = header_index
    payload_slot < pool.nslots || error("Slot out of range: $payload_slot")

    ptr, stride_bytes = payload_slot_ptr(state, pool_id, payload_slot)
    state.seq += 1

    return SlotReservation(seq, header_index, pool_id, payload_slot, ptr, stride_bytes)
end

function publish_reservation!(
    state::ProducerState,
    reservation::SlotReservation,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    pool = payload_pool_config(state, reservation.pool_id)
    pool === nothing && return false
    values_len <= reservation.stride_bytes || return false

    expected_index = UInt32(reservation.seq & (UInt64(state.config.nslots) - 1))
    reservation.header_index == expected_index || return false

    fetch!(state.clock)
    frame_id = reservation.seq

    header_offset = header_slot_offset(reservation.header_index)
    commit_ptr = Ptr{UInt64}(pointer(state.header_mmap, header_offset + 1))
    atomic_store_u64!(commit_ptr, (frame_id << 1) | 1)

    wrap_tensor_header!(state.header_encoder, state.header_mmap, header_offset)
    write_tensor_slot_header!(
        state.header_encoder;
        frame_id = frame_id,
        timestamp_ns = UInt64(Clocks.time_nanos(state.clock)),
        meta_version = meta_version,
        values_len_bytes = UInt32(values_len),
        payload_slot = reservation.payload_slot,
        payload_offset = UInt32(0),
        pool_id = reservation.pool_id,
        dtype = dtype,
        major_order = MajorOrder.ROW,
        ndims = UInt8(length(shape)),
        dims = shape,
        strides = strides,
    )

    atomic_store_u64!(commit_ptr, frame_id << 1)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    sent = try_claim_sbe!(state.pub_descriptor, state.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, buf, 0)
        encode_frame_descriptor!(
            state.descriptor_encoder,
            state,
            reservation.seq,
            reservation.header_index,
            meta_version,
            now_ns,
        )
    end
    if !sent
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, state.descriptor_buf, 0)
        encode_frame_descriptor!(
            state.descriptor_encoder,
            state,
            reservation.seq,
            reservation.header_index,
            meta_version,
            now_ns,
        )
        Aeron.offer(
            state.pub_descriptor,
            view(state.descriptor_buf, 1:sbe_message_length(state.descriptor_encoder)),
        )
    end

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
        emit_progress_complete!(state, frame_id, reservation.header_index, UInt64(values_len))
    end

    return true
end

function publish_frame_from_slot!(
    state::ProducerState,
    pool_id::UInt16,
    payload_slot::UInt32,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    fetch!(state.clock)

    seq = state.seq
    frame_id = seq
    header_index = next_header_index(state)
    payload_slot == header_index || error("payload_slot must equal header_index for seq=$seq")

    pool = payload_pool_config(state, pool_id)
    pool === nothing && return false
    values_len <= Int(pool.stride_bytes) || return false

    header_offset = header_slot_offset(header_index)
    commit_ptr = Ptr{UInt64}(pointer(state.header_mmap, header_offset + 1))
    atomic_store_u64!(commit_ptr, (frame_id << 1) | 1)

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

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    sent = try_claim_sbe!(state.pub_descriptor, state.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, buf, 0)
        encode_frame_descriptor!(state.descriptor_encoder, state, seq, header_index, meta_version, now_ns)
    end
    if !sent
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, state.descriptor_buf, 0)
        encode_frame_descriptor!(state.descriptor_encoder, state, seq, header_index, meta_version, now_ns)
        Aeron.offer(
            state.pub_descriptor,
            view(state.descriptor_buf, 1:sbe_message_length(state.descriptor_encoder)),
        )
    end

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
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
    sent = try_claim_sbe!(state.pub_control, state.progress_claim, FRAME_PROGRESS_LEN) do buf
        FrameProgress.wrap_and_apply_header!(state.progress_encoder, buf, 0)
        FrameProgress.streamId!(state.progress_encoder, state.config.stream_id)
        FrameProgress.epoch!(state.progress_encoder, state.epoch)
        FrameProgress.frameId!(state.progress_encoder, frame_id)
        FrameProgress.headerIndex!(state.progress_encoder, header_index)
        FrameProgress.payloadBytesFilled!(state.progress_encoder, bytes_filled)
        FrameProgress.state!(state.progress_encoder, FrameProgressState.COMPLETE)
    end
    if !sent
        FrameProgress.wrap_and_apply_header!(state.progress_encoder, state.progress_buf, 0)
        FrameProgress.streamId!(state.progress_encoder, state.config.stream_id)
        FrameProgress.epoch!(state.progress_encoder, state.epoch)
        FrameProgress.frameId!(state.progress_encoder, frame_id)
        FrameProgress.headerIndex!(state.progress_encoder, header_index)
        FrameProgress.payloadBytesFilled!(state.progress_encoder, bytes_filled)
        FrameProgress.state!(state.progress_encoder, FrameProgressState.COMPLETE)
        Aeron.offer(
            state.pub_control,
            view(state.progress_buf, 1:sbe_message_length(state.progress_encoder)),
        )
    end
    state.last_progress_ns = UInt64(Clocks.time_nanos(state.clock))
    state.last_progress_bytes = bytes_filled
    return nothing
end

function emit_announce!(state::ProducerState)
    ShmPoolAnnounce.wrap_and_apply_header!(state.announce_encoder, state.announce_buf, 0)
    ShmPoolAnnounce.streamId!(state.announce_encoder, state.config.stream_id)
    ShmPoolAnnounce.producerId!(state.announce_encoder, state.config.producer_id)
    ShmPoolAnnounce.epoch!(state.announce_encoder, state.epoch)
    ShmPoolAnnounce.layoutVersion!(state.announce_encoder, state.config.layout_version)
    ShmPoolAnnounce.headerNslots!(state.announce_encoder, state.config.nslots)
    ShmPoolAnnounce.headerSlotBytes!(state.announce_encoder, UInt16(HEADER_SLOT_BYTES))
    ShmPoolAnnounce.maxDims!(state.announce_encoder, state.config.max_dims)

    pools_group = ShmPoolAnnounce.payloadPools!(state.announce_encoder, length(state.config.payload_pools))
    for pool in state.config.payload_pools
        entry = ShmPoolAnnounce.PayloadPools.next!(pools_group)
        ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
        ShmPoolAnnounce.PayloadPools.poolNslots!(entry, pool.nslots)
        ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
        ShmPoolAnnounce.PayloadPools.regionUri!(entry, pool.uri)
    end
    ShmPoolAnnounce.headerRegionUri!(state.announce_encoder, state.config.header_uri)

    Aeron.offer(
        state.pub_control,
        view(state.announce_buf, 1:sbe_message_length(state.announce_encoder)),
    )
    return nothing
end

function emit_qos!(state::ProducerState)
    sent = try_claim_sbe!(state.pub_qos, state.qos_claim, QOS_PRODUCER_LEN) do buf
        QosProducer.wrap_and_apply_header!(state.qos_encoder, buf, 0)
        QosProducer.streamId!(state.qos_encoder, state.config.stream_id)
        QosProducer.producerId!(state.qos_encoder, state.config.producer_id)
        QosProducer.epoch!(state.qos_encoder, state.epoch)
        QosProducer.currentSeq!(state.qos_encoder, state.seq)
    end
    if !sent
        QosProducer.wrap_and_apply_header!(state.qos_encoder, state.qos_buf, 0)
        QosProducer.streamId!(state.qos_encoder, state.config.stream_id)
        QosProducer.producerId!(state.qos_encoder, state.config.producer_id)
        QosProducer.epoch!(state.qos_encoder, state.epoch)
        QosProducer.currentSeq!(state.qos_encoder, state.seq)
        Aeron.offer(state.pub_qos, view(state.qos_buf, 1:sbe_message_length(state.qos_encoder)))
    end
    return nothing
end

function handle_consumer_hello!(state::ProducerState, msg::ConsumerHello.Decoder)
    if ConsumerHello.supportsProgress(msg) == ShmTensorpoolControl.Bool_.TRUE
        state.supports_progress = true
        interval = ConsumerHello.progressIntervalUs(msg)
        bytes_delta = ConsumerHello.progressBytesDelta(msg)

        if interval != typemax(UInt32)
            hint_ns = UInt64(interval) * 1000
            state.progress_interval_ns = max(
                state.config.progress_interval_ns,
                min(state.progress_interval_ns, hint_ns),
            )
        end
        if bytes_delta != typemax(UInt32)
            hint_bytes = UInt64(bytes_delta)
            state.progress_bytes_delta = max(
                state.config.progress_bytes_delta,
                min(state.progress_bytes_delta, hint_bytes),
            )
        end
    end
    return nothing
end

function make_control_assembler(state::ProducerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_CONSUMER_HELLO
            ConsumerHello.wrap!(st.hello_decoder, buffer, 0; header = header)
            handle_consumer_hello!(st, st.hello_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

@inline function poll_control!(state::ProducerState, assembler::Aeron.FragmentAssembler, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(state.sub_control, assembler, fragment_limit)
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
