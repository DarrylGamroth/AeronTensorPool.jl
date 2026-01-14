@hsmdef mutable struct RateLimiterMappingLifecycle end

@statedef RateLimiterMappingLifecycle :Unbound
@statedef RateLimiterMappingLifecycle :Bound
@statedef RateLimiterMappingLifecycle :Active

@on_initial function(sm::RateLimiterMappingLifecycle, ::Root)
    return Hsm.transition!(sm, :Unbound)
end
