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
Inclusive stream ID range for bridge allocation.
"""
struct BridgeStreamIdRange
    start_id::UInt32
    end_id::UInt32
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
    assembly_timeout_ns::UInt64
    forward_metadata::Bool
    forward_qos::Bool
    forward_progress::Bool
    forward_tracelink::Bool
    dest_stream_id_range::Union{BridgeStreamIdRange, Nothing}
end

BridgeConfig(
    instance_id::String,
    aeron_dir::String,
    payload_channel::String,
    payload_stream_id::Int32,
    control_channel::String,
    control_stream_id::Int32,
    metadata_channel::String,
    metadata_stream_id::Int32,
    source_metadata_stream_id::Int32,
    mtu_bytes::UInt32,
    chunk_bytes::UInt32,
    max_chunk_bytes::UInt32,
    max_payload_bytes::UInt32,
    assembly_timeout_ns::UInt64,
    forward_metadata::Bool,
    forward_qos::Bool,
    forward_progress::Bool,
    forward_tracelink::Bool,
) = BridgeConfig(
    instance_id,
    aeron_dir,
    payload_channel,
    payload_stream_id,
    control_channel,
    control_stream_id,
    metadata_channel,
    metadata_stream_id,
    source_metadata_stream_id,
    mtu_bytes,
    chunk_bytes,
    max_chunk_bytes,
    max_payload_bytes,
    assembly_timeout_ns,
    forward_metadata,
    forward_qos,
    forward_progress,
    forward_tracelink,
    nothing,
)
