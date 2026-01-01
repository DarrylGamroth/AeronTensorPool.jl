"""
Per-stream mapping for the bridge.
"""
struct BridgeMapping
    source_stream_id::UInt32
    dest_stream_id::UInt32
    profile::String
    metadata_stream_id::UInt32
end

"""
Forwarded source pool announce metadata for validation.
"""
mutable struct BridgeSourceInfo
    stream_id::UInt32
    epoch::UInt64
    layout_version::UInt32
    max_dims::UInt8
    pool_stride_bytes::Dict{UInt16, UInt32}
end

"""
Configuration for the optional bridge role.
"""
mutable struct BridgeConfig
    instance_id::String
    aeron_dir::String
    payload_channel::String
    payload_stream_id::Int32
    control_channel::String
    control_stream_id::Int32
    mtu_bytes::UInt32
    chunk_bytes::UInt32
    max_chunk_bytes::UInt32
    max_payload_bytes::UInt32
    forward_metadata::Bool
    forward_qos::Bool
    assembly_timeout_ns::UInt64
end

"""
Assembly state for a single in-flight frame.
"""
mutable struct BridgeAssembly
    seq::UInt64
    epoch::UInt64
    chunk_count::UInt32
    payload_length::UInt32
    received_chunks::UInt32
    header_present::Bool
    header_bytes::Vector{UInt8}
    payload::Vector{UInt8}
    received::Vector{Bool}
    last_update_ns::UInt64
end

"""
Assembled bridge frame data.
"""
struct BridgeAssembledFrame
    seq::UInt64
    epoch::UInt64
    payload_length::UInt32
    header_bytes::Vector{UInt8}
    payload::Vector{UInt8}
end

"""
Bridge sender runtime state for publishing BridgeFrameChunk messages.
"""
mutable struct BridgeSenderState
    consumer_state::ConsumerState
    config::BridgeConfig
    mapping::BridgeMapping
    ctx::Aeron.Context
    client::Aeron.Client
    pub_payload::Aeron.Publication
    pub_control::Aeron.Publication
    chunk_encoder::BridgeFrameChunk.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    chunk_claim::Aeron.BufferClaim
    announce_encoder::ShmPoolAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    control_claim::Aeron.BufferClaim
    header_decoder::TensorSlotHeader256.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    header_buf::Vector{UInt8}
    scratch_dims::Vector{Int32}
    scratch_strides::Vector{Int32}
    last_announce_epoch::UInt64
end

"""
Bridge receiver runtime state for assembling BridgeFrameChunk payloads.
"""
mutable struct BridgeReceiverState
    config::BridgeConfig
    mapping::BridgeMapping
    ctx::Aeron.Context
    client::Aeron.Client
    clock::Clocks.AbstractClock
    now_ns::UInt64
    sub_payload::Aeron.Subscription
    payload_assembler::Aeron.FragmentAssembler
    sub_control::Aeron.Subscription
    control_assembler::Aeron.FragmentAssembler
    chunk_decoder::BridgeFrameChunk.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    header_decoder::TensorSlotHeader256.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    source_info::BridgeSourceInfo
    assembly::BridgeAssembly
    have_announce::Bool
end
