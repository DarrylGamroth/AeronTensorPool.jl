@on_event function(sm::RateLimiterMappingLifecycle, ::Root, ::MappingBound, state::RateLimiterMappingState)
    return Hsm.transition!(sm, :Bound)
end

@on_event function(sm::RateLimiterMappingLifecycle, ::Root, ::MappingActive, state::RateLimiterMappingState)
    return Hsm.transition!(sm, :Active)
end

@on_event function(sm::RateLimiterMappingLifecycle, ::Root, ::MappingReset, state::RateLimiterMappingState)
    state.dest_consumer_id = UInt32(0)
    state.max_rate_hz = state.mapping.max_rate_hz
    state.next_allowed_ns = UInt64(0)
    state.last_source_epoch = state.mapping_event_epoch
    clear_pending!(state.pending)
    return Hsm.transition!(sm, :Unbound)
end

function dispatch_mapping_event!(state::RateLimiterMappingState, event::Symbol)
    return Hsm.dispatch!(state.lifecycle, event, state)
end

function mark_mapping_bound!(state::RateLimiterMappingState)
    Hsm.current(state.lifecycle) == :Bound && return nothing
    Hsm.current(state.lifecycle) == :Active && return nothing
    dispatch_mapping_event!(state, :MappingBound)
    return nothing
end

function mark_mapping_active!(state::RateLimiterMappingState)
    Hsm.current(state.lifecycle) == :Active && return nothing
    dispatch_mapping_event!(state, :MappingActive)
    return nothing
end

function reset_mapping_lifecycle!(state::RateLimiterMappingState)
    dispatch_mapping_event!(state, :MappingReset)
    return nothing
end
