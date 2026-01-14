@on_event function(sm::ConsumerMappingLifecycle, ::Root, ::ToUnmapped, state::ConsumerState)
    state.phase = UNMAPPED
    return Hsm.transition!(sm, :Unmapped)
end

@on_event function(sm::ConsumerMappingLifecycle, ::Root, ::ToMapped, state::ConsumerState)
    state.phase = MAPPED
    return Hsm.transition!(sm, :Mapped)
end

@on_event function(sm::ConsumerMappingLifecycle, ::Root, ::ToFallback, state::ConsumerState)
    state.phase = FALLBACK
    return Hsm.transition!(sm, :Fallback)
end

function set_mapping_phase!(state::ConsumerState, phase::ConsumerPhase)
    event = if phase == UNMAPPED
        :ToUnmapped
    elseif phase == MAPPED
        :ToMapped
    else
        :ToFallback
    end
    return Hsm.dispatch!(state.mapping_lifecycle, event, state)
end
