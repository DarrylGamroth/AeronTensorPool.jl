"""
Supervisor tracking info for a producer.
"""
struct ProducerInfo
    stream_id::UInt32
    epoch::UInt64
    last_announce_ns::UInt64
    last_qos_ns::UInt64
    current_seq::UInt64
end

"""
Supervisor tracking info for a consumer.
"""
struct ConsumerInfo
    stream_id::UInt32
    consumer_id::UInt32
    epoch::UInt64
    mode::Mode.SbeEnum
    last_hello_ns::UInt64
    last_qos_ns::UInt64
    last_seq_seen::UInt64
    drops_gap::UInt64
    drops_late::UInt64
end

"""
Static configuration for the supervisor role.
"""
mutable struct SupervisorConfig
    aeron_dir::String
    aeron_uri::String
    control_stream_id::Int32
    qos_stream_id::Int32
    stream_id::UInt32
    liveness_timeout_ns::UInt64
    liveness_check_interval_ns::UInt64
end

struct SupervisorLivenessHandler end

"""
Mutable supervisor runtime resources (Aeron publications/subscriptions and codecs).
"""
mutable struct SupervisorRuntime
    ctx::Aeron.Context
    client::Aeron.Client
    owns_ctx::Bool
    owns_client::Bool
    pub_control::Aeron.Publication
    sub_control::Aeron.Subscription
    sub_qos::Aeron.Subscription
    config_buf::Vector{UInt8}
    config_encoder::ConsumerConfigMsg.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    config_claim::Aeron.BufferClaim
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    hello_decoder::ConsumerHello.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_producer_decoder::QosProducer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_consumer_decoder::QosConsumer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

"""
Mutable supervisor tracking state and counters.
"""
mutable struct SupervisorTracking
    producers::Dict{UInt32, ProducerInfo}
    consumers::Dict{UInt32, ConsumerInfo}
    config_count::UInt64
    liveness_count::UInt64
end

"""
Mutable supervisor runtime state including liveness tracking.
"""
mutable struct SupervisorState{ClockT<:Clocks.AbstractClock}
    config::SupervisorConfig
    clock::ClockT
    runtime::SupervisorRuntime
    tracking::SupervisorTracking
    timer_set::TimerSet{Tuple{PolledTimer}, Tuple{SupervisorLivenessHandler}}
end
