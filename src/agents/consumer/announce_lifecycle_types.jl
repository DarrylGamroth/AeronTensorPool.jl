@hsmdef mutable struct ConsumerAnnounceLifecycle end

@statedef ConsumerAnnounceLifecycle :Idle
@statedef ConsumerAnnounceLifecycle :WaitingAnnounce
@statedef ConsumerAnnounceLifecycle :RemapPending
@statedef ConsumerAnnounceLifecycle :Ready

@on_initial function(sm::ConsumerAnnounceLifecycle, ::Root)
    return Hsm.transition!(sm, :Idle)
end
