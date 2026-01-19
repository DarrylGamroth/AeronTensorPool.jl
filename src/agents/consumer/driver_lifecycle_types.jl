@hsmdef mutable struct ConsumerDriverLifecycle end

@statedef ConsumerDriverLifecycle :Unattached
@statedef ConsumerDriverLifecycle :Attaching
@statedef ConsumerDriverLifecycle :Attached
@statedef ConsumerDriverLifecycle :Backoff

@on_initial function(sm::ConsumerDriverLifecycle, ::Root)
    return Hsm.transition!(sm, :Unattached)
end
