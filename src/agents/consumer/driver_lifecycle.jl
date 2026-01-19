@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachRequested, state::ConsumerState)
    state.driver_active = false
    return Hsm.transition!(sm, :Attaching)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachOk, state::ConsumerState)
    state.driver_active = true
    return Hsm.transition!(sm, :Attached)
end

const DEFAULT_ATTACH_BACKOFF_NS = UInt64(10_000_000)

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachFailed, state::ConsumerState)
    state.driver_active = false
    set_interval!(state.backoff_timer, DEFAULT_ATTACH_BACKOFF_NS)
    reset!(state.backoff_timer, state.attach_event_now_ns)
    return Hsm.transition!(sm, :Backoff)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::LeaseInvalid, state::ConsumerState)
    state.driver_active = false
    reset_mappings!(state)
    abort_announce_wait!(state)
    state.pending_attach_id = Int64(0)
    set_interval!(state.backoff_timer, DEFAULT_ATTACH_BACKOFF_NS)
    reset!(state.backoff_timer, state.attach_event_now_ns)
    return Hsm.transition!(sm, :Backoff)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::AttachTimeout, state::ConsumerState)
    state.driver_active = false
    set_interval!(state.backoff_timer, DEFAULT_ATTACH_BACKOFF_NS)
    reset!(state.backoff_timer, state.attach_event_now_ns)
    return Hsm.transition!(sm, :Backoff)
end

@on_event function(sm::ConsumerDriverLifecycle, ::Root, ::BackoffElapsed, state::ConsumerState)
    state.driver_active = false
    set_interval!(state.backoff_timer, UInt64(0))
    return Hsm.transition!(sm, :Unattached)
end
