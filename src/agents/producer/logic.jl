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
function init_producer(config::ProducerConfig; client::Aeron.Client)
    ispow2(config.nslots) || throw(ArgumentError("header nslots must be power of two"))
    for pool in config.payload_pools
        pool.nslots == config.nslots || throw(ArgumentError("payload nslots must match header nslots"))
    end

    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

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

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)
    pub_metadata = Aeron.add_publication(client, config.aeron_uri, config.metadata_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(config.announce_interval_ns), PolledTimer(config.qos_interval_ns)),
        (ProducerAnnounceHandler(), ProducerQosHandler()),
    )

    control = ControlPlaneRuntime(client, pub_control, sub_control)
    runtime = ProducerRuntime(
        control,
        pub_descriptor,
        pub_qos,
        pub_metadata,
        sub_qos,
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
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
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
        true,
        false,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        true,
        nothing,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
    )

    emit_announce!(state)

    return state
end

"""
Build a ProducerConfig from a driver attach response.
"""
function producer_config_from_attach(config::ProducerConfig, attach::AttachResponseInfo)
    pools = PayloadPoolConfig[]
    for pool in attach.pools
        push!(
            pools,
            PayloadPoolConfig(pool.pool_id, pool.region_uri, pool.stride_bytes, pool.pool_nslots),
        )
    end
    return ProducerConfig(
        config.aeron_dir,
        config.aeron_uri,
        config.descriptor_stream_id,
        config.control_stream_id,
        config.qos_stream_id,
        config.metadata_stream_id,
        attach.stream_id,
        config.producer_id,
        attach.layout_version,
        attach.header_nslots,
        config.shm_base_dir,
        config.shm_namespace,
        config.producer_instance_id,
        attach.header_region_uri,
        pools,
        attach.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
    )
end

"""
Map driver-provisioned SHM regions for a producer config.
"""
function map_producer_from_attach(config::ProducerConfig, attach::AttachResponseInfo)
    attach.code == DriverResponseCode.OK || return nothing
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || return nothing

    header_size = SUPERBLOCK_SIZE + Int(config.nslots) * HEADER_SLOT_BYTES
    header_mmap = mmap_shm_existing(config.header_uri, header_size; write = true)

    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return nothing
    end
    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = config.layout_version,
        expected_epoch = attach.epoch,
        expected_stream_id = config.stream_id,
        expected_nslots = config.nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return nothing

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    for pool in config.payload_pools
        pool_size = SUPERBLOCK_SIZE + Int(pool.nslots) * Int(pool.stride_bytes)
        pmmap = mmap_shm_existing(pool.uri, pool_size; write = true)
        wrap_superblock!(sb_dec, pmmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return nothing
        end
        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = config.layout_version,
            expected_epoch = attach.epoch,
            expected_stream_id = config.stream_id,
            expected_nslots = pool.nslots,
            expected_slot_bytes = pool.stride_bytes,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool.pool_id,
        )
        pool_ok || return nothing
        payload_mmaps[pool.pool_id] = pmmap
    end

    return ProducerMappings(header_mmap, payload_mmaps)
end

