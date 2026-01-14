@hsmdef mutable struct ConsumerMappingLifecycle end

@statedef ConsumerMappingLifecycle :Unmapped
@statedef ConsumerMappingLifecycle :Mapped
@statedef ConsumerMappingLifecycle :Fallback

@on_initial function(sm::ConsumerMappingLifecycle, ::Root)
    return Hsm.transition!(sm, :Unmapped)
end
