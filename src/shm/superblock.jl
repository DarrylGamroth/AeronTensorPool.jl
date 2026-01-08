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
function wrap_superblock!(m::ShmRegionSuperblock.Encoder, buffer::AbstractVector{UInt8}, offset::Integer = 0)
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
function wrap_superblock!(m::ShmRegionSuperblock.Decoder, buffer::AbstractVector{UInt8}, offset::Integer = 0)
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
Wrap a slot header encoder over a buffer without an SBE message header.

Arguments:
- `m`: slot header encoder.
- `buffer`: header mmap buffer.
- `offset`: byte offset within `buffer`.

Returns:
- The wrapped encoder `m`.
"""
function wrap_slot_header!(m::SlotHeaderMsg.Encoder, buffer::AbstractVector{UInt8}, offset::Integer)
    @boundscheck length(buffer) >= offset + HEADER_SLOT_BYTES || throw(ArgumentError("buffer too small for header slot"))
    SlotHeaderMsg.wrap!(m, buffer, offset)
    return m
end

"""
Wrap a slot header decoder over a buffer without an SBE message header.

Arguments:
- `m`: slot header decoder.
- `buffer`: header mmap buffer.
- `offset`: byte offset within `buffer`.

Returns:
- The wrapped decoder `m`.
"""
function wrap_slot_header!(m::SlotHeaderMsg.Decoder, buffer::AbstractVector{UInt8}, offset::Integer)
    @boundscheck length(buffer) >= offset + HEADER_SLOT_BYTES || throw(ArgumentError("buffer too small for header slot"))
    SlotHeaderMsg.wrap!(
        m,
        buffer,
        offset,
        SlotHeaderMsg.sbe_block_length(SlotHeaderMsg.Decoder),
        SlotHeaderMsg.sbe_schema_version(SlotHeaderMsg.Decoder),
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
Write slot + tensor header fields into an encoder, padding dims/strides to MAX_DIMS.

Arguments:
- `slot`: slot header encoder.
- `tensor`: tensor header encoder (used for embedded headerBytes).
- `timestamp_ns`: timestamp for the frame.
- `meta_version`: metadata schema version.
- `values_len_bytes`: payload length in bytes.
- `payload_slot`: payload slot index.
- `payload_offset`: offset within payload slot (usually 0).
- `pool_id`: payload pool ID.
- `dtype`: element type enum.
- `major_order`: major order enum.
- `ndims`: number of dimensions.
- `progress_unit`: progress unit enum.
- `progress_stride_bytes`: bytes between adjacent rows/columns when progress is enabled.
- `dims`: dimension sizes (length >= `ndims`).
- `strides`: stride sizes (length >= `ndims`).

Returns:
- `nothing`.
"""
function write_slot_header!(
    slot::SlotHeaderMsg.Encoder,
    tensor::TensorHeaderMsg.Encoder,
    timestamp_ns::UInt64,
    meta_version::UInt32,
    values_len_bytes::UInt32,
    payload_slot::UInt32,
    payload_offset::UInt32,
    pool_id::UInt16,
    dtype::Dtype.SbeEnum,
    major_order::MajorOrder.SbeEnum,
    ndims::UInt8,
    progress_unit::ProgressUnit.SbeEnum,
    progress_stride_bytes::UInt32,
    dims::AbstractVector{Int32},
    strides::AbstractVector{Int32},
)
    SlotHeaderMsg.sbe_position!(
        slot,
        SlotHeaderMsg.sbe_offset(slot) + SlotHeaderMsg.sbe_block_length(SlotHeaderMsg.Decoder),
    )
    @boundscheck begin
        ndims <= MAX_DIMS || throw(ArgumentError("ndims exceeds MAX_DIMS"))
        length(dims) >= ndims || throw(ArgumentError("dims length must cover ndims"))
        length(strides) >= ndims || throw(ArgumentError("strides length must cover ndims"))
    end

    SlotHeaderMsg.timestampNs!(slot, timestamp_ns)
    SlotHeaderMsg.metaVersion!(slot, meta_version)
    SlotHeaderMsg.valuesLenBytes!(slot, values_len_bytes)
    SlotHeaderMsg.payloadSlot!(slot, payload_slot)
    SlotHeaderMsg.payloadOffset!(slot, payload_offset)
    SlotHeaderMsg.poolId!(slot, pool_id)

    SlotHeaderMsg.headerBytes_length!(slot, TENSOR_HEADER_LEN)
    header_pos = SlotHeaderMsg.sbe_position(slot) + SlotHeaderMsg.headerBytes_header_length
    SlotHeaderMsg.sbe_position!(slot, header_pos + TENSOR_HEADER_LEN)
    header_buf = SlotHeaderMsg.sbe_buffer(slot)
    TensorHeaderMsg.wrap_and_apply_header!(tensor, header_buf, header_pos)
    TensorHeaderMsg.dtype!(tensor, dtype)
    TensorHeaderMsg.majorOrder!(tensor, major_order)
    TensorHeaderMsg.ndims!(tensor, ndims)
    TensorHeaderMsg.padAlign!(tensor, UInt8(0))
    TensorHeaderMsg.progressUnit!(tensor, progress_unit)
    TensorHeaderMsg.progressStrideBytes!(tensor, progress_stride_bytes)

    dims_view = TensorHeaderMsg.dims!(tensor)
    for i in 1:MAX_DIMS
        dims_view[i] = i <= ndims ? dims[i] : Int32(0)
    end

    strides_view = TensorHeaderMsg.strides!(tensor)
    for i in 1:MAX_DIMS
        strides_view[i] = i <= ndims ? strides[i] : Int32(0)
    end
    return nothing
