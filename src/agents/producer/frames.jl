function encode_frame_descriptor!(
    enc::FrameDescriptor.Encoder,
    state::ProducerState,
    seq::UInt64,
    meta_version::UInt32,
    now_ns::UInt64,
    trace_id::UInt64,
)
    FrameDescriptor.streamId!(enc, state.config.stream_id)
    FrameDescriptor.epoch!(enc, state.epoch)
    FrameDescriptor.seq!(enc, seq)
    FrameDescriptor.timestampNs!(enc, now_ns)
    FrameDescriptor.metaVersion!(enc, meta_version)
    FrameDescriptor.traceId!(enc, trace_id)
    return nothing
end

"""
Offer a frame by copying payload bytes into SHM and publishing a descriptor.

Arguments:
- `state`: producer state and runtime resources.
- `payload_data`: source bytes to copy into the payload slot.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.
- `trace_id`: optional trace ID (0 means unset).

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function offer_frame!(
    state::ProducerState,
    payload_data::AbstractVector{UInt8},
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    ;
    trace_id::UInt64 = UInt64(0),
)
    return offer_frame!(
        state,
        payload_data,
        shape,
        strides,
        dtype,
        meta_version,
        NOOP_PRODUCER_CALLBACKS;
        trace_id = trace_id,
    )
end

"""
Offer a frame by copying payload bytes into SHM and publishing a descriptor.

Arguments:
- `state`: producer state and runtime resources.
- `payload_data`: source bytes to copy into the payload slot.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.
- `callbacks`: producer callbacks.
- `trace_id`: optional trace ID (0 means unset).

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function offer_frame!(
    state::ProducerState,
    payload_data::AbstractVector{UInt8},
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    callbacks::ProducerCallbacks,
    ;
    trace_id::UInt64 = UInt64(0),
)
    producer_driver_active(state) || return false

    seq = state.seq
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
    seqlock_begin_write!(commit_ptr, seq)

    copyto!(payload_mmap, payload_offset + 1, payload_data, 1, values_len)

    wrap_slot_header!(state.runtime.slot_encoder, state.mappings.header_mmap, header_offset)
    @inbounds write_slot_header!(
        state.runtime.slot_encoder,
        state.runtime.tensor_encoder,
        UInt64(Clocks.time_nanos(state.clock)),
        meta_version,
        UInt32(values_len),
        payload_slot,
        UInt32(0),
        pool.pool_id,
        dtype,
        MajorOrder.ROW,
        UInt8(length(shape)),
        ProgressUnit.NONE,
        UInt32(0),
        shape,
        strides,
    )

    seqlock_commit_write!(commit_ptr, seq)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    shared_sent = let st = state,
        seq = seq,
        header_index = header_index,
        meta_version = meta_version,
        now_ns = now_ns,
        trace_id = trace_id
        with_claimed_buffer!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            header = MessageHeader.Encoder(buf, 0)
            MessageHeader.blockLength!(header, FrameDescriptor.sbe_block_length(FrameDescriptor.Decoder))
            MessageHeader.templateId!(header, FrameDescriptor.sbe_template_id(FrameDescriptor.Decoder))
            MessageHeader.schemaId!(header, FrameDescriptor.sbe_schema_id(FrameDescriptor.Decoder))
            MessageHeader.version!(header, FrameDescriptor.sbe_schema_version(FrameDescriptor.Decoder))
            FrameDescriptor.wrap!(st.runtime.descriptor_encoder, buf, MESSAGE_HEADER_LEN)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, meta_version, now_ns, trace_id)
        end
    end
    per_consumer_sent = publish_descriptor_to_consumers!(state, seq, meta_version, now_ns, trace_id)
    (shared_sent || per_consumer_sent) || return false
    callbacks.on_frame_published!(state, seq, header_index)

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
        emit_progress_complete!(state, seq, UInt64(values_len))
    end

    state.seq += 1
    return true
end

"""
Compute the next header index for the current seq.

Arguments:
- `state`: producer state.

Returns:
- Next header index (UInt32).
"""
function next_header_index(state::ProducerState)
    return UInt32(state.seq & (UInt64(state.config.nslots) - 1))
end

"""
Lookup payload pool configuration by pool_id.

Arguments:
- `state`: producer state.
- `pool_id`: payload pool identifier.

Returns:
- `PayloadPoolConfig` if found, otherwise `nothing`.
"""
function payload_pool_config(state::ProducerState, pool_id::UInt16)
    for pool in state.config.payload_pools
        if pool.pool_id == pool_id
            return pool
        end
    end
    return nothing
end

