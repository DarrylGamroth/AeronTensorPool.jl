@on_event function(sm::BridgeAssemblyLifecycle, ::Root, ::AssemblyStart, state::BridgeReceiverState)
    return Hsm.transition!(sm, :Assembling)
end

@on_event function(sm::BridgeAssemblyLifecycle, ::Root, ::AssemblyClear, state::BridgeReceiverState)
    return Hsm.transition!(sm, :Idle)
end

@on_event function(sm::BridgeAssemblyLifecycle, ::Root, ::AssemblyTimeout, state::BridgeReceiverState)
    return Hsm.transition!(sm, :Idle)
end

function dispatch_assembly_event!(state::BridgeReceiverState, event::Symbol)
    return Hsm.dispatch!(state.assembly_lifecycle, event, state)
end

function bridge_start_assembly!(
    state::BridgeReceiverState,
    seq::UInt64,
    epoch::UInt64,
    chunk_count::UInt32,
    payload_length::UInt32,
    now_ns::UInt64,
)
    reset_bridge_assembly!(state.assembly, seq, epoch, chunk_count, payload_length, now_ns)
    dispatch_assembly_event!(state, :AssemblyStart)
    return nothing
end

function bridge_clear_assembly!(state::BridgeReceiverState, now_ns::UInt64)
    clear_bridge_assembly!(state.assembly, now_ns)
    dispatch_assembly_event!(state, :AssemblyClear)
    return nothing
end

function bridge_timeout_assembly!(state::BridgeReceiverState, now_ns::UInt64)
    clear_bridge_assembly!(state.assembly, now_ns)
    dispatch_assembly_event!(state, :AssemblyTimeout)
    return nothing
end
