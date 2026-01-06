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
Assembly state for a single in-flight frame.
"""
mutable struct BridgeAssembly
    seq::UInt64
    epoch::UInt64
    chunk_count::UInt32
    payload_length::UInt32
    received_chunks::UInt32
    header_bytes::FixedSizeVectorDefault{UInt8}
    payload::FixedSizeVectorDefault{UInt8}
    received::FixedSizeVectorDefault{Bool}
    assembly_timer::PolledTimer
    header_present::Bool
end

"""
Bridge sender metrics.
"""
mutable struct BridgeSenderMetrics
    frames_forwarded::UInt64
    chunks_sent::UInt64
    chunks_dropped::UInt64
    control_forwarded::UInt64
end

"""
Bridge receiver metrics.
"""
mutable struct BridgeReceiverMetrics
    frames_rematerialized::UInt64
    assemblies_reset::UInt64
    chunks_dropped::UInt64
    control_forwarded::UInt64
end

"""
Reusable fill handler for BridgeFrameChunk encoding.
"""
mutable struct BridgeChunkFill
    encoder::BridgeFrameChunk.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    dest_stream_id::UInt32
    epoch::UInt64
    seq::UInt64
    chunk_index::UInt32
    chunk_count::UInt32
    chunk_offset::UInt32
    chunk_length::UInt32
    payload_length::UInt32
    header_included::Bool
    header_mmap_vec::Vector{UInt8}
    header_offset::Int
    payload_mmap_vec::Vector{UInt8}
    payload_pos::Int
    payload_chunk_len::Int
end

"""
Call overload for `BridgeChunkFill`.
"""
@inline function (fill::BridgeChunkFill)(buf::AbstractArray{UInt8})
    BridgeFrameChunk.wrap_and_apply_header!(fill.encoder, buf, 0)
    BridgeFrameChunk.streamId!(fill.encoder, fill.dest_stream_id)
    BridgeFrameChunk.epoch!(fill.encoder, fill.epoch)
    BridgeFrameChunk.seq!(fill.encoder, fill.seq)
    BridgeFrameChunk.chunkIndex!(fill.encoder, fill.chunk_index)
    BridgeFrameChunk.chunkCount!(fill.encoder, fill.chunk_count)
    BridgeFrameChunk.chunkOffset!(fill.encoder, fill.chunk_offset)
    BridgeFrameChunk.chunkLength!(fill.encoder, fill.chunk_length)
    BridgeFrameChunk.payloadLength!(fill.encoder, fill.payload_length)
    BridgeFrameChunk.headerIncluded!(
        fill.encoder,
        fill.header_included ? BridgeBool.TRUE : BridgeBool.FALSE,
    )
    if fill.header_included
        BridgeFrameChunk.headerBytes_length!(fill.encoder, HEADER_SLOT_BYTES)
        header_pos = BridgeFrameChunk.sbe_position(fill.encoder) + 4
        BridgeFrameChunk.sbe_position!(fill.encoder, header_pos + HEADER_SLOT_BYTES)
        dest_ptr = pointer(BridgeFrameChunk.sbe_buffer(fill.encoder), header_pos + 1)
        unsafe_copyto!(
            dest_ptr,
            pointer(fill.header_mmap_vec, fill.header_offset + 1),
            HEADER_SLOT_BYTES,
        )
    else
        BridgeFrameChunk.headerBytes_length!(fill.encoder, 0)
        header_pos = BridgeFrameChunk.sbe_position(fill.encoder) + 4
        BridgeFrameChunk.sbe_position!(fill.encoder, header_pos)
    end
    BridgeFrameChunk.payloadBytes_length!(fill.encoder, fill.payload_chunk_len)
    payload_pos_enc = BridgeFrameChunk.sbe_position(fill.encoder) + 4
    BridgeFrameChunk.sbe_position!(fill.encoder, payload_pos_enc + fill.payload_chunk_len)
    dest_ptr = pointer(BridgeFrameChunk.sbe_buffer(fill.encoder), payload_pos_enc + 1)
    unsafe_copyto!(
        dest_ptr,
        pointer(fill.payload_mmap_vec, fill.payload_pos + 1),
        fill.payload_chunk_len,
    )
    return nothing
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
    metrics::BridgeSenderMetrics
    client::Aeron.Client
    pub_payload::Aeron.Publication
    pub_control::Aeron.Publication
    pub_metadata::Union{Nothing, Aeron.Publication}
    chunk_encoder::BridgeFrameChunk.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    chunk_claim::Aeron.BufferClaim
    chunk_fill::BridgeChunkFill
    announce_encoder::ShmPoolAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    control_claim::Aeron.BufferClaim
    metadata_claim::Aeron.BufferClaim
    metadata_announce_encoder::DataSourceAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_encoder::DataSourceMeta.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    header_decoder::TensorSlotHeaderMsg.Decoder{Vector{UInt8}}
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
mutable struct BridgeReceiverState{ClockT}
    config::BridgeConfig
    mapping::BridgeMapping
    client::Aeron.Client
    clock::ClockT
    metrics::BridgeReceiverMetrics
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
    header_decoder::TensorSlotHeaderMsg.Decoder{FixedSizeVectorDefault{UInt8}}
    scratch_dims::FixedSizeVectorDefault{Int32}
    scratch_strides::FixedSizeVectorDefault{Int32}
    have_announce::Bool
end
