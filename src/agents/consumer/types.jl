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
    announce_freshness_ns::UInt64
    requested_descriptor_channel::String
    requested_descriptor_stream_id::UInt32
    requested_control_channel::String
    requested_control_stream_id::UInt32
    mlock_shm::Bool
end

"""
Reference to a payload region in shared memory.
"""
mutable struct PayloadView
    mmap::Vector{UInt8}
    offset::Int
    len::Int
end

"""
Return a view over the payload bytes for a PayloadView.

Arguments:
- `payload`: payload view descriptor.

Returns:
- `SubArray` view into the payload bytes.
"""
function payload_view(payload::PayloadView)
    return view(payload.mmap, payload.offset + 1: payload.offset + payload.len)
end
