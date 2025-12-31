"""
Mutable consumer configuration (can be updated by ConsumerConfig messages).
"""
mutable struct ConsumerConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    control_stream_id::Int32
    qos_stream_id::Int32
    stream_id::UInt32
    consumer_id::UInt32
    expected_layout_version::UInt32
    max_dims::UInt8
    mode::Mode.SbeEnum
    decimation::UInt16
    max_outstanding_seq_gap::UInt32
    use_shm::Bool
    supports_shm::Bool
    supports_progress::Bool
    max_rate_hz::UInt16
    payload_fallback_uri::String
    shm_base_dir::String
    allowed_base_dirs::Vector{String}
    require_hugepages::Bool
    progress_interval_us::UInt32
    progress_bytes_delta::UInt32
    progress_rows_delta::UInt32
    hello_interval_ns::UInt64
    qos_interval_ns::UInt64
end

struct ConsumerHelloHandler end
struct ConsumerQosHandler end

"""
Mutable consumer runtime resources (Aeron publications/subscriptions and codecs).
"""
mutable struct ConsumerRuntime
    ctx::Aeron.Context
    client::Aeron.Client
    pub_control::Aeron.Publication
    pub_qos::Aeron.Publication
    sub_descriptor::Aeron.Subscription
    sub_control::Aeron.Subscription
    sub_qos::Aeron.Subscription
    hello_buf::Vector{UInt8}
    qos_buf::Vector{UInt8}
    hello_encoder::ConsumerHello.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_encoder::QosConsumer.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    hello_claim::Aeron.BufferClaim
    qos_claim::Aeron.BufferClaim
    desc_decoder::FrameDescriptor.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    config_decoder::ConsumerConfigMsg.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    header_decoder::TensorSlotHeader256.Decoder{Vector{UInt8}}
    scratch_dims::Vector{Int64}
    scratch_strides::Vector{Int64}
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
    seen_any::Bool
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
end

"""
Mutable consumer runtime state including SHM mappings and QoS counters.
"""
mutable struct ConsumerState
    config::ConsumerConfig
    clock::Clocks.AbstractClock
    runtime::ConsumerRuntime
    mappings::ConsumerMappings
    metrics::ConsumerMetrics
    driver_client::Union{DriverClientState, Nothing}
    timer_set::TimerSet{Tuple{PolledTimer, PolledTimer}, Tuple{ConsumerHelloHandler, ConsumerQosHandler}}
end
