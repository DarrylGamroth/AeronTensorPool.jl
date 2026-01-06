"""
Decoded superblock fields for SHM validation and diagnostics.
"""
struct SuperblockFields
    magic::UInt64
    layout_version::UInt32
    epoch::UInt64
    stream_id::UInt32
    region_type::RegionType.SbeEnum
    pool_id::UInt16
    nslots::UInt32
    slot_bytes::UInt32
    stride_bytes::UInt32
    pid::UInt64
    start_timestamp_ns::UInt64
    activity_timestamp_ns::UInt64
end

"""
Wrap a superblock encoder over a buffer without an SBE message header.

Arguments:
- `m`: superblock encoder.
- `buffer`: mmap buffer.
- `offset`: byte offset within `buffer` (default: 0).

Returns:
- The wrapped encoder `m`.
"""
@inline function wrap_superblock!(m::ShmRegionSuperblock.Encoder, buffer::AbstractVector{UInt8}, offset::Integer = 0)
    @boundscheck length(buffer) >= offset + SUPERBLOCK_SIZE || throw(ArgumentError("buffer too small for superblock"))
    ShmRegionSuperblock.wrap!(m, buffer, offset)
    return m
end

"""
Wrap a superblock decoder over a buffer without an SBE message header.

Arguments:
- `m`: superblock decoder.
- `buffer`: mmap buffer.
- `offset`: byte offset within `buffer` (default: 0).

Returns:
- The wrapped decoder `m`.
"""
@inline function wrap_superblock!(m::ShmRegionSuperblock.Decoder, buffer::AbstractVector{UInt8}, offset::Integer = 0)
    @boundscheck length(buffer) >= offset + SUPERBLOCK_SIZE || throw(ArgumentError("buffer too small for superblock"))
    ShmRegionSuperblock.wrap!(
        m,
        buffer,
        offset,
        ShmRegionSuperblock.sbe_block_length(ShmRegionSuperblock.Decoder),
        ShmRegionSuperblock.sbe_schema_version(ShmRegionSuperblock.Decoder),
    )
    return m
end

"""
Wrap a tensor slot header encoder over a buffer without an SBE message header.

Arguments:
- `m`: tensor slot header encoder.
- `buffer`: header mmap buffer.
- `offset`: byte offset within `buffer`.

Returns:
- The wrapped encoder `m`.
"""
@inline function wrap_tensor_header!(m::TensorSlotHeaderMsg.Encoder, buffer::AbstractVector{UInt8}, offset::Integer)
    @boundscheck length(buffer) >= offset + HEADER_SLOT_BYTES || throw(ArgumentError("buffer too small for header slot"))
    TensorSlotHeaderMsg.wrap!(m, buffer, offset)
    return m
end

"""
Wrap a tensor slot header decoder over a buffer without an SBE message header.

Arguments:
- `m`: tensor slot header decoder.
- `buffer`: header mmap buffer.
- `offset`: byte offset within `buffer`.

Returns:
- The wrapped decoder `m`.
"""
@inline function wrap_tensor_header!(m::TensorSlotHeaderMsg.Decoder, buffer::AbstractVector{UInt8}, offset::Integer)
    @boundscheck length(buffer) >= offset + HEADER_SLOT_BYTES || throw(ArgumentError("buffer too small for header slot"))
    TensorSlotHeaderMsg.wrap!(
        m,
        buffer,
        offset,
        TensorSlotHeaderMsg.sbe_block_length(TensorSlotHeaderMsg.Decoder),
        TensorSlotHeaderMsg.sbe_schema_version(TensorSlotHeaderMsg.Decoder),
    )
    return m
end

