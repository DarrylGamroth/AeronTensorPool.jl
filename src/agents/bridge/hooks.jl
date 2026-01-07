"""
Hook container for bridge events.
"""
struct BridgeHooks{FSender, FReceiver}
    on_send_frame!::FSender
    on_receive_chunk!::FReceiver
end

function noop_bridge_send!(::BridgeSenderState, ::FrameDescriptor.Decoder)
    return nothing
end

function noop_bridge_receive!(::BridgeReceiverState, ::BridgeFrameChunk.Decoder)
    return nothing
end

const NOOP_BRIDGE_HOOKS = BridgeHooks(noop_bridge_send!, noop_bridge_receive!)
