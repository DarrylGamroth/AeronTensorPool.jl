"""
Configuration for a payload pool in shared memory.
"""
struct PayloadPoolConfig
    pool_id::UInt16
    uri::String
    stride_bytes::UInt32
    nslots::UInt32
end

"""
Static configuration for the producer role.
"""
struct ProducerConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    control_stream_id::Int32
    qos_stream_id::Int32
    metadata_stream_id::Int32
    stream_id::UInt32
    producer_id::UInt32
    layout_version::UInt32
    nslots::UInt32
    shm_base_dir::String
    shm_namespace::String
    producer_instance_id::String
    header_uri::String
    payload_pools::Vector{PayloadPoolConfig}
    max_dims::UInt8
    announce_interval_ns::UInt64
    qos_interval_ns::UInt64
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
    mlock_shm::Bool
end

"""
Mutable consumer configuration (can be updated by ConsumerConfig messages).
"""
mutable struct ConsumerSettings
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
Claim handle for a payload slot that will be filled externally.
"""
struct SlotClaim
    seq::UInt64
    ptr::Ptr{UInt8}
    stride_bytes::Int
    header_index::UInt32
    payload_slot::UInt32
    pool_id::UInt16
end

"""
Discovery service configuration.
"""
struct DiscoveryConfig
    channel::String
    stream_id::Int32
    announce_channel::String
    announce_stream_id::Int32
    metadata_channel::String
    metadata_stream_id::Int32
    driver_instance_id::String
    driver_control_channel::String
    driver_control_stream_id::UInt32
    max_results::UInt32
    expiry_ns::UInt64
    response_buf_bytes::UInt32
    max_tags_per_entry::UInt16
    max_pools_per_entry::UInt16
end

"""
Discovery registry endpoint configuration.
"""
struct DiscoveryRegistryEndpoint
    driver_instance_id::String
    announce_channel::String
    announce_stream_id::Int32
    metadata_channel::String
    metadata_stream_id::Int32
    driver_control_channel::String
    driver_control_stream_id::UInt32
end

"""
Discovery registry configuration.
"""
struct DiscoveryRegistryConfig
    channel::String
    stream_id::Int32
    endpoints::Vector{DiscoveryRegistryEndpoint}
    max_results::UInt32
    expiry_ns::UInt64
    response_buf_bytes::UInt32
    max_tags_per_entry::UInt16
    max_pools_per_entry::UInt16
end

"""
Discovery service payload pool entry.
"""
mutable struct DiscoveryPoolEntry
    pool_id::UInt16
    pool_nslots::UInt32
    stride_bytes::UInt32
    region_uri::FixedString
end

"""
Discovery service stream entry.
"""
mutable struct DiscoveryEntry
    driver_instance_id::FixedString
    driver_control_channel::FixedString
    driver_control_stream_id::UInt32
    stream_id::UInt32
    producer_id::UInt32
    epoch::UInt64
    layout_version::UInt32
    header_region_uri::FixedString
    header_nslots::UInt32
    header_slot_bytes::UInt16
    max_dims::UInt8
    data_source_id::UInt64
    data_source_name::FixedString
    tags::Vector{FixedString}
    pools::Vector{DiscoveryPoolEntry}
    expiry_timer::PolledTimer
    last_announce_ns::UInt64
end

"""
View of a discovery entry with StringView fields.
"""
struct DiscoveryResultView
    driver_instance_id::StringView
    driver_control_channel::StringView
    header_region_uri::StringView
    data_source_name::StringView
end

@inline function discovery_result_view(entry::DiscoveryEntry)
    return DiscoveryResultView(
        view(entry.driver_instance_id),
        view(entry.driver_control_channel),
        view(entry.header_region_uri),
        view(entry.data_source_name),
    )
end

"""
Return a view over the payload bytes for a PayloadView.

Arguments:
- `payload`: payload view descriptor.

Returns:
- `SubArray` view into the payload bytes.
"""
@inline function payload_view(payload::PayloadView)
    return view(payload.mmap, payload.offset + 1: payload.offset + payload.len)
end
