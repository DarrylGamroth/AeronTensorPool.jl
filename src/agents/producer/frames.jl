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

Base.isempty(q::InflightQueue) = q.count == 0
Base.length(q::InflightQueue) = q.count
Base.isfull(q::InflightQueue) = q.count == length(q.items)

Base.first(q::InflightQueue) = isempty(q) ? throw(ArgumentError("inflight queue empty")) : q.items[q.head]

function Base.push!(q::InflightQueue, reservation::SlotReservation)
    isfull(q) && throw(ArgumentError("inflight queue full"))
    q.items[q.tail] = reservation
    q.tail = q.tail == length(q.items) ? 1 : q.tail + 1
    q.count += 1
    return q
end

function Base.popfirst!(q::InflightQueue)
    isempty(q) && throw(ArgumentError("inflight queue empty"))
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
