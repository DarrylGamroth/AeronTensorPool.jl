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
    progress_major_delta_units::UInt32
    mlock_shm::Bool
end

function ProducerConfig(
    aeron_dir::AbstractString,
    aeron_uri::AbstractString,
    descriptor_stream_id::Int32,
    control_stream_id::Int32,
    qos_stream_id::Int32,
    metadata_stream_id::Int32,
    stream_id::UInt32,
    producer_id::UInt32,
    layout_version::UInt32,
    nslots::UInt32,
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    producer_instance_id::AbstractString,
    header_uri::AbstractString,
    payload_pools::AbstractVector{PayloadPoolConfig},
    max_dims::UInt8,
    announce_interval_ns::UInt64,
    qos_interval_ns::UInt64,
    progress_interval_ns::UInt64,
    progress_bytes_delta::UInt64,
    mlock_shm::Bool,
)
    return ProducerConfig(
        String(aeron_dir),
        String(aeron_uri),
        descriptor_stream_id,
        control_stream_id,
        qos_stream_id,
        metadata_stream_id,
        stream_id,
        producer_id,
        layout_version,
        nslots,
        String(shm_base_dir),
        String(shm_namespace),
        String(producer_instance_id),
        String(header_uri),
        Vector{PayloadPoolConfig}(payload_pools),
        max_dims,
        announce_interval_ns,
        qos_interval_ns,
        progress_interval_ns,
        progress_bytes_delta,
        UInt32(0),
        mlock_shm,
    )
end

"""
Claim handle for a payload slot that will be filled externally.

The `ptr` is only valid while the owning producer state and its SHM mappings
remain alive; do not retain a `SlotClaim` beyond the lifecycle of its producer.
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
Select the smallest payload pool that can accommodate values_len.

Arguments:
- `pools`: payload pool configurations.
- `values_len`: required payload length in bytes.

Returns:
- 1-based index of the best-fit pool, or 0 if no pool fits.
"""
function select_pool(pools::AbstractVector{PayloadPoolConfig}, values_len::Integer)::Int
    best_idx = 0
    best_stride = typemax(UInt32)
    for (i, pool) in pairs(pools)
        stride = pool.stride_bytes
        if stride >= values_len && stride < best_stride
            best_idx = i
            best_stride = stride
        end
    end
    return best_idx
end
