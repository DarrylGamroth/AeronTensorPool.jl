"""
Handle a source frame from the consumer and apply rate limiting.
"""
function handle_source_frame!(
    mapping_state::RateLimiterMappingState,
    consumer_state::ConsumerState,
    view::ConsumerFrameView,
)
    now_ns = UInt64(Clocks.time_nanos(consumer_state.clock))
    mapped_epoch = consumer_state.mappings.mapped_epoch
    if mapped_epoch != mapping_state.last_source_epoch
        mapping_state.last_source_epoch = mapped_epoch
        mapping_state.next_allowed_ns = UInt64(0)
        clear_pending!(mapping_state.pending)
    end

    header = view.header
    payload_ptr = pointer(view.payload.mmap, view.payload.offset + 1)
    payload_len = Int(view.payload.len)

    if rate_limit_allow!(mapping_state, now_ns)
        rematerialize_frame!(mapping_state, header, payload_ptr, payload_len)
        clear_pending!(mapping_state.pending)
    else
        store_pending!(mapping_state.pending, header, payload_ptr, payload_len)
    end
    return nothing
end

"""
Publish pending frame when the rate slot opens.
"""
function publish_pending!(mapping_state::RateLimiterMappingState)
    pending = mapping_state.pending
    pending.valid || return false
    now_ns = UInt64(Clocks.time_nanos(mapping_state.consumer_agent.state.clock))
    if rate_limit_allow!(mapping_state, now_ns)
        ptr = pointer(pending.payload_buf)
        ok = rematerialize_frame!(mapping_state, pending.header, ptr, Int(pending.payload_len))
        if ok
            clear_pending!(pending)
        else
            seq = pending.seq
            clear_pending!(pending)
            @tp_debug "rate limiter dropped pending frame" seq
        end
        return ok
    end
    return false
end

"""
Poll forwarding subscriptions.
"""
function poll_forwarding!(state::RateLimiterState, fragment_limit::Int32)
    work_count = 0
    if state.metadata_sub !== nothing && state.metadata_asm !== nothing
        work_count += Aeron.poll(state.metadata_sub, state.metadata_asm, fragment_limit)
    end
    if state.control_sub !== nothing && state.control_asm !== nothing
        work_count += Aeron.poll(state.control_sub, state.control_asm, fragment_limit)
    end
    if state.qos_sub !== nothing && state.qos_asm !== nothing
        work_count += Aeron.poll(state.qos_sub, state.qos_asm, fragment_limit)
    end
    return work_count
end

"""
Rate limiter duty cycle: poll mappings, forward metadata/progress/qos, and return work count.
"""
function rate_limiter_do_work!(state::RateLimiterState, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    fetch!(state.clock)
    work_count = 0
    for mapping in state.mappings
        work_count += Agent.do_work(mapping.consumer_agent)
        work_count += Agent.do_work(mapping.producer_agent)
        publish_pending!(mapping)
    end
    work_count += poll_forwarding!(state, fragment_limit)
    return work_count
end