"""
Write superblock fields into an encoder.

Arguments:
- `m`: superblock encoder.
- `fields`: decoded or constructed superblock fields.

Returns:
- `nothing`.
"""
function write_superblock!(m::ShmRegionSuperblock.Encoder, fields::SuperblockFields)
    ShmRegionSuperblock.magic!(m, fields.magic)
    ShmRegionSuperblock.layoutVersion!(m, fields.layout_version)
    ShmRegionSuperblock.epoch!(m, fields.epoch)
    ShmRegionSuperblock.streamId!(m, fields.stream_id)
    ShmRegionSuperblock.regionType!(m, fields.region_type)
    ShmRegionSuperblock.poolId!(m, fields.pool_id)
    ShmRegionSuperblock.nslots!(m, fields.nslots)
    ShmRegionSuperblock.slotBytes!(m, fields.slot_bytes)
    ShmRegionSuperblock.strideBytes!(m, fields.stride_bytes)
    ShmRegionSuperblock.pid!(m, fields.pid)
    ShmRegionSuperblock.startTimestampNs!(m, fields.start_timestamp_ns)
    ShmRegionSuperblock.activityTimestampNs!(m, fields.activity_timestamp_ns)
    return nothing
end

"""
Decode a superblock into a `SuperblockFields` struct.

Arguments:
- `m`: superblock decoder.

Returns:
- `SuperblockFields` with decoded values.
"""
function read_superblock(m::ShmRegionSuperblock.Decoder)
    return SuperblockFields(
        ShmRegionSuperblock.magic(m),
        ShmRegionSuperblock.layoutVersion(m),
        ShmRegionSuperblock.epoch(m),
        ShmRegionSuperblock.streamId(m),
        ShmRegionSuperblock.regionType(m),
        ShmRegionSuperblock.poolId(m),
        ShmRegionSuperblock.nslots(m),
        ShmRegionSuperblock.slotBytes(m),
        ShmRegionSuperblock.strideBytes(m),
        ShmRegionSuperblock.pid(m),
        ShmRegionSuperblock.startTimestampNs(m),
        ShmRegionSuperblock.activityTimestampNs(m),
    )
end

"""
Validate superblock fields against expected layout and mapping rules.

Arguments:
- `fields`: decoded superblock fields.
- `expected_layout_version`: expected layout version.
- `expected_epoch`: expected epoch.
- `expected_stream_id`: expected stream ID.
- `expected_nslots`: expected number of slots.
- `expected_slot_bytes`: expected slot size in bytes.
- `expected_region_type`: expected region type enum.
- `expected_pool_id`: expected pool ID (0 for header ring).

Returns:
- `true` if all checks pass, `false` otherwise.
"""
function validate_superblock_fields(
    fields::SuperblockFields;
    expected_layout_version::UInt32,
    expected_epoch::UInt64,
    expected_stream_id::UInt32,
    expected_nslots::UInt32,
    expected_slot_bytes::UInt32,
    expected_region_type::RegionType.SbeEnum,
    expected_pool_id::UInt16,
)
    fields.magic == MAGIC_TPOLSHM1 || return false
    fields.layout_version == expected_layout_version || return false
    fields.epoch == expected_epoch || return false
    fields.stream_id == expected_stream_id || return false
    fields.region_type == expected_region_type || return false
    fields.pool_id == expected_pool_id || return false
    fields.nslots == expected_nslots || return false
    ispow2(fields.nslots) || return false
    fields.slot_bytes == expected_slot_bytes || return false
    return true
end

