@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::ProducerRevoke, state::ConsumerState)
    return Hsm.transition!(sm, :WaitingAnnounce)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::AnnounceTimeout, state::ConsumerState)
    return Hsm.transition!(sm, :WaitingAnnounce)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::AnnounceSeen, state::ConsumerState)
    return Hsm.transition!(sm, :Ready)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::EpochChange, state::ConsumerState)
    return Hsm.transition!(sm, :RemapPending)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::RemapComplete, state::ConsumerState)
    return Hsm.transition!(sm, :Ready)
end

@on_event function(sm::ConsumerAnnounceLifecycle, ::Root, ::AbortWait, state::ConsumerState)
    return Hsm.transition!(sm, :Idle)
end
