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
Select the smallest payload pool that can accommodate values_len.

Arguments:
- `pools`: payload pool configurations.
- `values_len`: required payload length in bytes.

Returns:
- 1-based index of the best-fit pool, or 0 if no pool fits.
"""
@inline function select_pool(pools::AbstractVector{PayloadPoolConfig}, values_len::Integer)::Int
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
