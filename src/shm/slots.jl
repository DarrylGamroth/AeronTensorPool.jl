"""
Return the byte offset for a header slot index.

Arguments:
- `index`: 0-based header slot index.

Returns:
- Byte offset from the start of the header mmap.
"""
header_slot_offset(index::Integer) = SUPERBLOCK_SIZE + Int(index) * HEADER_SLOT_BYTES

"""
Decoded tensor header fields for consumer-side validation.
"""
struct TensorHeader
    dtype::Dtype.SbeEnum
    major_order::MajorOrder.SbeEnum
    ndims::UInt8
    pad_align::UInt8
    progress_unit::ProgressUnit.SbeEnum
    progress_stride_bytes::UInt32
    dims::NTuple{MAX_DIMS, Int32}
    strides::NTuple{MAX_DIMS, Int32}
end

"""
Decoded slot header fields for consumer-side validation.
"""
struct SlotHeader
    seq_commit::UInt64
    timestamp_ns::UInt64
    meta_version::UInt32
    values_len_bytes::UInt32
    payload_slot::UInt32
    payload_offset::UInt32
    pool_id::UInt16
    tensor::TensorHeader
end

"""
Return the byte offset for a payload slot index in a pool.

Arguments:
- `stride_bytes`: pool stride size in bytes.
- `slot`: 0-based payload slot index.

Returns:
- Byte offset from the start of the payload mmap.
"""
payload_slot_offset(stride_bytes::Integer, slot::Integer) =
    SUPERBLOCK_SIZE + Int(slot) * Int(stride_bytes)

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
function payload_slot_view(
    buffer::AbstractVector{UInt8},
    stride_bytes::Integer,
    slot::Integer,
    len::Integer = stride_bytes,
)
    @boundscheck len <= stride_bytes || throw(ArgumentError("len exceeds stride_bytes"))
    offset = payload_slot_offset(stride_bytes, slot)
    return view(buffer, offset + 1:offset + Int(len))
end

"""
Try to return a view into a payload slot region.

Arguments:
- `buffer`: payload mmap buffer.
- `stride_bytes`: pool stride size in bytes.
- `slot`: 0-based payload slot index.
- `len`: view length in bytes (defaults to `stride_bytes`).

Returns:
- `SubArray` view into the payload buffer, or `nothing` if `len` exceeds `stride_bytes`.
"""
function try_payload_slot_view(
    buffer::AbstractVector{UInt8},
    stride_bytes::Integer,
    slot::Integer,
    len::Integer = stride_bytes,
)
    len <= stride_bytes || return nothing
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
function payload_slot_ptr(buffer::AbstractVector{UInt8}, stride_bytes::Integer, slot::Integer)
    offset = payload_slot_offset(stride_bytes, slot)
    return Ptr{UInt8}(pointer(buffer, offset + 1)), Int(stride_bytes)
end

ispow2_u32(x::UInt32) = (x != 0x00000000) & ((x & (x - 0x00000001)) == 0x00000000)

"""
Validate stride_bytes against the v1.2 alignment requirements.

Arguments:
- `stride_bytes`: pool stride size in bytes.
- `require_hugepages`: whether hugepages are required (not used for stride validation).
- `page_size_bytes`: OS page size in bytes (unused for stride validation).
- `hugepage_size`: hugepage size in bytes (unused for stride validation).

Returns:
- `true` if valid, `false` otherwise.
"""
function validate_stride(
    stride_bytes::UInt32;
    require_hugepages::Bool,
    page_size_bytes::Int = page_size_bytes(),
    hugepage_size::Int = 0,
)
    _ = require_hugepages
    _ = page_size_bytes
    _ = hugepage_size

    stride_bytes >= UInt32(64) || return false
    return ispow2_u32(stride_bytes) & ((stride_bytes & UInt32(0x3f)) == UInt32(0))
end