"""
Return a pointer to a payload slot for a producer pool.

Arguments:
- `state`: producer state.
- `pool_id`: payload pool identifier.
- `slot`: 0-based payload slot index.

Returns:
- Tuple `(Ptr{UInt8}, Int)` pointing to the slot and stride size.
"""
function payload_slot_ptr(state::ProducerState, pool_id::UInt16, slot::UInt32)
    pool = payload_pool_config(state, pool_id)
    pool === nothing && error("Unknown pool_id: $pool_id")
    slot < pool.nslots || error("Slot out of range: $slot")
    payload_mmap = state.mappings.payload_mmaps[pool.pool_id]
    return Shm.payload_slot_ptr(payload_mmap, pool.stride_bytes, slot)
end

"""
Try to return a pointer to a payload slot for a producer pool.

Arguments:
- `state`: producer state.
- `pool_id`: payload pool identifier.
- `slot`: 0-based payload slot index.

Returns:
- Tuple `(Ptr{UInt8}, Int)` pointing to the slot and stride size, or `nothing` if invalid.
"""
function try_payload_slot_ptr(state::ProducerState, pool_id::UInt16, slot::UInt32)
    pool = payload_pool_config(state, pool_id)
    pool === nothing && return nothing
    slot < pool.nslots || return nothing
    payload_mmap = state.mappings.payload_mmaps[pool.pool_id]
    return Shm.payload_slot_ptr(payload_mmap, pool.stride_bytes, slot)
end

"""
Return a view into a producer payload slot.

Arguments:
- `state`: producer state.
- `pool_id`: payload pool identifier.
- `slot`: 0-based payload slot index.
- `len`: view length in bytes (default: full stride).

Returns:
- `SubArray` view into the payload buffer.
"""
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
    return Shm.payload_slot_view(payload_mmap, pool.stride_bytes, slot, view_len)
end

"""
Try to return a view into a producer payload slot.

Arguments:
- `state`: producer state.
- `pool_id`: payload pool identifier.
- `slot`: 0-based payload slot index.
- `len`: view length in bytes (default: full stride).

Returns:
- `SubArray` view into the payload buffer, or `nothing` if the slot is invalid or the length exceeds stride.
"""
function try_payload_slot_view(
    state::ProducerState,
    pool_id::UInt16,
    slot::UInt32;
    len::Integer = -1,
)
    pool = payload_pool_config(state, pool_id)
    pool === nothing && return nothing
    slot < pool.nslots || return nothing
    payload_mmap = state.mappings.payload_mmaps[pool.pool_id]
    view_len = len < 0 ? Int(pool.stride_bytes) : Int(len)
    return Shm.try_payload_slot_view(payload_mmap, pool.stride_bytes, slot, view_len)
end

"""
Try to claim a payload slot for external filling.

Arguments:
- `state`: producer state and runtime resources.
- `pool_id`: payload pool to claim from.

Returns:
- `SlotClaim` containing slot identifiers, payload pointer, and stride size, or `nothing` if the claim fails.

Notes:
- Marks the slot as WRITING via seqlock before returning the pointer.
"""
function try_claim_slot!(state::ProducerState, pool_id::UInt16)
    producer_driver_active(state) || return nothing
    pool = payload_pool_config(state, pool_id)
    pool === nothing && return nothing

    seq = state.seq
    header_index = next_header_index(state)
    payload_slot = header_index
    payload_slot < pool.nslots || return nothing

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, seq)

    ptr_stride = try_payload_slot_ptr(state, pool_id, payload_slot)
    ptr_stride === nothing && return nothing
    ptr, stride_bytes = ptr_stride
    state.seq += 1

    return SlotClaim(seq, ptr, stride_bytes, header_index, payload_slot, pool_id)
end

"""
Try to claim a payload slot by selecting the smallest pool that fits values_len.

Arguments:
- `state`: producer state and runtime resources.
- `values_len`: required payload length in bytes.

Returns:
- `SlotClaim` on success, or `nothing` if no pool fits or the claim fails.
"""
function try_claim_slot_by_size!(state::ProducerState, values_len::Integer)
    producer_driver_active(state) || return nothing
    pool_idx = select_pool(state.config.payload_pools, values_len)
    pool_idx == 0 && return nothing
    pool_id = state.config.payload_pools[pool_idx].pool_id
    return try_claim_slot!(state, pool_id)
end

"""
Try to claim a payload slot, fill it, and commit the claim.

Arguments:
- `fill_fn`: callback invoked with `SlotClaim`; must write payload bytes before return.
- `state`: producer state and runtime resources.
- `pool_id`: payload pool to claim from.
- `values_len`: number of payload bytes filled.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.
- `trace_id`: optional trace ID (0 means unset).

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function with_claimed_slot!(
    fill_fn,
    state::ProducerState,
    pool_id::UInt16,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    trace_id::UInt64,
)
    claim = try_claim_slot!(state, pool_id)
    claim === nothing && return false
    fill_fn(claim)
    return commit_slot!(state, claim, values_len, shape, strides, dtype, meta_version, trace_id)
end

"""
Try to claim a payload slot, fill it, and commit the claim.