"""
Write tensor slot header fields to an encoder, padding dims/strides to MAX_DIMS.

Arguments:
- `m`: tensor slot header encoder.
- `timestamp_ns`: timestamp for the frame.
- `meta_version`: metadata schema version.
- `values_len_bytes`: payload length in bytes.
- `payload_slot`: payload slot index.
- `payload_offset`: offset within payload slot (usually 0).
- `pool_id`: payload pool ID.
- `dtype`: element type enum.
- `major_order`: major order enum.
- `ndims`: number of dimensions.
- `dims`: dimension sizes (length >= `ndims`).
- `strides`: stride sizes (length >= `ndims`).

Returns:
- `nothing`.
"""
@inline function write_tensor_slot_header!(
    m::TensorSlotHeaderMsg.Encoder,
    timestamp_ns::UInt64,
    meta_version::UInt32,
    values_len_bytes::UInt32,
    payload_slot::UInt32,
    payload_offset::UInt32,
    pool_id::UInt16,
    dtype::Dtype.SbeEnum,
    major_order::MajorOrder.SbeEnum,
    ndims::UInt8,
    dims::AbstractVector{Int32},
    strides::AbstractVector{Int32},
)
    ndims <= MAX_DIMS || throw(ArgumentError("ndims exceeds MAX_DIMS"))
    length(dims) >= ndims || throw(ArgumentError("dims length must cover ndims"))
    length(strides) >= ndims || throw(ArgumentError("strides length must cover ndims"))

    TensorSlotHeaderMsg.timestampNs!(m, timestamp_ns)
    TensorSlotHeaderMsg.metaVersion!(m, meta_version)
    TensorSlotHeaderMsg.valuesLenBytes!(m, values_len_bytes)
    TensorSlotHeaderMsg.payloadSlot!(m, payload_slot)
    TensorSlotHeaderMsg.payloadOffset!(m, payload_offset)
    TensorSlotHeaderMsg.poolId!(m, pool_id)
    TensorSlotHeaderMsg.dtype!(m, dtype)
    TensorSlotHeaderMsg.majorOrder!(m, major_order)
    TensorSlotHeaderMsg.ndims!(m, ndims)
    TensorSlotHeaderMsg.padAlign!(m, UInt8(0))

    dims_view = TensorSlotHeaderMsg.dims!(m)
    for i in 1:MAX_DIMS
        dims_view[i] = i <= ndims ? dims[i] : Int32(0)
    end

    strides_view = TensorSlotHeaderMsg.strides!(m)
    for i in 1:MAX_DIMS
        strides_view[i] = i <= ndims ? strides[i] : Int32(0)
    end
    return nothing
end

"""
Keyword-based wrapper for `write_tensor_slot_header!`.

Arguments:
- Same as the positional variant, passed by keyword.

Returns:
- `nothing`.
"""
@inline function write_tensor_slot_header!(
    m::TensorSlotHeaderMsg.Encoder;
    timestamp_ns::UInt64,
    meta_version::UInt32,
    values_len_bytes::UInt32,
    payload_slot::UInt32,
    payload_offset::UInt32,
    pool_id::UInt16,
    dtype::Dtype.SbeEnum,
    major_order::MajorOrder.SbeEnum,
    ndims::UInt8,
    dims::AbstractVector{Int32},
    strides::AbstractVector{Int32},
)
    return write_tensor_slot_header!(
        m,
        timestamp_ns,
        meta_version,
        values_len_bytes,
        payload_slot,
        payload_offset,
        pool_id,
        dtype,
        major_order,
        ndims,
        dims,
        strides,
    )
end

"""
Decode a tensor slot header into a `TensorSlotHeader` struct.

Arguments:
- `m`: tensor slot header decoder.

Returns:
- `TensorSlotHeader` with decoded values.
"""
function read_tensor_slot_header(m::TensorSlotHeaderMsg.Decoder)
    buf = TensorSlotHeaderMsg.sbe_buffer(m)
    base = TensorSlotHeaderMsg.sbe_offset(m)
    dims_offset = TensorSlotHeaderMsg.dims_encoding_offset(m)
    strides_offset = TensorSlotHeaderMsg.strides_encoding_offset(m)
    elem_bytes = Int(sizeof(Int32))
    dims = ntuple(Val(MAX_DIMS)) do i
        @inbounds TensorSlotHeaderMsg.decode_value(
            Int32,
            buf,
            base + dims_offset + (i - 1) * elem_bytes,
        )
    end
    strides = ntuple(Val(MAX_DIMS)) do i
        @inbounds TensorSlotHeaderMsg.decode_value(
            Int32,
            buf,
            base + strides_offset + (i - 1) * elem_bytes,
        )
    end
    return TensorSlotHeader(
        TensorSlotHeaderMsg.seqCommit(m),
        TensorSlotHeaderMsg.timestampNs(m),
        TensorSlotHeaderMsg.metaVersion(m),
        TensorSlotHeaderMsg.valuesLenBytes(m),
        TensorSlotHeaderMsg.payloadSlot(m),
        TensorSlotHeaderMsg.payloadOffset(m),
        TensorSlotHeaderMsg.poolId(m),
        TensorSlotHeaderMsg.dtype(m),
        TensorSlotHeaderMsg.majorOrder(m),
        TensorSlotHeaderMsg.ndims(m),
        TensorSlotHeaderMsg.padAlign(m),
        dims,
        strides,
    )
end
