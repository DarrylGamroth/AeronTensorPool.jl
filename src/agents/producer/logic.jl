"""
Return true if a progress update should be emitted.
"""
@inline function should_emit_progress!(state::ProducerState, bytes_filled::UInt64, final::Bool)
    if final
        return true
    end
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    if now_ns - state.metrics.last_progress_ns < state.progress_interval_ns &&
       bytes_filled - state.metrics.last_progress_bytes < state.progress_bytes_delta
        return false
    end
    return true
end

"""
Initialize a producer: map SHM regions, write superblocks, and create Aeron resources.
"""
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
    set_aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)
    pub_metadata = Aeron.add_publication(client, config.aeron_uri, config.metadata_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)

    timer_set = TimerSet(
        (PolledTimer(config.announce_interval_ns), PolledTimer(config.qos_interval_ns)),
        (ProducerAnnounceHandler(), ProducerQosHandler()),
    )

    runtime = ProducerRuntime(
        ctx,
        client,
        pub_descriptor,
        pub_control,
        pub_qos,
        pub_metadata,
        sub_control,
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        Vector{UInt8}(undef, ANNOUNCE_BUF_BYTES),
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        sb_encoder,
        TensorSlotHeader256.Encoder(Vector{UInt8}),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    mappings = ProducerMappings(header_mmap, payload_mmaps)
    metrics = ProducerMetrics(UInt64(0), UInt64(0), UInt64(0), UInt64(0))
    state = ProducerState(
        config,
        clock,
        runtime,
        mappings,
        metrics,
        UInt64(1),
        UInt64(0),
        false,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        timer_set,
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

"""
Write a payload into SHM and publish a FrameDescriptor.
"""
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
    payload_mmap = state.mappings.payload_mmaps[pool.pool_id]
    payload_offset = SUPERBLOCK_SIZE + Int(payload_slot) * Int(pool.stride_bytes)

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, frame_id)

    copyto!(view(payload_mmap, payload_offset + 1:payload_offset + values_len), payload_data)

    wrap_tensor_header!(state.runtime.header_encoder, state.mappings.header_mmap, header_offset)
    write_tensor_slot_header!(
        state.runtime.header_encoder,
        frame_id,
        UInt64(Clocks.time_nanos(state.clock)),
        meta_version,
        UInt32(values_len),
        payload_slot,
        UInt32(0),
        pool.pool_id,
        dtype,
        MajorOrder.ROW,
        UInt8(length(shape)),
        shape,
        strides,
    )

    seqlock_commit_write!(commit_ptr, frame_id)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    sent = try_claim_sbe!(state.runtime.pub_descriptor, state.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.runtime.descriptor_encoder, buf, 0)
        encode_frame_descriptor!(state.runtime.descriptor_encoder, state, seq, header_index, meta_version, now_ns)
    end
    sent || return false

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
        emit_progress_complete!(state, frame_id, header_index, UInt64(values_len))
    end

    state.seq += 1
    return true
end

"""
Compute the next header index for the current seq.
"""
@inline function next_header_index(state::ProducerState)
    return UInt32(state.seq & (UInt64(state.config.nslots) - 1))
end

"""
Lookup payload pool configuration by pool_id.
"""
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
    payload_mmap = state.mappings.payload_mmaps[pool.pool_id]
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
    payload_mmap = state.mappings.payload_mmaps[pool.pool_id]
    view_len = len < 0 ? Int(pool.stride_bytes) : Int(len)
    return payload_slot_view(payload_mmap, pool.stride_bytes, slot, view_len)
end

"""
Reservation handle for a payload slot that will be filled externally.
"""
struct SlotReservation
    seq::UInt64
    header_index::UInt32
    pool_id::UInt16
    payload_slot::UInt32
    ptr::Ptr{UInt8}
    stride_bytes::Int
end

"""
Simple ring buffer for SlotReservation tracking.
"""
mutable struct InflightQueue
    items::Vector{SlotReservation}
    head::Int
    tail::Int
    count::Int
end

"""
Create an InflightQueue with the given capacity.
"""
function InflightQueue(capacity::Integer)
    capacity > 0 || throw(ArgumentError("capacity must be > 0"))
    return InflightQueue(Vector{SlotReservation}(undef, capacity), 1, 1, 0)
end

"""
Return true if the inflight queue is empty.
"""
@inline function inflight_empty(q::InflightQueue)
    return q.count == 0
end

"""
Return true if the inflight queue is full.
"""
@inline function inflight_full(q::InflightQueue)
    return q.count == length(q.items)
end

"""
Push a reservation into the inflight queue.
"""
function inflight_push!(q::InflightQueue, reservation::SlotReservation)
    inflight_full(q) && return false
    q.items[q.tail] = reservation
    q.tail = q.tail == length(q.items) ? 1 : q.tail + 1
    q.count += 1
    return true
end

"""
Peek at the next reservation without removing it.
"""
function inflight_peek(q::InflightQueue)
    inflight_empty(q) && return nothing
    return q.items[q.head]
end

"""
Pop the next reservation from the inflight queue.
"""
function inflight_pop!(q::InflightQueue)
    inflight_empty(q) && return nothing
    item = q.items[q.head]
    q.head = q.head == length(q.items) ? 1 : q.head + 1
    q.count -= 1
    return item
end

"""
Reserve a payload slot and return a SlotReservation for external filling.
"""
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

"""
Publish a SlotReservation after the payload has been filled externally.
"""
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
    commit_ptr = header_commit_ptr_from_offset(state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, frame_id)

    wrap_tensor_header!(state.runtime.header_encoder, state.mappings.header_mmap, header_offset)
    write_tensor_slot_header!(
        state.runtime.header_encoder,
        frame_id,
        UInt64(Clocks.time_nanos(state.clock)),
        meta_version,
        UInt32(values_len),
        reservation.payload_slot,
        UInt32(0),
        reservation.pool_id,
        dtype,
        MajorOrder.ROW,
        UInt8(length(shape)),
        shape,
        strides,
    )

    seqlock_commit_write!(commit_ptr, frame_id)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    sent = try_claim_sbe!(state.runtime.pub_descriptor, state.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.runtime.descriptor_encoder, buf, 0)
        encode_frame_descriptor!(
            state.runtime.descriptor_encoder,
            state,
            reservation.seq,
            reservation.header_index,
            meta_version,
            now_ns,
        )
    end
    sent || return false

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
        emit_progress_complete!(state, frame_id, reservation.header_index, UInt64(values_len))
    end

    return true
end

"""
Publish a descriptor for an already-filled payload slot.
"""
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
    commit_ptr = header_commit_ptr_from_offset(state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, frame_id)

    wrap_tensor_header!(state.runtime.header_encoder, state.mappings.header_mmap, header_offset)
    write_tensor_slot_header!(
        state.runtime.header_encoder,
        frame_id,
        UInt64(Clocks.time_nanos(state.clock)),
        meta_version,
        UInt32(values_len),
        payload_slot,
        UInt32(0),
        pool.pool_id,
        dtype,
        MajorOrder.ROW,
        UInt8(length(shape)),
        shape,
        strides,
    )

    seqlock_commit_write!(commit_ptr, frame_id)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    sent = try_claim_sbe!(state.runtime.pub_descriptor, state.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.runtime.descriptor_encoder, buf, 0)
        encode_frame_descriptor!(state.runtime.descriptor_encoder, state, seq, header_index, meta_version, now_ns)
    end
    sent || return false

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
        emit_progress_complete!(state, frame_id, header_index, UInt64(values_len))
    end

    state.seq += 1
    return true
end

"""
Emit a FrameProgress COMPLETE message.
"""
function emit_progress_complete!(
    state::ProducerState,
    frame_id::UInt64,
    header_index::UInt32,
    bytes_filled::UInt64,
)
    sent = try_claim_sbe!(state.runtime.pub_control, state.runtime.progress_claim, FRAME_PROGRESS_LEN) do buf
        FrameProgress.wrap_and_apply_header!(state.runtime.progress_encoder, buf, 0)
        FrameProgress.streamId!(state.runtime.progress_encoder, state.config.stream_id)
        FrameProgress.epoch!(state.runtime.progress_encoder, state.epoch)
        FrameProgress.frameId!(state.runtime.progress_encoder, frame_id)
        FrameProgress.headerIndex!(state.runtime.progress_encoder, header_index)
        FrameProgress.payloadBytesFilled!(state.runtime.progress_encoder, bytes_filled)
        FrameProgress.state!(state.runtime.progress_encoder, FrameProgressState.COMPLETE)
    end
    sent || return false
    state.metrics.last_progress_ns = UInt64(Clocks.time_nanos(state.clock))
    state.metrics.last_progress_bytes = bytes_filled
    return true
end

"""
Emit a ShmPoolAnnounce for this producer.
"""
function emit_announce!(state::ProducerState)
    payload_count = length(state.config.payload_pools)
    msg_len = MESSAGE_HEADER_LEN +
        Int(ShmPoolAnnounce.sbe_block_length(ShmPoolAnnounce.Decoder)) +
        4 +
        sum(
            10 + ShmPoolAnnounce.PayloadPools.regionUri_header_length + sizeof(pool.uri)
            for pool in state.config.payload_pools
        ) +
        ShmPoolAnnounce.headerRegionUri_header_length +
        sizeof(state.config.header_uri)

    sent = try_claim_sbe!(state.runtime.pub_control, state.runtime.progress_claim, msg_len) do buf
        ShmPoolAnnounce.wrap_and_apply_header!(state.runtime.announce_encoder, buf, 0)
        ShmPoolAnnounce.streamId!(state.runtime.announce_encoder, state.config.stream_id)
        ShmPoolAnnounce.producerId!(state.runtime.announce_encoder, state.config.producer_id)
        ShmPoolAnnounce.epoch!(state.runtime.announce_encoder, state.epoch)
        ShmPoolAnnounce.layoutVersion!(state.runtime.announce_encoder, state.config.layout_version)
        ShmPoolAnnounce.headerNslots!(state.runtime.announce_encoder, state.config.nslots)
        ShmPoolAnnounce.headerSlotBytes!(state.runtime.announce_encoder, UInt16(HEADER_SLOT_BYTES))
        ShmPoolAnnounce.maxDims!(state.runtime.announce_encoder, state.config.max_dims)

        pools_group = ShmPoolAnnounce.payloadPools!(state.runtime.announce_encoder, payload_count)
        for pool in state.config.payload_pools
            entry = ShmPoolAnnounce.PayloadPools.next!(pools_group)
            ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
            ShmPoolAnnounce.PayloadPools.poolNslots!(entry, pool.nslots)
            ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
            ShmPoolAnnounce.PayloadPools.regionUri!(entry, pool.uri)
        end
        ShmPoolAnnounce.headerRegionUri!(state.runtime.announce_encoder, state.config.header_uri)
    end
    sent || return false
    state.metrics.announce_count += 1
    return true
end

"""
Emit a QosProducer message for this producer.
"""
function emit_qos!(state::ProducerState)
    sent = try_claim_sbe!(state.runtime.pub_qos, state.runtime.qos_claim, QOS_PRODUCER_LEN) do buf
        QosProducer.wrap_and_apply_header!(state.runtime.qos_encoder, buf, 0)
        QosProducer.streamId!(state.runtime.qos_encoder, state.config.stream_id)
        QosProducer.producerId!(state.runtime.qos_encoder, state.config.producer_id)
        QosProducer.epoch!(state.runtime.qos_encoder, state.epoch)
        QosProducer.currentSeq!(state.runtime.qos_encoder, state.seq)
    end
    sent || return false
    state.metrics.qos_count += 1
    return true
end

"""
Update progress settings based on a ConsumerHello message.
"""
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
