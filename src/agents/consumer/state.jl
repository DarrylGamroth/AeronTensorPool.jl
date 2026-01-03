struct ConsumerHelloHandler end
struct ConsumerQosHandler end

"""
Decoded frame header and payload view.
"""
mutable struct ConsumerFrameView
    header::TensorSlotHeader
    payload::PayloadView
end

"""
Mutable consumer runtime resources (Aeron publications/subscriptions and codecs).
"""
mutable struct ConsumerRuntime
    control::ControlPlaneRuntime
    pub_qos::Aeron.Publication
    sub_descriptor::Aeron.Subscription
    sub_qos::Aeron.Subscription
    sub_progress::Union{Aeron.Subscription, Nothing}
    hello_buf::FixedSizeVectorDefault{UInt8}
    qos_buf::FixedSizeVectorDefault{UInt8}
    hello_encoder::ConsumerHello.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_encoder::QosConsumer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    hello_claim::Aeron.BufferClaim
    qos_claim::Aeron.BufferClaim
    desc_decoder::FrameDescriptor.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    config_decoder::ConsumerConfigMsg.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    progress_decoder::FrameProgress.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    header_decoder::TensorSlotHeader256.Decoder{Vector{UInt8}}
    superblock_decoder::ShmRegionSuperblock.Decoder{Vector{UInt8}}
    scratch_dims::FixedSizeVectorDefault{Int64}
    scratch_strides::FixedSizeVectorDefault{Int64}
    frame_view::ConsumerFrameView
end

"""
Mutable consumer SHM mappings.
"""
mutable struct ConsumerMappings
    mapped_epoch::UInt64
    header_mmap::Union{Nothing, Vector{UInt8}}
    payload_mmaps::Dict{UInt16, Vector{UInt8}}
    pool_stride_bytes::Dict{UInt16, UInt32}
    mapped_nslots::UInt32
    mapped_pid::UInt64
    last_commit_words::Vector{UInt64}
end

"""
Mutable consumer counters and QoS metrics.
"""
mutable struct ConsumerMetrics
    last_seq_seen::UInt64
    frames_ok::UInt64
    drops_gap::UInt64
    drops_late::UInt64
    drops_odd::UInt64
    drops_changed::UInt64
    drops_frame_id_mismatch::UInt64
    drops_header_invalid::UInt64
    drops_payload_invalid::UInt64
    remap_count::UInt64
    hello_count::UInt64
    qos_count::UInt64
    seen_any::Bool
end

"""
Mutable consumer runtime state including SHM mappings and QoS counters.
"""
mutable struct ConsumerState{ClockT<:Clocks.AbstractClock}
    config::ConsumerSettings
    clock::ClockT
    announce_join_ns::UInt64
    runtime::ConsumerRuntime
    mappings::ConsumerMappings
    metrics::ConsumerMetrics
    driver_client::Union{DriverClientState, Nothing}
    pending_attach_id::Int64
    timer_set::TimerSet{Tuple{PolledTimer, PolledTimer}, Tuple{ConsumerHelloHandler, ConsumerQosHandler}}
    assigned_descriptor_channel::String
    assigned_descriptor_stream_id::UInt32
    assigned_control_channel::String
    assigned_control_stream_id::UInt32
    progress_assembler::Aeron.FragmentAssembler
    driver_active::Bool
end
