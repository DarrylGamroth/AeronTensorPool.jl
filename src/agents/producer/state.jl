struct ProducerAnnounceHandler end
struct ProducerQosHandler end
struct ProducerBackoffHandler end

"""
Mutable producer runtime resources (Aeron publications/subscriptions and codecs).
"""
mutable struct ProducerRuntime
    control::ControlPlaneRuntime
    pub_descriptor::Aeron.Publication
    pub_qos::Aeron.Publication
    pub_metadata::Aeron.Publication
    sub_qos::Aeron.Subscription
    descriptor_buf::FixedSizeVectorDefault{UInt8}
    progress_buf::FixedSizeVectorDefault{UInt8}
    announce_buf::FixedSizeVectorDefault{UInt8}
    qos_buf::FixedSizeVectorDefault{UInt8}
    superblock_encoder::ShmRegionSuperblock.Encoder{Vector{UInt8}}
    slot_encoder::SlotHeaderMsg.Encoder{Vector{UInt8}}
    tensor_encoder::TensorHeaderMsg.Encoder{Vector{UInt8}}
    descriptor_encoder::FrameDescriptor.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    progress_encoder::FrameProgress.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_encoder::ShmPoolAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_encoder::QosProducer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    config_encoder::ConsumerConfigMsg.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_announce_encoder::DataSourceAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_encoder::DataSourceMeta.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    descriptor_claim::Aeron.BufferClaim
    progress_claim::Aeron.BufferClaim
    qos_claim::Aeron.BufferClaim
    config_claim::Aeron.BufferClaim
    metadata_claim::Aeron.BufferClaim
    hello_decoder::ConsumerHello.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_decoder::QosConsumer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    config_decoder::ConsumerConfigMsg.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
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
    last_progress_bytes::UInt64
    announce_count::UInt64
    qos_count::UInt64
    descriptor_backpressured::UInt64
    descriptor_not_connected::UInt64
    descriptor_admin_action::UInt64
    descriptor_closed::UInt64
    descriptor_max_position_exceeded::UInt64
    descriptor_error::UInt64
    descriptor_last_log_ns::UInt64
end

"""
Per-consumer descriptor/control stream assignments.
"""
mutable struct ProducerConsumerStream
    descriptor_pub::Union{Aeron.Publication, Nothing}
    control_pub::Union{Aeron.Publication, Nothing}
    descriptor_channel::String
    control_channel::String
    descriptor_stream_id::UInt32
    control_stream_id::UInt32
    max_rate_hz::UInt16
    descriptor_timer::PolledTimer
    timeout_timer::PolledTimer
    last_hello_ns::UInt64
    last_qos_ns::UInt64
end

"""
Mutable producer runtime state including Aeron resources and SHM mappings.
"""
mutable struct ProducerState{ClockT}
    config::ProducerConfig
    clock::ClockT
    runtime::ProducerRuntime
    mappings::ProducerMappings
    metrics::ProducerMetrics
    epoch::UInt64
    seq::UInt64
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
    progress_major_delta_units::UInt64
    progress_major_stride_bytes::UInt64
    progress_timer::PolledTimer
    driver_client::Union{DriverClientState, Nothing}
    driver_lifecycle::ProducerDriverLifecycle
    pending_attach_id::Int64
    attach_event_now_ns::UInt64
    attach_event_stream_id::UInt32
    backoff_timer::PolledTimer
    timer_set::TimerSet{
        Tuple{PolledTimer, PolledTimer, PolledTimer},
        Tuple{ProducerAnnounceHandler, ProducerQosHandler, ProducerBackoffHandler},
    }
    consumer_streams::Dict{UInt32, ProducerConsumerStream}
    supports_progress::Bool
    emit_announce::Bool
    metadata_version::UInt32
    metadata_name::String
    metadata_summary::String
    metadata_attrs::Vector{MetadataAttribute}
    metadata_dirty::Bool
end
