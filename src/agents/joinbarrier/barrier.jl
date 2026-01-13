@inline function reset_result!(result::JoinBarrierResult)
    result.ready = false
    result.missing_count = 0
    result.stale_count = 0
    return nothing
end

@inline function reset_input_state!(state::JoinBarrierState, idx::Int)
    state.observed_seq[idx] = UInt64(0)
    state.processed_seq[idx] = UInt64(0)
    state.observed_time[idx] = UInt64(0)
    state.processed_time[idx] = UInt64(0)
    state.last_observed_ns[idx] = UInt64(0)
    state.seen_any[idx] = false
    state.seen_seq[idx] = false
    state.seen_time[idx] = false
    return nothing
end

function invalidate_latest!(state::JoinBarrierState, stream_id::UInt32)
    slots = get(state.input_index, stream_id, nothing)
    slots === nothing && return false
    for idx in slots
        state.seen_any[idx] = false
        state.seen_seq[idx] = false
        state.seen_time[idx] = false
    end
    return true
end

@inline function saturating_sub_u64(value::UInt64, sub::UInt64)
    return value >= sub ? value - sub : UInt64(0)
end

function sequence_required_seq(rule::SequenceMergeRule, out_seq::UInt64)
    if rule.rule_type == Merge.MergeRuleType.OFFSET
        offset = rule.offset
        offset === nothing && return nothing
        if offset >= 0
            return out_seq + UInt64(offset)
        end
        neg = UInt64(-offset)
        out_seq < neg && return nothing
        return out_seq - neg
    elseif rule.rule_type == Merge.MergeRuleType.WINDOW
        window = rule.window_size
        window === nothing && return nothing
        window == 0 && return nothing
        out_seq < UInt64(window - 1) && return nothing
        return out_seq
    end
    return nothing
end

function timestamp_required_time(rule::TimestampMergeRule, out_time::UInt64, lateness_ns::UInt64)
    if rule.rule_type == Merge.MergeTimeRuleType.OFFSET_NS
        offset = rule.offset_ns
        offset === nothing && return nothing
        if offset >= 0
            required_in = out_time + UInt64(offset)
        else
            neg = UInt64(-offset)
            out_time < neg && return nothing
            required_in = out_time - neg
        end
        return saturating_sub_u64(required_in, lateness_ns)
    elseif rule.rule_type == Merge.MergeTimeRuleType.WINDOW_NS
        window = rule.window_ns
        window === nothing && return nothing
        window == 0 && return nothing
        out_time < window && return nothing
        return saturating_sub_u64(out_time, lateness_ns)
    end
    return nothing
end

function update_observed_seq_epoch!(
    state::JoinBarrierState,
    stream_id::UInt32,
    epoch::UInt64,
    seq::UInt64,
    now_ns::UInt64,
)
    slots = get(state.input_index, stream_id, nothing)
    slots === nothing && return false
    for idx in slots
        if state.observed_epoch[idx] != epoch
            state.observed_epoch[idx] = epoch
            reset_input_state!(state, idx)
        end
        if seq > state.observed_seq[idx]
            state.observed_seq[idx] = seq
        end
        state.last_observed_ns[idx] = now_ns
        state.seen_any[idx] = true
        state.seen_seq[idx] = true
    end
    return true
end

function update_processed_seq_epoch!(state::JoinBarrierState, stream_id::UInt32, epoch::UInt64, seq::UInt64)
    slots = get(state.input_index, stream_id, nothing)
    slots === nothing && return false
    for idx in slots
        if state.observed_epoch[idx] != epoch
            state.observed_epoch[idx] = epoch
            reset_input_state!(state, idx)
        end
        if seq > state.processed_seq[idx]
            state.processed_seq[idx] = seq
        end
    end
    return true
end

function update_observed_time!(
    state::JoinBarrierState,
    stream_id::UInt32,
    source::Merge.TimestampSource.SbeEnum,
    timestamp_ns::UInt64,
    now_ns::UInt64,
    clock_domain::Merge.ClockDomain.SbeEnum,
)
    epoch = state.active_epoch
    return update_observed_time_epoch!(state, stream_id, epoch, source, timestamp_ns, now_ns, clock_domain)
end

function update_observed_time_epoch!(
    state::JoinBarrierState,
    stream_id::UInt32,
    epoch::UInt64,
    source::Merge.TimestampSource.SbeEnum,
    timestamp_ns::UInt64,
    now_ns::UInt64,
    clock_domain::Merge.ClockDomain.SbeEnum,
)
    state.clock_domain === nothing && return false
    state.clock_domain == clock_domain || return false
    key = merge_time_key(stream_id, source)
    slots = get(state.time_index, key, nothing)
    slots === nothing && return false
    for idx in slots
        if epoch != UInt64(0) && state.observed_epoch[idx] != epoch
            state.observed_epoch[idx] = epoch
            reset_input_state!(state, idx)
        end
        if timestamp_ns > state.observed_time[idx]
            state.observed_time[idx] = timestamp_ns
        end
        state.last_observed_ns[idx] = now_ns
        state.seen_any[idx] = true
        state.seen_time[idx] = true
    end
    return true
end

function update_processed_time_epoch!(
    state::JoinBarrierState,
    stream_id::UInt32,
    epoch::UInt64,
    timestamp_ns::UInt64,
)
    slots = get(state.input_index, stream_id, nothing)
    slots === nothing && return false
    for idx in slots
        if epoch != UInt64(0) && state.observed_epoch[idx] != epoch
            state.observed_epoch[idx] = epoch
            reset_input_state!(state, idx)
        end
        if timestamp_ns > state.processed_time[idx]
            state.processed_time[idx] = timestamp_ns
        end
    end
    return true
