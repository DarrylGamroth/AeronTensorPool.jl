@on_event function(sm::ProducerDriverLifecycle, ::Root, ::AttachRequested, state::ProducerState)
    return Hsm.transition!(sm, :PendingAttach)
end

@on_event function(sm::ProducerDriverLifecycle, ::Root, ::AttachOk, state::ProducerState)
    return Hsm.transition!(sm, :Active)
end

@on_event function(sm::ProducerDriverLifecycle, ::Root, ::AttachFailed, state::ProducerState)
    return Hsm.transition!(sm, :Inactive)
end

@on_event function(sm::ProducerDriverLifecycle, ::Root, ::LeaseInvalid, state::ProducerState)
    return Hsm.transition!(sm, :Inactive)
end

function producer_driver_active(state::ProducerState)
    dc = state.driver_client
    dc === nothing && return true
    return Hsm.current(state.driver_lifecycle) == :Active &&
           dc.lease_id != 0 && !dc.revoked && !dc.shutdown
end
