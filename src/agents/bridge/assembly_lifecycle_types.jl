@hsmdef mutable struct BridgeAssemblyLifecycle end

@statedef BridgeAssemblyLifecycle :Idle
@statedef BridgeAssemblyLifecycle :Assembling

struct BridgeAssemblyStart end
struct BridgeAssemblyClear end
struct BridgeAssemblyTimeout end

@on_initial function(sm::BridgeAssemblyLifecycle, ::Root)
    return Hsm.transition!(sm, :Idle)
end
