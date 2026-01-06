"""
Return the byte offset for a header slot index.

Arguments:
- `index`: 0-based header slot index.

Returns:
- Byte offset from the start of the header mmap.
"""
@inline function header_slot_offset(index::Integer)
    return SUPERBLOCK_SIZE + Int(index) * HEADER_SLOT_BYTES
end

"""
Decoded slot header fields for consumer-side validation.
"""
struct TensorSlotHeader
    seq_commit::UInt64
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
Return the byte offset for a payload slot index in a pool.

Arguments:
- `stride_bytes`: pool stride size in bytes.
- `slot`: 0-based payload slot index.

Returns:
- Byte offset from the start of the payload mmap.
"""
@inline function payload_slot_offset(stride_bytes::Integer, slot::Integer)
    return SUPERBLOCK_SIZE + Int(slot) * Int(stride_bytes)
end

"""
Return a view into a payload slot region.

Arguments:
- `buffer`: payload mmap buffer.
- `stride_bytes`: pool stride size in bytes.
- `slot`: 0-based payload slot index.
- `len`: view length in bytes (defaults to `stride_bytes`).

Returns:
- `SubArray` view into the payload buffer.
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

Arguments:
- `buffer`: payload mmap buffer.
- `stride_bytes`: pool stride size in bytes.
- `slot`: 0-based payload slot index.

Returns:
- Tuple `(Ptr{UInt8}, Int)` where the pointer is the start of the slot.
"""
@inline function payload_slot_ptr(buffer::AbstractVector{UInt8}, stride_bytes::Integer, slot::Integer)
    offset = payload_slot_offset(stride_bytes, slot)
    return Ptr{UInt8}(pointer(buffer, offset + 1)), Int(stride_bytes)
end

"""
Validate stride_bytes against alignment and hugepage requirements.

Arguments:
- `stride_bytes`: pool stride size in bytes.
- `require_hugepages`: whether hugepages are required.
- `page_size_bytes`: OS page size in bytes (default: backend value).
- `hugepage_size`: hugepage size in bytes (default: 0 means unknown).

Returns:
- `true` if valid, `false` otherwise.
"""
function validate_stride(
    stride_bytes::UInt32;
    require_hugepages::Bool,
    page_size_bytes::Int = page_size_bytes(),
    hugepage_size::Int = 0,
)
    ispow2(stride_bytes) || return false
    (stride_bytes % UInt32(page_size_bytes)) == 0 || return false
    if require_hugepages
        hugepage_size > 0 || return false
        (stride_bytes % UInt32(hugepage_size)) == 0 || return false
    end
    return true
end
