"""
Hook container for decimator events.
"""
struct DecimatorHooks{F}
    on_republish!::F
end

@inline function noop_decimator_republish!(::DecimatorState, ::TensorSlotHeader)
    return nothing
end

const NOOP_DECIMATOR_HOOKS = DecimatorHooks(noop_decimator_republish!)
