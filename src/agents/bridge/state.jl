"""
Configuration for the optional bridge role.
"""
mutable struct BridgeConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    payload_stream_id::Int32
    stream_id::UInt32
    bridge_epoch::UInt64
end

"""
Bridge runtime state for republishing payloads and descriptors.
"""
mutable struct BridgeState
    consumer_state::ConsumerState
    config::BridgeConfig
    ctx::Aeron.Context
    client::Aeron.Client
    pub_descriptor::Aeron.Publication
    pub_payload::Aeron.Publication
    descriptor_buf::Vector{UInt8}
    descriptor_encoder::FrameDescriptor.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    descriptor_claim::Aeron.BufferClaim
end
