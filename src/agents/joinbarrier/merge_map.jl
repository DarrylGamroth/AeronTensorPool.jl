const MERGE_SCHEMA_ID = Merge.MessageHeader.sbe_schema_id(Merge.MessageHeader.Decoder)

@inline function merge_time_key(stream_id::UInt32, source::Merge.TimestampSource.SbeEnum)
    return (UInt64(stream_id) << 32) | UInt64(source)
end

function validate_join_barrier_config(config::JoinBarrierConfig)
    config.out_stream_id != 0 || throw(ArgumentError("out_stream_id must be nonzero"))
    return config
end

function validate_sequence_rule(rule::SequenceMergeRule)
    if rule.rule_type == Merge.MergeRuleType.OFFSET
        rule.offset === nothing && return false
        rule.window_size === nothing || return false
        return true
    elseif rule.rule_type == Merge.MergeRuleType.WINDOW
        rule.window_size === nothing && return false
        rule.window_size > 0 || return false
        rule.offset === nothing || return false
        return true
    end
    return false
end

function validate_timestamp_rule(rule::TimestampMergeRule)
    if rule.rule_type == Merge.MergeTimeRuleType.OFFSET_NS
        rule.offset_ns === nothing && return false
        rule.window_ns === nothing || return false
        return true
    elseif rule.rule_type == Merge.MergeTimeRuleType.WINDOW_NS
        rule.window_ns === nothing && return false
        rule.window_ns > 0 || return false
        rule.offset_ns === nothing || return false
        return true
    end
    return false
end

function validate_sequence_merge_map(map::SequenceMergeMap)
    map.out_stream_id != 0 || return false
    for rule in map.rules
        validate_sequence_rule(rule) || return false
    end
    return true
end

function validate_timestamp_merge_map(map::TimestampMergeMap)
    map.out_stream_id != 0 || return false
    for rule in map.rules
        validate_timestamp_rule(rule) || return false
    end
    return true
end

function reset_join_barrier_state!(state::JoinBarrierState, rule_count::Int)
    state.input_ids = Vector{UInt32}(undef, rule_count)
    state.time_keys = Vector{UInt64}(undef, rule_count)
    state.observed_epoch = fill(UInt64(0), rule_count)
    state.observed_seq = fill(UInt64(0), rule_count)
    state.processed_seq = fill(UInt64(0), rule_count)
    state.observed_time = fill(UInt64(0), rule_count)
    state.processed_time = fill(UInt64(0), rule_count)
    state.last_observed_ns = fill(UInt64(0), rule_count)
    state.seen_any = fill(false, rule_count)
    state.seen_seq = fill(false, rule_count)
    state.seen_time = fill(false, rule_count)
    state.result.missing_inputs = Vector{UInt32}(undef, rule_count)
    state.result.stale_inputs = Vector{UInt32}(undef, rule_count)
    state.result.ready = false
    state.result.missing_count = 0
    state.result.stale_count = 0
    empty!(state.input_index)
    empty!(state.time_index)
    return nothing
end

function build_input_index!(index::Dict{UInt32, Vector{Int}}, input_ids::Vector{UInt32})
    empty!(index)
    for (i, input_id) in enumerate(input_ids)
        slots = get!(index, input_id, Int[])
        push!(slots, i)
    end
    return nothing
end

function build_time_index!(index::Dict{UInt64, Vector{Int}}, time_keys::Vector{UInt64})
    empty!(index)
    for (i, key) in enumerate(time_keys)
        slots = get!(index, key, Int[])
        push!(slots, i)
    end
    return nothing
end

function apply_sequence_merge_map!(state::JoinBarrierState, map::SequenceMergeMap)
    validate_join_barrier_config(state.config)
    state.config.out_stream_id == map.out_stream_id || return false
    if !validate_sequence_merge_map(map)
        clear_merge_map!(state)
        return false
    end

    rule_count = length(map.rules)
    reset_join_barrier_state!(state, rule_count)

    for (i, rule) in enumerate(map.rules)
        state.input_ids[i] = rule.input_stream_id
    end
    build_input_index!(state.input_index, state.input_ids)

    state.sequence_map = map
    state.timestamp_map = nothing
    state.active_epoch = map.epoch
    state.stale_timeout_ns = map.stale_timeout_ns
    state.clock_domain = nothing
    state.lateness_ns = UInt64(0)
    return true
end

function apply_timestamp_merge_map!(state::JoinBarrierState, map::TimestampMergeMap)
    validate_join_barrier_config(state.config)
    state.config.out_stream_id == map.out_stream_id || return false
    if !validate_timestamp_merge_map(map)
        clear_merge_map!(state)
        return false
    end

    rule_count = length(map.rules)
    reset_join_barrier_state!(state, rule_count)

    for (i, rule) in enumerate(map.rules)
        state.input_ids[i] = rule.input_stream_id
        state.time_keys[i] = merge_time_key(rule.input_stream_id, rule.timestamp_source)
    end
    build_input_index!(state.input_index, state.input_ids)
    build_time_index!(state.time_index, state.time_keys)

    state.sequence_map = nothing
    state.timestamp_map = map
    state.active_epoch = map.epoch
    state.stale_timeout_ns = map.stale_timeout_ns
    state.clock_domain = map.clock_domain
    state.lateness_ns = map.lateness_ns
    return true
end

function clear_merge_map!(state::JoinBarrierState)
    reset_join_barrier_state!(state, 0)
    state.sequence_map = nothing
    state.timestamp_map = nothing
    state.active_epoch = UInt64(0)
    state.stale_timeout_ns = nothing
    state.clock_domain = nothing
    state.lateness_ns = UInt64(0)
    return nothing
end

function set_active_epoch!(state::JoinBarrierState, epoch::UInt64)
    if state.active_epoch != epoch
        clear_merge_map!(state)
        state.active_epoch = epoch
    end
    return nothing
end