"""
Initialize a producer using driver-provisioned SHM regions.
"""
function init_producer_from_attach(
    config::ProducerConfig,
    attach::AttachResponseInfo;
    driver_client::Union{DriverClientState, Nothing} = nothing,
    client::Aeron.Client,
)
    attach.code == DriverResponseCode.OK || throw(ArgumentError("attach failed"))
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || throw(ArgumentError("header_slot_bytes mismatch"))

    driver_config = producer_config_from_attach(config, attach)
    ispow2(driver_config.nslots) || throw(ArgumentError("header nslots must be power of two"))
    for pool in driver_config.payload_pools
        pool.nslots == driver_config.nslots || throw(ArgumentError("payload nslots must match header nslots"))
    end

    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    mappings = map_producer_from_attach(driver_config, attach)
    mappings === nothing && throw(ArgumentError("payload superblock validation failed"))

    pub_descriptor = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.descriptor_stream_id)
    pub_control = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.control_stream_id)
    pub_qos = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.qos_stream_id)
    pub_metadata = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.metadata_stream_id)
    sub_control = Aeron.add_subscription(client, driver_config.aeron_uri, driver_config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, driver_config.aeron_uri, driver_config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(driver_config.announce_interval_ns), PolledTimer(driver_config.qos_interval_ns)),
        (ProducerAnnounceHandler(), ProducerQosHandler()),
    )

    control = ControlPlaneRuntime(client, pub_control, sub_control)
    runtime = ProducerRuntime(
        control,
        pub_descriptor,
        pub_qos,
        pub_metadata,
        sub_qos,
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        Vector{UInt8}(undef, ANNOUNCE_BUF_BYTES),
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        ShmRegionSuperblock.Encoder(Vector{UInt8}),
        TensorSlotHeader256.Encoder(Vector{UInt8}),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    metrics = ProducerMetrics(UInt64(0), UInt64(0), UInt64(0), UInt64(0))
    state = ProducerState(
        driver_config,
        clock,
        runtime,
        mappings,
        metrics,
        attach.epoch,
        UInt64(0),
        true,
        false,
        driver_config.progress_interval_ns,
        driver_config.progress_bytes_delta,
        false,
        driver_client,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
    )
    return state
end

"""
Remap producer SHM and epoch from a driver attach response.
"""
function remap_producer_from_attach!(state::ProducerState, attach::AttachResponseInfo)
    attach.code == DriverResponseCode.OK || return false
    driver_config = producer_config_from_attach(state.config, attach)
    ispow2(driver_config.nslots) || return false
    for pool in driver_config.payload_pools
        pool.nslots == driver_config.nslots || return false
    end

    mappings = map_producer_from_attach(driver_config, attach)
    mappings === nothing && return false

    state.config = driver_config
    state.mappings = mappings
    state.epoch = attach.epoch
    state.seq = UInt64(0)
    state.emit_announce = false
    state.driver_active = true
    return true
end

@inline function producer_driver_active(state::ProducerState)
    dc = state.driver_client
    dc === nothing && return true
    return state.driver_active && dc.lease_id != 0 && !dc.revoked && !dc.shutdown
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ProducerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0

    if dc.revoked || dc.shutdown
        state.driver_active = false
    end

    if !state.driver_active && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.layout_version,
            max_dims = state.config.max_dims,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        if cid != 0
            state.pending_attach_id = cid
            work_count += 1
        end
    end

    if state.pending_attach_id != 0
        attach = dc.poller.last_attach
        if attach !== nothing && attach.correlation_id == state.pending_attach_id
            state.pending_attach_id = Int64(0)
            if attach.code == DriverResponseCode.OK
                apply_attach!(dc, attach)
                state.driver_active = remap_producer_from_attach!(state, attach)
                state.driver_active || (dc.lease_id = UInt64(0))
            else
                state.driver_active = false
            end
        end
    end
    return work_count
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
    producer_driver_active(state) || return false

    seq = state.seq
    frame_id = seq
    header_index = UInt32(seq & (UInt64(state.config.nslots) - 1))

    values_len = length(payload_data)
    pool_idx = select_pool(state.config.payload_pools, values_len)
    pool_idx == 0 && return false
    pool = state.config.payload_pools[pool_idx]

    payload_slot = header_index
    payload_mmap = state.mappings.payload_mmaps[pool.pool_id]
    payload_offset = SUPERBLOCK_SIZE + Int(payload_slot) * Int(pool.stride_bytes)

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, frame_id)

    copyto!(payload_mmap, payload_offset + 1, payload_data, 1, values_len)

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
    shared_sent = let st = state,
        seq = seq,
        header_index = header_index,
        meta_version = meta_version,
        now_ns = now_ns
        try_claim_sbe!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            header = MessageHeader.Encoder(buf, 0)
            MessageHeader.blockLength!(header, FrameDescriptor.sbe_block_length(FrameDescriptor.Decoder))
            MessageHeader.templateId!(header, FrameDescriptor.sbe_template_id(FrameDescriptor.Decoder))
            MessageHeader.schemaId!(header, FrameDescriptor.sbe_schema_id(FrameDescriptor.Decoder))
            MessageHeader.version!(header, FrameDescriptor.sbe_schema_version(FrameDescriptor.Decoder))
            FrameDescriptor.wrap!(st.runtime.descriptor_encoder, buf, MESSAGE_HEADER_LEN)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
        end
    end
    per_consumer_sent = publish_descriptor_to_consumers!(state, seq, header_index, meta_version, now_ns)
    (shared_sent || per_consumer_sent) || return false

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
    producer_driver_active(state) || error("driver lease inactive")
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
    producer_driver_active(state) || return false
    pool = payload_pool_config(state, reservation.pool_id)
    pool === nothing && return false
    values_len <= reservation.stride_bytes || return false

    expected_index = UInt32(reservation.seq & (UInt64(state.config.nslots) - 1))
    reservation.header_index == expected_index || return false

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
    shared_sent = let st = state,
        seq = reservation.seq,
        header_index = reservation.header_index,
        meta_version = meta_version,
        now_ns = now_ns
        try_claim_sbe!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
        end
    end
    per_consumer_sent =
        publish_descriptor_to_consumers!(state, reservation.seq, reservation.header_index, meta_version, now_ns)
    (shared_sent || per_consumer_sent) || return false

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
    producer_driver_active(state) || return false

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
    shared_sent = let st = state,
        seq = seq,
        header_index = header_index,
        meta_version = meta_version,
        now_ns = now_ns
        try_claim_sbe!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
        end
    end
    per_consumer_sent = publish_descriptor_to_consumers!(state, seq, header_index, meta_version, now_ns)
    (shared_sent || per_consumer_sent) || return false

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
    sent = let st = state,
        frame_id = frame_id,
        header_index = header_index,
        bytes_filled = bytes_filled
        try_claim_sbe!(st.runtime.control.pub_control, st.runtime.progress_claim, FRAME_PROGRESS_LEN) do buf
            FrameProgress.wrap_and_apply_header!(st.runtime.progress_encoder, buf, 0)
            FrameProgress.streamId!(st.runtime.progress_encoder, st.config.stream_id)
            FrameProgress.epoch!(st.runtime.progress_encoder, st.epoch)
            FrameProgress.frameId!(st.runtime.progress_encoder, frame_id)
            FrameProgress.headerIndex!(st.runtime.progress_encoder, header_index)
            FrameProgress.payloadBytesFilled!(st.runtime.progress_encoder, bytes_filled)
            FrameProgress.state!(st.runtime.progress_encoder, FrameProgressState.COMPLETE)
        end
    end
    sent || return false
    state.metrics.last_progress_ns = UInt64(Clocks.time_nanos(state.clock))
    state.metrics.last_progress_bytes = bytes_filled
    publish_progress_to_consumers!(state, frame_id, header_index, bytes_filled)
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

    sent = let st = state,
        payload_count = payload_count
        try_claim_sbe!(st.runtime.control.pub_control, st.runtime.progress_claim, msg_len) do buf
            ShmPoolAnnounce.wrap_and_apply_header!(st.runtime.announce_encoder, buf, 0)
            ShmPoolAnnounce.streamId!(st.runtime.announce_encoder, st.config.stream_id)
            ShmPoolAnnounce.producerId!(st.runtime.announce_encoder, st.config.producer_id)
            ShmPoolAnnounce.epoch!(st.runtime.announce_encoder, st.epoch)
            ShmPoolAnnounce.layoutVersion!(st.runtime.announce_encoder, st.config.layout_version)
            ShmPoolAnnounce.headerNslots!(st.runtime.announce_encoder, st.config.nslots)
            ShmPoolAnnounce.headerSlotBytes!(st.runtime.announce_encoder, UInt16(HEADER_SLOT_BYTES))
            ShmPoolAnnounce.maxDims!(st.runtime.announce_encoder, st.config.max_dims)

            pools_group = ShmPoolAnnounce.payloadPools!(st.runtime.announce_encoder, payload_count)
            for pool in st.config.payload_pools
                entry = ShmPoolAnnounce.PayloadPools.next!(pools_group)
                ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
                ShmPoolAnnounce.PayloadPools.poolNslots!(entry, pool.nslots)
                ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
                ShmPoolAnnounce.PayloadPools.regionUri!(entry, pool.uri)
            end
            ShmPoolAnnounce.headerRegionUri!(st.runtime.announce_encoder, st.config.header_uri)
        end
    end
    sent || return false
    state.metrics.announce_count += 1
    return true
