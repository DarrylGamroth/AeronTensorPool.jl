@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::ProducerRevoke, state::ConsumerState)
    state.awaiting_announce_epoch = state.announce_event_epoch
    set_interval!(state.announce_wait_timer, state.config.announce_freshness_ns * ANNOUNCE_WAIT_MULTIPLIER)
    reset!(state.announce_wait_timer, state.announce_event_now_ns)
    state.announce_wait_active = true
    return Hsm.transition!(sm, :WaitingAnnounce)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::AnnounceTimeout, state::ConsumerState)
    reset_mappings!(state)
    reset!(state.announce_wait_timer, state.announce_event_now_ns)
    return Hsm.transition!(sm, :WaitingAnnounce)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::AnnounceSeen, state::ConsumerState)
    state.awaiting_announce_epoch = UInt64(0)
    state.announce_wait_active = false
    set_interval!(state.announce_wait_timer, UInt64(0))
    return Hsm.transition!(sm, :Ready)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::EpochChange, state::ConsumerState)
    return Hsm.transition!(sm, :RemapPending)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::RemapComplete, state::ConsumerState)
    set_mapping_phase!(state, MAPPED)
    return Hsm.transition!(sm, :Ready)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::AbortWait, state::ConsumerState)
    state.awaiting_announce_epoch = UInt64(0)
    state.announce_wait_active = false
    set_interval!(state.announce_wait_timer, UInt64(0))
    return Hsm.transition!(sm, :Idle)
end
