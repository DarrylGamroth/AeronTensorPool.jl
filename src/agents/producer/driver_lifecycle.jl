@hsmdef mutable struct ProducerDriverLifecycle end

@statedef ProducerDriverLifecycle :Inactive
@statedef ProducerDriverLifecycle :PendingAttach
@statedef ProducerDriverLifecycle :Active
@statedef ProducerDriverLifecycle :Backoff

@on_initial function(sm::ProducerDriverLifecycle, ::Root)
    return Hsm.transition!(sm, :Inactive)
end
