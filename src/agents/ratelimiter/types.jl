"""
Per-stream mapping for the rate limiter.
"""
struct RateLimiterMapping
    source_stream_id::UInt32
    dest_stream_id::UInt32
    metadata_stream_id::UInt32
    max_rate_hz::UInt32
end

"""
Configuration for the rate limiter agent.
"""
mutable struct RateLimiterConfig
    instance_id::String
    aeron_dir::String
    aeron_uri::String
    shm_base_dir::String
    driver_control_channel::String
    driver_control_stream_id::Int32
    descriptor_channel::String
    descriptor_stream_id::Int32
    control_channel::String
    control_stream_id::Int32
    qos_channel::String
    qos_stream_id::Int32
    metadata_channel::String
    metadata_stream_id::Int32
    forward_metadata::Bool
    forward_progress::Bool
    forward_qos::Bool
    max_rate_hz::UInt32
    source_control_stream_id::Int32
    dest_control_stream_id::Int32
    source_qos_stream_id::Int32
    dest_qos_stream_id::Int32
    keepalive_interval_ns::UInt64
    attach_timeout_ns::UInt64
    attach_retry_interval_ns::UInt64
end
