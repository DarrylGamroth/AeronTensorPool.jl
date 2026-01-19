@on_event function(sm::BridgeAssemblyLifecycle, ::Root, ::AssemblyStart, state::BridgeReceiverState)
    reset_bridge_assembly!(
        state.assembly,
        state.assembly_event_seq,
        state.assembly_event_epoch,
        state.assembly_event_chunk_count,
        state.assembly_event_payload_length,
        state.assembly_event_now_ns,
    )
    return Hsm.transition!(sm, :Assembling)
end

@on_event function(sm::BridgeAssemblyLifecycle, ::Root, ::AssemblyClear, state::BridgeReceiverState)
    clear_bridge_assembly!(state.assembly, state.assembly_event_now_ns)
    return Hsm.transition!(sm, :Idle)
end

@on_event function(sm::BridgeAssemblyLifecycle, ::Root, ::AssemblyTimeout, state::BridgeReceiverState)
    clear_bridge_assembly!(state.assembly, state.assembly_event_now_ns)
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
    state.assembly_event_seq = seq
    state.assembly_event_epoch = epoch
    state.assembly_event_chunk_count = chunk_count
    state.assembly_event_payload_length = payload_length
    state.assembly_event_now_ns = now_ns
    dispatch_assembly_event!(state, :AssemblyStart)
    return nothing
end

function bridge_clear_assembly!(state::BridgeReceiverState, now_ns::UInt64)
    state.assembly_event_now_ns = now_ns
    dispatch_assembly_event!(state, :AssemblyClear)
    return nothing
end

function bridge_timeout_assembly!(state::BridgeReceiverState, now_ns::UInt64)
    state.assembly_event_now_ns = now_ns
    dispatch_assembly_event!(state, :AssemblyTimeout)
    return nothing
end