end

"""
Emit a QosProducer message for this producer.
"""
function emit_qos!(state::ProducerState)
    sent = let st = state
        try_claim_sbe!(st.runtime.pub_qos, st.runtime.qos_claim, QOS_PRODUCER_LEN) do buf
            QosProducer.wrap_and_apply_header!(st.runtime.qos_encoder, buf, 0)
            QosProducer.streamId!(st.runtime.qos_encoder, st.config.stream_id)
            QosProducer.producerId!(st.runtime.qos_encoder, st.config.producer_id)
            QosProducer.epoch!(st.runtime.qos_encoder, st.epoch)
            QosProducer.currentSeq!(st.runtime.qos_encoder, st.seq)
        end
    end
    sent || return false
    state.metrics.qos_count += 1
    return true
end

@inline function consumer_stream_timeout_ns(state::ProducerState)
    base = max(state.config.announce_interval_ns, state.config.qos_interval_ns)
    return base * 5
end

@inline function consumer_stream_last_seen_ns(entry::ProducerConsumerStream)
    return max(entry.last_hello_ns, entry.last_qos_ns)
end

function clear_consumer_stream!(entry::ProducerConsumerStream)
    entry.descriptor_pub === nothing || close(entry.descriptor_pub)
    entry.control_pub === nothing || close(entry.control_pub)
    entry.descriptor_pub = nothing
    entry.control_pub = nothing
    entry.descriptor_channel = ""
    entry.control_channel = ""
    entry.descriptor_stream_id = UInt32(0)
    entry.control_stream_id = UInt32(0)
    entry.max_rate_hz = UInt16(0)
    entry.next_descriptor_ns = UInt64(0)
    entry.last_hello_ns = UInt64(0)
    entry.last_qos_ns = UInt64(0)
    return nothing
