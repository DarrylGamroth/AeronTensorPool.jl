struct ProducerAnnounceHandler end
struct ProducerQosHandler end

"""
Mutable producer runtime state including Aeron resources and SHM mappings.
"""
mutable struct ProducerState
    config::ProducerConfig
    clock::Clocks.AbstractClock
    ctx::Aeron.Context
    client::Aeron.Client
    pub_descriptor::Aeron.Publication
    pub_control::Aeron.Publication
    pub_qos::Aeron.Publication
    pub_metadata::Aeron.Publication
    sub_control::Aeron.Subscription
    header_mmap::Vector{UInt8}
    payload_mmaps::Dict{UInt16, Vector{UInt8}}
    epoch::UInt64
    seq::UInt64
    supports_progress::Bool
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
    last_progress_ns::UInt64
    last_progress_bytes::UInt64
    announce_count::UInt64
    qos_count::UInt64
    timer_set::TimerSet{Tuple{PolledTimer, PolledTimer}, Tuple{ProducerAnnounceHandler, ProducerQosHandler}}
    descriptor_buf::Vector{UInt8}
    progress_buf::Vector{UInt8}
    announce_buf::Vector{UInt8}
    qos_buf::Vector{UInt8}
    superblock_encoder::ShmRegionSuperblock.Encoder{Vector{UInt8}}
    header_encoder::TensorSlotHeader256.Encoder{Vector{UInt8}}
    descriptor_encoder::FrameDescriptor.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    progress_encoder::FrameProgress.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_encoder::ShmPoolAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_encoder::QosProducer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    descriptor_claim::Aeron.BufferClaim
    progress_claim::Aeron.BufferClaim
    qos_claim::Aeron.BufferClaim
    hello_decoder::ConsumerHello.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end
