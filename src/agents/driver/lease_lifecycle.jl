@hsmdef mutable struct LeaseLifecycle end

@statedef LeaseLifecycle :Live
@statedef LeaseLifecycle :Init :Live
@statedef LeaseLifecycle :Active :Live
@statedef LeaseLifecycle :Detached :Live
@statedef LeaseLifecycle :Expired :Live
@statedef LeaseLifecycle :Revoked :Live
@statedef LeaseLifecycle :Closed

@on_initial function(sm::LeaseLifecycle, ::Root)
    return Hsm.transition!(sm, :Init)
end

@on_event function(sm::LeaseLifecycle, ::Init, ::AttachOk, _)
    return Hsm.transition!(sm, :Active)
end

@on_event function(sm::LeaseLifecycle, ::Active, ::Keepalive, _)
    return Hsm.EventHandled
end

@on_event function(sm::LeaseLifecycle, ::Active, ::Detach, _)
    return Hsm.transition!(sm, :Detached)
end

@on_event function(sm::LeaseLifecycle, ::Active, ::LeaseTimeout, _)
    return Hsm.transition!(sm, :Expired)
end

@on_event function(sm::LeaseLifecycle, ::Active, ::Revoke, _)
    return Hsm.transition!(sm, :Revoked)
end

@on_event function(sm::LeaseLifecycle, ::Live, ::Close, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::LeaseLifecycle, ::Closed, ::Close, _)
    return Hsm.EventHandled
end

@on_event function(sm::LeaseLifecycle, ::Root, event::Any, arg::DriverMetrics)
    arg.lease_hsm_unhandled += 1
    return Hsm.EventHandled
end