end

function cleanup_consumer_streams!(state::ProducerState, now_ns::UInt64)
    timeout_ns = consumer_stream_timeout_ns(state)
    closed = 0
    for entry in values(state.consumer_streams)
        last_seen = consumer_stream_last_seen_ns(entry)
        last_seen == 0 && continue
        if now_ns - last_seen > timeout_ns
            clear_consumer_stream!(entry)
            closed += 1
        end
    end
    return closed
end

function emit_consumer_config!(
    state::ProducerState,
    consumer_id::UInt32;
    use_shm::Bool = state.config.nslots > 0,
    mode::Mode.SbeEnum = Mode.STREAM,
    decimation::UInt16 = UInt16(1),
    payload_fallback_uri::AbstractString = "",
    descriptor_channel::AbstractString = "",
    descriptor_stream_id::UInt32 = UInt32(0),
    control_channel::AbstractString = "",
    control_stream_id::UInt32 = UInt32(0),
)
    msg_len = MESSAGE_HEADER_LEN +
        Int(ConsumerConfigMsg.sbe_block_length(ConsumerConfigMsg.Decoder)) +
        Int(ConsumerConfigMsg.payloadFallbackUri_header_length) +
        Int(ConsumerConfigMsg.descriptorChannel_header_length) +
        Int(ConsumerConfigMsg.controlChannel_header_length) +
        sizeof(payload_fallback_uri) +
        sizeof(descriptor_channel) +
        sizeof(control_channel)

    sent = let st = state,
        consumer_id = consumer_id,
        use_shm = use_shm,
        mode = mode,
        decimation = decimation,
        payload_fallback_uri = payload_fallback_uri,
        descriptor_channel = descriptor_channel,
        descriptor_stream_id = descriptor_stream_id,
        control_channel = control_channel,
        control_stream_id = control_stream_id
        try_claim_sbe!(st.runtime.control.pub_control, st.runtime.config_claim, msg_len) do buf
            ConsumerConfigMsg.wrap_and_apply_header!(st.runtime.config_encoder, buf, 0)
            ConsumerConfigMsg.streamId!(st.runtime.config_encoder, st.config.stream_id)
            ConsumerConfigMsg.consumerId!(st.runtime.config_encoder, consumer_id)
            ConsumerConfigMsg.useShm!(
                st.runtime.config_encoder,
                use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerConfigMsg.mode!(st.runtime.config_encoder, mode)
            ConsumerConfigMsg.decimation!(st.runtime.config_encoder, decimation)
            ConsumerConfigMsg.descriptorStreamId!(
                st.runtime.config_encoder,
                descriptor_stream_id != 0 ?
                descriptor_stream_id :
                ConsumerConfigMsg.descriptorStreamId_null_value(ConsumerConfigMsg.Encoder),
            )
            ConsumerConfigMsg.controlStreamId!(
                st.runtime.config_encoder,
                control_stream_id != 0 ?
                control_stream_id :
                ConsumerConfigMsg.controlStreamId_null_value(ConsumerConfigMsg.Encoder),
            )
            ConsumerConfigMsg.payloadFallbackUri!(st.runtime.config_encoder, payload_fallback_uri)
            if isempty(descriptor_channel)
                ConsumerConfigMsg.descriptorChannel_length!(st.runtime.config_encoder, 0)
            else
                ConsumerConfigMsg.descriptorChannel!(st.runtime.config_encoder, descriptor_channel)
            end
            if isempty(control_channel)
                ConsumerConfigMsg.controlChannel_length!(st.runtime.config_encoder, 0)
            else
                ConsumerConfigMsg.controlChannel!(st.runtime.config_encoder, control_channel)
            end
        end
    end
    return sent
end

function update_consumer_streams!(state::ProducerState, msg::ConsumerHello.Decoder)
    consumer_id = ConsumerHello.consumerId(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    descriptor_stream_id = ConsumerHello.descriptorStreamId(msg)
    control_stream_id = ConsumerHello.controlStreamId(msg)
    descriptor_null = ConsumerHello.descriptorStreamId_null_value(ConsumerHello.Decoder)
    control_null = ConsumerHello.controlStreamId_null_value(ConsumerHello.Decoder)
    descriptor_channel = String(ConsumerHello.descriptorChannel(msg))
    control_channel = String(ConsumerHello.controlChannel(msg))
    descriptor_stream_id_provided =
        descriptor_stream_id != 0 && descriptor_stream_id != descriptor_null
    control_stream_id_provided =
        control_stream_id != 0 && control_stream_id != control_null
    descriptor_channel_provided = !isempty(descriptor_channel)
    control_channel_provided = !isempty(control_channel)
    descriptor_requested = descriptor_channel_provided && descriptor_stream_id_provided
    control_requested = control_channel_provided && control_stream_id_provided
    invalid_descriptor_request = descriptor_channel_provided != descriptor_stream_id_provided
    invalid_control_request = control_channel_provided != control_stream_id_provided

    if !descriptor_requested && !control_requested && !invalid_descriptor_request && !invalid_control_request
        return false
    end

    entry = get(state.consumer_streams, consumer_id, nothing)
    if entry === nothing
        entry = ProducerConsumerStream(
            nothing,
            nothing,
            "",
            "",
            UInt32(0),
            UInt32(0),
            UInt16(0),
            UInt64(0),
            now_ns,
            UInt64(0),
        )
        state.consumer_streams[consumer_id] = entry
    end

    entry.last_hello_ns = now_ns
    entry.max_rate_hz = ConsumerHello.maxRateHz(msg)

    changed = false
    if descriptor_requested
        if entry.descriptor_pub === nothing ||
            entry.descriptor_stream_id != descriptor_stream_id ||
            entry.descriptor_channel != descriptor_channel
            entry.descriptor_pub === nothing || close(entry.descriptor_pub)
            try
                entry.descriptor_pub = Aeron.add_publication(
                    state.runtime.control.client,
                    descriptor_channel,
                    Int32(descriptor_stream_id),
                )
                entry.descriptor_stream_id = descriptor_stream_id
                entry.descriptor_channel = descriptor_channel
                entry.next_descriptor_ns = now_ns
                changed = true
            catch
                entry.descriptor_pub = nothing
                entry.descriptor_stream_id = UInt32(0)
                entry.descriptor_channel = ""
                changed = true
            end
        end
    elseif entry.descriptor_pub !== nothing
        close(entry.descriptor_pub)
        entry.descriptor_pub = nothing
        entry.descriptor_channel = ""
        entry.descriptor_stream_id = UInt32(0)
        changed = true
    end

    if control_requested
        if entry.control_pub === nothing ||
            entry.control_stream_id != control_stream_id ||
            entry.control_channel != control_channel
            entry.control_pub === nothing || close(entry.control_pub)
            try
                entry.control_pub = Aeron.add_publication(
                    state.runtime.control.client,
                    control_channel,
                    Int32(control_stream_id),
                )
                entry.control_stream_id = control_stream_id
                entry.control_channel = control_channel
                changed = true
            catch
                entry.control_pub = nothing
                entry.control_stream_id = UInt32(0)
                entry.control_channel = ""
                changed = true
            end
        end
    elseif entry.control_pub !== nothing
        close(entry.control_pub)
        entry.control_pub = nothing
        entry.control_channel = ""
        entry.control_stream_id = UInt32(0)
        changed = true
    end

    if invalid_descriptor_request || invalid_control_request
        emit_consumer_config!(
            state,
            consumer_id;
            use_shm = true,
            mode = ConsumerHello.mode(msg),
            decimation = UInt16(1),
            payload_fallback_uri = "",
            descriptor_channel = "",
            descriptor_stream_id = UInt32(0),
            control_channel = "",
            control_stream_id = UInt32(0),
        )
        return false
    end

    if changed
        emit_consumer_config!(
            state,
            consumer_id;
            use_shm = true,
            mode = ConsumerHello.mode(msg),
            decimation = UInt16(1),
            payload_fallback_uri = "",
            descriptor_channel = entry.descriptor_channel,
            descriptor_stream_id = entry.descriptor_stream_id,
            control_channel = entry.control_channel,
            control_stream_id = entry.control_stream_id,
        )
    end
    return changed
end

function handle_qos_consumer!(state::ProducerState, msg::QosConsumer.Decoder)
    QosConsumer.streamId(msg) == state.config.stream_id || return false
    consumer_id = QosConsumer.consumerId(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    entry = get(state.consumer_streams, consumer_id, nothing)
    if entry === nothing
        entry = ProducerConsumerStream(
            nothing,
            nothing,
            "",
            "",
            UInt32(0),
            UInt32(0),
            UInt16(0),
            UInt64(0),
            UInt64(0),
            now_ns,
        )
        state.consumer_streams[consumer_id] = entry
    end
    entry.last_qos_ns = now_ns
    return true
end

function publish_descriptor_to_consumers!(
    state::ProducerState,
    seq::UInt64,
    header_index::UInt32,
    meta_version::UInt32,
    now_ns::UInt64,
)
    any_sent = false
    for entry in values(state.consumer_streams)
        pub = entry.descriptor_pub
        pub === nothing && continue
        if entry.max_rate_hz != 0 && now_ns < entry.next_descriptor_ns
            continue
        end
        sent = let st = state,
            seq = seq,
            header_index = header_index,
            meta_version = meta_version,
            now_ns = now_ns,
            pub = pub
            try_claim_sbe!(pub, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
                FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
                encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
            end
        end
        if sent
            any_sent = true
        end
        if sent && entry.max_rate_hz != 0
            period_ns = UInt64(1_000_000_000) ÷ UInt64(entry.max_rate_hz)
            entry.next_descriptor_ns = now_ns + period_ns
        end
    end
    return any_sent
end

function publish_progress_to_consumers!(
    state::ProducerState,
    frame_id::UInt64,
    header_index::UInt32,
    bytes_filled::UInt64,
)
    for entry in values(state.consumer_streams)
        pub = entry.control_pub
        pub === nothing && continue
        let st = state,
            frame_id = frame_id,
            header_index = header_index,
            bytes_filled = bytes_filled,
            pub = pub
            try_claim_sbe!(pub, st.runtime.progress_claim, FRAME_PROGRESS_LEN) do buf
                FrameProgress.wrap_and_apply_header!(st.runtime.progress_encoder, buf, 0)
                FrameProgress.streamId!(st.runtime.progress_encoder, st.config.stream_id)
                FrameProgress.epoch!(st.runtime.progress_encoder, st.epoch)
                FrameProgress.frameId!(st.runtime.progress_encoder, frame_id)
                FrameProgress.headerIndex!(st.runtime.progress_encoder, header_index)
                FrameProgress.payloadBytesFilled!(st.runtime.progress_encoder, bytes_filled)
                FrameProgress.state!(st.runtime.progress_encoder, FrameProgressState.COMPLETE)
            end
        end
    end
    return nothing
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
    update_consumer_streams!(state, msg)
    return nothing
end
