"""
Return byte offset for a header slot index.
"""
@inline function header_slot_offset(index::Integer)
    return SUPERBLOCK_SIZE + Int(index) * HEADER_SLOT_BYTES
end

"""
Decoded slot header fields for consumer-side validation.
"""
struct TensorSlotHeader
    commit_word::UInt64
    frame_id::UInt64
    timestamp_ns::UInt64
    meta_version::UInt32
    values_len_bytes::UInt32
    payload_slot::UInt32
    payload_offset::UInt32
    pool_id::UInt16
    dtype::Dtype.SbeEnum
    major_order::MajorOrder.SbeEnum
    ndims::UInt8
    pad_align::UInt8
    dims::NTuple{MAX_DIMS, Int32}
    strides::NTuple{MAX_DIMS, Int32}
end

"""
Return byte offset for a payload slot index in a pool.
"""
@inline function payload_slot_offset(stride_bytes::Integer, slot::Integer)
    return SUPERBLOCK_SIZE + Int(slot) * Int(stride_bytes)
end

"""
Return a view into a payload slot region.
"""
@inline function payload_slot_view(
    buffer::AbstractVector{UInt8},
    stride_bytes::Integer,
    slot::Integer,
    len::Integer = stride_bytes,
)
    len <= stride_bytes || throw(ArgumentError("len exceeds stride_bytes"))
    offset = payload_slot_offset(stride_bytes, slot)
    return view(buffer, offset + 1:offset + Int(len))
end

"""
Return a pointer and stride_bytes for a payload slot.
"""
@inline function payload_slot_ptr(buffer::AbstractVector{UInt8}, stride_bytes::Integer, slot::Integer)
    offset = payload_slot_offset(stride_bytes, slot)
    return Ptr{UInt8}(pointer(buffer, offset + 1)), Int(stride_bytes)
end

"""
Pick the smallest payload pool that can fit values_len.
Returns a 1-based index or 0 if no pool fits.
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