Arguments:
- `fill_fn`: callback invoked with `SlotClaim`; must write payload bytes before return.
- `state`: producer state and runtime resources.
- `pool_id`: payload pool to claim from.
- `values_len`: number of payload bytes filled.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function with_claimed_slot!(
    fill_fn,
    state::ProducerState,
    pool_id::UInt16,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return with_claimed_slot!(fill_fn, state, pool_id, values_len, shape, strides, dtype, meta_version, UInt64(0))
end

"""
Try to claim a payload slot, fill it, and commit the claim (keyword wrapper).

Arguments:
- `fill_fn`: callback invoked with `SlotClaim`; must write payload bytes before return.
- `state`: producer state and runtime resources.
- `pool_id`: payload pool to claim from.
- `values_len`: number of payload bytes filled.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function with_claimed_slot!(
    fill_fn,
    state::ProducerState,
    pool_id::UInt16;
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    trace_id::UInt64 = UInt64(0),
)
    return with_claimed_slot!(fill_fn, state, pool_id, values_len, shape, strides, dtype, meta_version, trace_id)
end

"""
Commit a SlotClaim after the payload has been filled externally.

Arguments:
- `state`: producer state and runtime resources.
- `claim`: slot claim returned from `try_claim_slot!`.
- `values_len`: number of payload bytes filled.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.
- `trace_id`: optional trace ID (0 means unset).

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function commit_slot!(
    state::ProducerState,
    claim::SlotClaim,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    trace_id::UInt64,
)
    producer_driver_active(state) || return false
    pool = payload_pool_config(state, claim.pool_id)
    pool === nothing && return false
    values_len <= claim.stride_bytes || return false

    expected_index = UInt32(claim.seq & (UInt64(state.config.nslots) - 1))
    claim.header_index == expected_index || return false

    seq = claim.seq

    header_offset = header_slot_offset(claim.header_index)
    commit_ptr = header_commit_ptr_from_offset(state.mappings.header_mmap, header_offset)

    wrap_slot_header!(state.runtime.slot_encoder, state.mappings.header_mmap, header_offset)
    @inbounds write_slot_header!(
        state.runtime.slot_encoder,
        state.runtime.tensor_encoder,
        UInt64(Clocks.time_nanos(state.clock)),
        meta_version,
        UInt32(values_len),
        claim.payload_slot,
        UInt32(0),
        claim.pool_id,
        dtype,
        MajorOrder.ROW,
        UInt8(length(shape)),
        ProgressUnit.NONE,
        UInt32(0),
        shape,
        strides,
    )

    seqlock_commit_write!(commit_ptr, seq)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    shared_sent = let st = state,
        seq = claim.seq,
        header_index = claim.header_index,
        meta_version = meta_version,
        now_ns = now_ns,
        trace_id = trace_id
        with_claimed_buffer!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
            encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, meta_version, now_ns, trace_id)
        end
    end
    per_consumer_sent =
        publish_descriptor_to_consumers!(state, claim.seq, meta_version, now_ns, trace_id)
    (shared_sent || per_consumer_sent) || return false

    if state.supports_progress && should_emit_progress!(state, UInt64(values_len), true)
        emit_progress_complete!(state, seq, UInt64(values_len))
    end

    return true
end

"""
Commit a SlotClaim after the payload has been filled externally.

Arguments:
- `state`: producer state and runtime resources.
- `claim`: slot claim returned from `try_claim_slot!`.
- `values_len`: number of payload bytes filled.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function commit_slot!(
    state::ProducerState,
    claim::SlotClaim,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return commit_slot!(state, claim, values_len, shape, strides, dtype, meta_version, UInt64(0))
end

"""
Commit a SlotClaim after the payload has been filled externally (keyword wrapper).

Arguments:
- `state`: producer state and runtime resources.
- `claim`: slot claim returned from `try_claim_slot!`.
- `values_len`: number of payload bytes filled.
- `shape`: tensor dimensions (Int32).
- `strides`: tensor strides (Int32).
- `dtype`: element type enum.
- `meta_version`: metadata schema version for this frame.

Returns:
- `true` if the descriptor was published (shared or per-consumer), `false` otherwise.
"""
function commit_slot!(
    state::ProducerState,
    claim::SlotClaim;
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    trace_id::UInt64 = UInt64(0),
)
    return commit_slot!(state, claim, values_len, shape, strides, dtype, meta_version, trace_id)
end
