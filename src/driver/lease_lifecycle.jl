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

@on_event function(sm::LeaseLifecycle, ::Init, ::AttachOk, _)
    return Hsm.transition!(sm, :Active)
end

@on_event function(sm::LeaseLifecycle, ::Init, ::Close, _)
    return Hsm.transition!(sm, :Closed)
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

@on_event function(sm::LeaseLifecycle, ::Active, ::Close, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::LeaseLifecycle, ::Detached, ::Close, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::LeaseLifecycle, ::Expired, ::Close, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::LeaseLifecycle, ::Revoked, ::Close, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::LeaseLifecycle, ::Closed, ::Close, _)
    return Hsm.EventHandled
end

@on_event function(sm::LeaseLifecycle, ::Root, event::Any, arg)
    if arg !== nothing && hasproperty(arg, :lease_hsm_unhandled)
        arg.lease_hsm_unhandled += 1
    end
    return Hsm.EventHandled
end
