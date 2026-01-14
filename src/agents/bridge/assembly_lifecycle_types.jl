@hsmdef mutable struct BridgeAssemblyLifecycle end

@statedef BridgeAssemblyLifecycle :Idle
@statedef BridgeAssemblyLifecycle :Assembling

@on_initial function(sm::BridgeAssemblyLifecycle, ::Root)
    return Hsm.transition!(sm, :Idle)
end
