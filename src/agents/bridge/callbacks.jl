"""
Hook container for bridge events.
"""
struct BridgeCallbacks{FSender, FReceiver}
    on_send_frame!::FSender
    on_receive_chunk!::FReceiver
end

noop_bridge_send!(::BridgeSenderState, ::FrameDescriptor.Decoder) = nothing

noop_bridge_receive!(::BridgeReceiverState, ::BridgeFrameChunk.Decoder) = nothing

const NOOP_BRIDGE_CALLBACKS = BridgeCallbacks(noop_bridge_send!, noop_bridge_receive!)
