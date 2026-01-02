@hsmdef mutable struct LeaseLifecycle end

@statedef LeaseLifecycle :Init
@statedef LeaseLifecycle :Active
@statedef LeaseLifecycle :Detached
@statedef LeaseLifecycle :Expired
@statedef LeaseLifecycle :Revoked
@statedef LeaseLifecycle :Closed

@on_initial function(sm::LeaseLifecycle, ::Root)
    return Hsm.transition!(sm, :Init)
end
