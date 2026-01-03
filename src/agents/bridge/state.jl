"""
Per-stream mapping for the bridge.
"""
struct BridgeMapping
    source_stream_id::UInt32
    dest_stream_id::UInt32
    profile::String
    metadata_stream_id::UInt32
    source_control_stream_id::Int32
    dest_control_stream_id::Int32
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
    metadata_channel::String
    metadata_stream_id::Int32
    source_metadata_stream_id::Int32
    mtu_bytes::UInt32
    chunk_bytes::UInt32
    max_chunk_bytes::UInt32
    max_payload_bytes::UInt32
    forward_metadata::Bool
    forward_qos::Bool
    forward_progress::Bool
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
    header_bytes::FixedSizeVectorDefault{UInt8}
    payload::FixedSizeVectorDefault{UInt8}
    received::FixedSizeVectorDefault{Bool}
    last_update_ns::UInt64
end

"""
Assembled bridge frame data.
"""
struct BridgeAssembledFrame
    seq::UInt64
    epoch::UInt64
    payload_length::UInt32
    header_bytes::FixedSizeVectorDefault{UInt8}
    payload::FixedSizeVectorDefault{UInt8}
end

"""
Bridge sender runtime state for publishing BridgeFrameChunk messages.
"""
mutable struct BridgeSenderState
    consumer_state::ConsumerState
    config::BridgeConfig
    mapping::BridgeMapping
    client::Aeron.Client
    pub_payload::Aeron.Publication
    pub_control::Aeron.Publication
    pub_metadata::Union{Nothing, Aeron.Publication}
    chunk_encoder::BridgeFrameChunk.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    chunk_claim::Aeron.BufferClaim
    announce_encoder::ShmPoolAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    control_claim::Aeron.BufferClaim
    metadata_claim::Aeron.BufferClaim
    metadata_announce_encoder::DataSourceAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_encoder::DataSourceMeta.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    header_decoder::TensorSlotHeader256.Decoder{Vector{UInt8}}
    header_buf::FixedSizeVectorDefault{UInt8}
    scratch_dims::FixedSizeVectorDefault{Int32}
    scratch_strides::FixedSizeVectorDefault{Int32}
    last_announce_epoch::UInt64
    sub_control::Aeron.Subscription
    control_assembler::Aeron.FragmentAssembler
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    sub_metadata::Union{Nothing, Aeron.Subscription}
    metadata_assembler::Union{Nothing, Aeron.FragmentAssembler}
    metadata_announce_decoder::DataSourceAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_decoder::DataSourceMeta.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_producer_decoder::QosProducer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_consumer_decoder::QosConsumer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_producer_encoder::QosProducer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_consumer_encoder::QosConsumer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    progress_decoder::FrameProgress.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    progress_encoder::FrameProgress.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

"""
Bridge receiver runtime state for assembling BridgeFrameChunk payloads.
"""
mutable struct BridgeReceiverState{ClockT <: Clocks.AbstractClock}
    config::BridgeConfig
    mapping::BridgeMapping
    client::Aeron.Client
    clock::ClockT
    now_ns::UInt64
    have_announce::Bool
    producer_state::Union{Nothing, ProducerState}
    source_info::BridgeSourceInfo
    assembly::BridgeAssembly
    sub_payload::Aeron.Subscription
    payload_assembler::Aeron.FragmentAssembler
    sub_control::Aeron.Subscription
    control_assembler::Aeron.FragmentAssembler
    sub_metadata::Union{Nothing, Aeron.Subscription}
    metadata_assembler::Union{Nothing, Aeron.FragmentAssembler}
    pub_metadata_local::Union{Nothing, Aeron.Publication}
    metadata_claim::Aeron.BufferClaim
    metadata_announce_encoder::DataSourceAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_encoder::DataSourceMeta.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_announce_decoder::DataSourceAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_decoder::DataSourceMeta.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    pub_control_local::Union{Nothing, Aeron.Publication}
    control_claim::Aeron.BufferClaim
    qos_producer_encoder::QosProducer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_consumer_encoder::QosConsumer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_producer_decoder::QosProducer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_consumer_decoder::QosConsumer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    progress_encoder::FrameProgress.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    progress_decoder::FrameProgress.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    chunk_decoder::BridgeFrameChunk.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    header_decoder::TensorSlotHeader256.Decoder{FixedSizeVectorDefault{UInt8}}
    scratch_dims::FixedSizeVectorDefault{Int32}
    scratch_strides::FixedSizeVectorDefault{Int32}
end
