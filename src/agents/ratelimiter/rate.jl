"""
Return the rate period in nanoseconds for a max_rate_hz value (0 = unlimited).
"""
@inline function rate_period_ns(rate_hz::UInt32)
    rate_hz == 0 && return UInt64(0)
    return UInt64(1_000_000_000) ÷ UInt64(rate_hz)
end

"""
Update rate limit from ConsumerHello (per-consumer).
"""
function apply_consumer_hello_rate!(state::RateLimiterMappingState, msg::ConsumerHello.Decoder)
    ConsumerHello.streamId(msg) == state.mapping.dest_stream_id || return nothing
    consumer_id = UInt32(ConsumerHello.consumerId(msg))
    if state.dest_consumer_id == 0
        state.dest_consumer_id = consumer_id
        mark_mapping_bound!(state)
    elseif state.dest_consumer_id != consumer_id
        @tp_warn "rate limiter mapping already bound to consumer" existing_consumer_id = state.dest_consumer_id consumer_id
        return nothing
    end
    rate_hz = UInt32(ConsumerHello.maxRateHz(msg))
    if rate_hz != typemax(UInt32)
        state.max_rate_hz = rate_hz
    end
    return nothing
end

"""
Check whether a frame can be accepted now based on rate limit.
"""
function rate_limit_allow!(state::RateLimiterMappingState, now_ns::UInt64)
    period_ns = rate_period_ns(state.max_rate_hz)
    period_ns == 0 && return true
    if now_ns >= state.next_allowed_ns
        state.next_allowed_ns = now_ns + period_ns
        return true
    end
    return false
end

"""
Clear pending frame state.
"""
function clear_pending!(pending::RateLimiterPending)
    pending.valid = false
    pending.seq = UInt64(0)
    pending.trace_id = UInt64(0)
    pending.payload_len = UInt32(0)
    return nothing
end

"""
Store a pending frame by copying payload bytes.
"""
function store_pending!(
    pending::RateLimiterPending,
    header::SlotHeader,
    trace_id::UInt64,
    payload_ptr::Ptr{UInt8},
    payload_len::Int,
)
    payload_len <= length(pending.payload_buf) || return false
    unsafe_copyto!(pointer(pending.payload_buf), payload_ptr, payload_len)
    pending.header = header
    pending.seq = seqlock_sequence(header.seq_commit)
    pending.trace_id = trace_id
    pending.payload_len = UInt32(payload_len)
    pending.valid = true
    return true
end

"""
Commit a claimed destination slot and publish a descriptor.
"""
function rate_limiter_commit_claim!(
    state::RateLimiterMappingState,
    header::SlotHeader,
    claim::SlotClaim,
    trace_id::UInt64,
)
    producer_state = state.producer_agent.state
    Producer.producer_driver_active(producer_state) || return false

    payload_len = Int(header.values_len_bytes)
    payload_len <= claim.stride_bytes || return false
    claim.header_index == UInt32(claim.seq & (UInt64(producer_state.config.nslots) - 1)) || return false

    header_offset = header_slot_offset(claim.header_index)
    commit_ptr = header_commit_ptr_from_offset(producer_state.mappings.header_mmap, header_offset)

    wrap_slot_header!(producer_state.runtime.slot_encoder, producer_state.mappings.header_mmap, header_offset)
    dims = state.scratch_dims
    strides = state.scratch_strides
    fill!(dims, Int32(0))
    fill!(strides, Int32(0))
    ndims = Int(header.tensor.ndims)
    for i in 1:ndims
        dims[i] = header.tensor.dims[i]
        strides[i] = header.tensor.strides[i]
    end
    @inbounds write_slot_header!(
        producer_state.runtime.slot_encoder,
        producer_state.runtime.tensor_encoder,
        header.timestamp_ns,
        header.meta_version,
        UInt32(payload_len),
        claim.payload_slot,
        UInt32(0),
        claim.pool_id,
        header.tensor.dtype,
        header.tensor.major_order,
        header.tensor.ndims,
        header.tensor.progress_unit,
        header.tensor.progress_stride_bytes,
        dims,
        strides,
    )

    seqlock_commit_write!(commit_ptr, claim.seq)

    now_ns = UInt64(Clocks.time_nanos(state.producer_agent.state.clock))
    shared_sent = let st = producer_state,
        seq = claim.seq,
        meta_version = header.meta_version,
        now_ns = now_ns,
        trace_id = trace_id
        with_claimed_buffer!(st.runtime.pub_descriptor, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
            Producer.encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, meta_version, now_ns, trace_id)
        end
    end
    per_consumer_sent =
        Producer.publish_descriptor_to_consumers!(producer_state, claim.seq, header.meta_version, now_ns, trace_id)
    (shared_sent || per_consumer_sent) || return false
    if producer_state.seq <= claim.seq
        producer_state.seq = claim.seq + 1
    end
    return true
end

"""
Rematerialize a source frame into the destination producer.
"""
function rematerialize_frame!(
    state::RateLimiterMappingState,
    header::SlotHeader,
    trace_id::UInt64,
    payload_ptr::Ptr{UInt8},
    payload_len::Int,
)
    producer_state = state.producer_agent.state
    Producer.producer_driver_active(producer_state) || return false

    pool_idx = Producer.select_pool(producer_state.config.payload_pools, payload_len)
    pool_idx == 0 && return false
    pool = producer_state.config.payload_pools[pool_idx]
    payload_len <= pool.stride_bytes || return false

    seq = seqlock_sequence(header.seq_commit)
    if producer_state.seq > seq
        return false
    end
    producer_state.seq = seq

    claim = Producer.try_claim_slot!(producer_state, pool.pool_id)
    claim === nothing && return false
    payload_len <= claim.stride_bytes || return false

    unsafe_copyto!(claim.ptr, payload_ptr, payload_len)
    return rate_limiter_commit_claim!(state, header, claim, trace_id)
end
