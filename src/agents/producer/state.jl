struct ProducerAnnounceHandler end
struct ProducerQosHandler end

"""
Mutable producer runtime resources (Aeron publications/subscriptions and codecs).
"""
mutable struct ProducerRuntime
    control::ControlPlaneRuntime
    pub_descriptor::Aeron.Publication
    pub_qos::Aeron.Publication
    pub_metadata::Aeron.Publication
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

"""
Mutable producer SHM mappings.
"""
mutable struct ProducerMappings
    header_mmap::Vector{UInt8}
    payload_mmaps::Dict{UInt16, Vector{UInt8}}
end

"""
Mutable producer counters and progress tracking.
"""
mutable struct ProducerMetrics
    last_progress_ns::UInt64
    last_progress_bytes::UInt64
    announce_count::UInt64
    qos_count::UInt64
end

"""
Mutable producer runtime state including Aeron resources and SHM mappings.
"""
mutable struct ProducerState{ClockT<:Clocks.AbstractClock}
    config::ProducerConfig
    clock::ClockT
    runtime::ProducerRuntime
    mappings::ProducerMappings
    metrics::ProducerMetrics
    epoch::UInt64
    seq::UInt64
    driver_active::Bool
    supports_progress::Bool
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
    emit_announce::Bool
    driver_client::Union{DriverClientState, Nothing}
    pending_attach_id::Int64
    timer_set::TimerSet{Tuple{PolledTimer, PolledTimer}, Tuple{ProducerAnnounceHandler, ProducerQosHandler}}
end
