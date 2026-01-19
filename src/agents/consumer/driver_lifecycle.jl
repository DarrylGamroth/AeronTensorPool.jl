@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachRequested, state::ConsumerState)
    state.driver_active = false
    return Hsm.transition!(sm, :Attaching)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachOk, state::ConsumerState)
    state.driver_active = true
    return Hsm.transition!(sm, :Attached)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachFailed, state::ConsumerState)
    state.driver_active = false
    return Hsm.transition!(sm, :Unattached)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::LeaseInvalid, state::ConsumerState)
    state.driver_active = false
    return Hsm.transition!(sm, :Unattached)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachTimeout, state::ConsumerState)
    state.driver_active = false
    return Hsm.transition!(sm, :Backoff)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::BackoffElapsed, state::ConsumerState)
    state.driver_active = false
    return Hsm.transition!(sm, :Unattached)
end