end

"""
Keyword-based wrapper for `write_slot_header!`.

Arguments:
- Same as the positional variant, passed by keyword.

Returns:
- `nothing`.
"""
function write_slot_header!(
    slot::SlotHeaderMsg.Encoder,
    tensor::TensorHeaderMsg.Encoder;
    timestamp_ns::UInt64,
    meta_version::UInt32,
    values_len_bytes::UInt32,
    payload_slot::UInt32,
    payload_offset::UInt32,
    pool_id::UInt16,
    dtype::Dtype.SbeEnum,
    major_order::MajorOrder.SbeEnum,
    ndims::UInt8,
    progress_unit::ProgressUnit.SbeEnum,
    progress_stride_bytes::UInt32,
    dims::AbstractVector{Int32},
    strides::AbstractVector{Int32},
)
    return write_slot_header!(
        slot,
        tensor,
        timestamp_ns,
        meta_version,
        values_len_bytes,
        payload_slot,
        payload_offset,
        pool_id,
        dtype,
        major_order,
        ndims,
        progress_unit,
        progress_stride_bytes,
        dims,
        strides,
    )
end

"""
Decode a slot header into a `SlotHeader` struct.

Arguments:
- `slot`: slot header decoder.
- `tensor`: tensor header decoder (reused; wrapped over headerBytes).
- `buffer`: header mmap buffer.
- `header_pos`: byte offset of embedded TensorHeader header.

Returns:
- `SlotHeader` with decoded values.
"""
function read_slot_header(
    slot::SlotHeaderMsg.Decoder,
    tensor::TensorHeaderMsg.Decoder,
    buffer::AbstractVector{UInt8},
    header_pos::Integer,
)
    TensorHeaderMsg.wrap!(tensor, buffer, header_pos)

    dims = TensorHeaderMsg.dims(tensor, NTuple{MAX_DIMS, Int32})
    strides = TensorHeaderMsg.strides(tensor, NTuple{MAX_DIMS, Int32})
    tensor_fields = TensorHeader(
        TensorHeaderMsg.dtype(tensor),
        TensorHeaderMsg.majorOrder(tensor),
        TensorHeaderMsg.ndims(tensor),
        TensorHeaderMsg.padAlign(tensor),
        TensorHeaderMsg.progressUnit(tensor),
        TensorHeaderMsg.progressStrideBytes(tensor),
        dims,
        strides,
    )
    return SlotHeader(
        SlotHeaderMsg.seqCommit(slot),
        SlotHeaderMsg.timestampNs(slot),
        SlotHeaderMsg.metaVersion(slot),
        SlotHeaderMsg.valuesLenBytes(slot),
        SlotHeaderMsg.payloadSlot(slot),
        SlotHeaderMsg.payloadOffset(slot),
        SlotHeaderMsg.poolId(slot),
        tensor_fields,
    )
end

"""
Try to decode a slot header without throwing.

Arguments:
- `slot`: slot header decoder.
- `tensor`: tensor header decoder (reused; wrapped over headerBytes).

Returns:
- `SlotHeader` on success, `nothing` if the buffer is too short or invalid.
"""
function try_read_slot_header(slot::SlotHeaderMsg.Decoder, tensor::TensorHeaderMsg.Decoder)
    len = SlotHeaderMsg.headerBytes_length(slot)
    len == TENSOR_HEADER_LEN || return nothing
    header_pos = SlotHeaderMsg.sbe_position(slot) + SlotHeaderMsg.headerBytes_header_length
    buffer = SlotHeaderMsg.sbe_buffer(slot)
    header_pos >= 0 && header_pos + len <= length(buffer) || return nothing

    header = MessageHeader.Decoder(buffer, header_pos)
    MessageHeader.templateId(header) == TensorHeaderMsg.sbe_template_id(TensorHeaderMsg.Decoder) ||
        return nothing
    MessageHeader.schemaId(header) == TensorHeaderMsg.sbe_schema_id(TensorHeaderMsg.Decoder) ||
        return nothing
    MessageHeader.blockLength(header) == TensorHeaderMsg.sbe_block_length(TensorHeaderMsg.Decoder) ||
        return nothing
    MessageHeader.version(header) == TensorHeaderMsg.sbe_schema_version(TensorHeaderMsg.Decoder) ||
        return nothing
    return read_slot_header(slot, tensor, buffer, header_pos)
end