end

@inline function update_observed_seq!(state::JoinBarrierState, stream_id::UInt32, seq::UInt64, now_ns::UInt64)
    epoch = state.active_epoch
    return update_observed_seq_epoch!(state, stream_id, epoch, seq, now_ns)
end

@inline function update_processed_seq!(state::JoinBarrierState, stream_id::UInt32, seq::UInt64)
    epoch = state.active_epoch
    return update_processed_seq_epoch!(state, stream_id, epoch, seq)
end

@inline function update_processed_time!(state::JoinBarrierState, stream_id::UInt32, timestamp_ns::UInt64)
    epoch = state.active_epoch
    return update_processed_time_epoch!(state, stream_id, epoch, timestamp_ns)
end

@inline function update_observed_slot_header_time!(
    state::JoinBarrierState,
    stream_id::UInt32,
    epoch::UInt64,
    timestamp_ns::UInt64,
    now_ns::UInt64,
    clock_domain::Merge.ClockDomain.SbeEnum,
)
    return update_observed_time_epoch!(
        state,
        stream_id,
        epoch,
        Merge.TimestampSource.SLOT_HEADER,
        timestamp_ns,
        now_ns,
        clock_domain,
    )
end

function sequence_ready!(state::JoinBarrierState, out_seq::UInt64, now_ns::UInt64)
    reset_result!(state.result)
    map = state.sequence_map
    map === nothing && return state.result

    stale_timeout = state.stale_timeout_ns
    use_processed = state.config.use_processed_cursor
    for (i, rule) in enumerate(map.rules)
        required = sequence_required_seq(rule, out_seq)
        if required === nothing
            state.result.missing_count += 1
            state.result.missing_inputs[state.result.missing_count] = rule.input_stream_id
            continue
        end
        observed = state.observed_seq[i]
        processed = state.processed_seq[i]
        if observed < required || (use_processed && processed < required)
            if stale_timeout !== nothing && state.last_observed_ns[i] != 0 &&
               now_ns - state.last_observed_ns[i] > stale_timeout
                state.result.stale_count += 1
                state.result.stale_inputs[state.result.stale_count] = rule.input_stream_id
            else
                state.result.missing_count += 1
                state.result.missing_inputs[state.result.missing_count] = rule.input_stream_id
            end
        end
    end

    state.result.ready = state.result.missing_count == 0
    return state.result
end

function timestamp_ready!(state::JoinBarrierState, out_time::UInt64, now_ns::UInt64)
    reset_result!(state.result)
    map = state.timestamp_map
    map === nothing && return state.result

    stale_timeout = state.stale_timeout_ns
    use_processed = state.config.use_processed_cursor
    lateness_ns = state.lateness_ns
    for (i, rule) in enumerate(map.rules)
        required = timestamp_required_time(rule, out_time, lateness_ns)
        if required === nothing
            state.result.missing_count += 1
            state.result.missing_inputs[state.result.missing_count] = rule.input_stream_id
            continue
        end
        observed = state.observed_time[i]
        processed = state.processed_time[i]
        if observed < required || (use_processed && processed < required)
            if stale_timeout !== nothing && state.last_observed_ns[i] != 0 &&
               now_ns - state.last_observed_ns[i] > stale_timeout
                state.result.stale_count += 1
                state.result.stale_inputs[state.result.stale_count] = rule.input_stream_id
            else
                state.result.missing_count += 1
                state.result.missing_inputs[state.result.missing_count] = rule.input_stream_id
            end
        end
    end

    state.result.ready = state.result.missing_count == 0
    return state.result
end

function latest_value_ready!(state::JoinBarrierState, now_ns::UInt64)
    reset_result!(state.result)
    map = state.sequence_map === nothing ? state.timestamp_map : state.sequence_map
    map === nothing && return state.result

    stale_timeout = state.stale_timeout_ns
    use_timestamp = state.config.latest_value_use_timestamp
    if use_timestamp && state.timestamp_map === nothing
        for rule in map.rules
            state.result.missing_count += 1
            state.result.missing_inputs[state.result.missing_count] = rule.input_stream_id
        end
        return state.result
    end
    if use_timestamp && state.clock_domain === nothing
        for rule in map.rules
            state.result.missing_count += 1
            state.result.missing_inputs[state.result.missing_count] = rule.input_stream_id
        end
        return state.result
    end
    for (i, rule) in enumerate(map.rules)
        has_value = use_timestamp ? state.seen_time[i] : state.seen_seq[i]
        has_value || begin
            state.result.missing_count += 1
            state.result.missing_inputs[state.result.missing_count] = rule.input_stream_id
            continue
        end
        if stale_timeout !== nothing && state.last_observed_ns[i] != 0 &&
           now_ns - state.last_observed_ns[i] > stale_timeout
            state.result.stale_count += 1
            state.result.stale_inputs[state.result.stale_count] = rule.input_stream_id
        end
    end

    state.result.ready = state.result.missing_count == 0
    return state.result
end

function join_barrier_ready!(state::JoinBarrierState, out_value::UInt64, now_ns::UInt64)
    mode = state.config.mode
    if mode == SEQUENCE
        return sequence_ready!(state, out_value, now_ns)
    elseif mode == TIMESTAMP
        return timestamp_ready!(state, out_value, now_ns)
    elseif mode == LATEST_VALUE
        return latest_value_ready!(state, now_ns)
    end
    reset_result!(state.result)
    return state.result
end
