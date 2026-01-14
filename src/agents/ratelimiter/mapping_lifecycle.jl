@on_event function(sm::RateLimiterMappingLifecycle, ::Root, ::RateLimiterBound, state::RateLimiterMappingState)
    return Hsm.transition!(sm, :Bound)
end

@on_event function(sm::RateLimiterMappingLifecycle, ::Root, ::RateLimiterActive, state::RateLimiterMappingState)
    return Hsm.transition!(sm, :Active)
end

@on_event function(sm::RateLimiterMappingLifecycle, ::Root, ::RateLimiterReset, state::RateLimiterMappingState)
    return Hsm.transition!(sm, :Unbound)
end

function dispatch_mapping_event!(state::RateLimiterMappingState, event)
    return Hsm.dispatch!(state.lifecycle, event, state)
end

function mark_mapping_bound!(state::RateLimiterMappingState)
    Hsm.current(state.lifecycle) == :Bound && return nothing
    Hsm.current(state.lifecycle) == :Active && return nothing
    dispatch_mapping_event!(state, RateLimiterBound())
    return nothing
end

function mark_mapping_active!(state::RateLimiterMappingState)
    Hsm.current(state.lifecycle) == :Active && return nothing
    dispatch_mapping_event!(state, RateLimiterActive())
    return nothing
end

function reset_mapping_lifecycle!(state::RateLimiterMappingState)
    dispatch_mapping_event!(state, RateLimiterReset())
    return nothing
end
