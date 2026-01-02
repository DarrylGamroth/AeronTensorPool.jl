"""
Wrap a superblock encoder over a buffer without SBE message header.
"""
@inline function wrap_superblock!(m::ShmRegionSuperblock.Encoder, buffer::AbstractVector{UInt8}, offset::Integer = 0)
    @boundscheck length(buffer) >= offset + SUPERBLOCK_SIZE || throw(ArgumentError("buffer too small for superblock"))
    ShmRegionSuperblock.wrap!(m, buffer, offset)
    return m
end

"""
Wrap a superblock decoder over a buffer without SBE message header.
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
Wrap a tensor slot header encoder over a buffer without SBE message header.
"""
@inline function wrap_tensor_header!(m::TensorSlotHeader256.Encoder, buffer::AbstractVector{UInt8}, offset::Integer)
    @boundscheck length(buffer) >= offset + HEADER_SLOT_BYTES || throw(ArgumentError("buffer too small for header slot"))
    TensorSlotHeader256.wrap!(m, buffer, offset)
    return m
end

"""
Wrap a tensor slot header decoder over a buffer without SBE message header.
"""
@inline function wrap_tensor_header!(m::TensorSlotHeader256.Decoder, buffer::AbstractVector{UInt8}, offset::Integer)
    @boundscheck length(buffer) >= offset + HEADER_SLOT_BYTES || throw(ArgumentError("buffer too small for header slot"))
    TensorSlotHeader256.wrap!(
        m,
        buffer,
        offset,
        TensorSlotHeader256.sbe_block_length(TensorSlotHeader256.Decoder),
        TensorSlotHeader256.sbe_schema_version(TensorSlotHeader256.Decoder),
    )
    return m
end

"""
Write superblock fields into an encoder.
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
Decode a superblock into a SuperblockFields struct.
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
Write tensor slot header fields to an encoder, padding dims/strides to MAX_DIMS.
"""
@inline function write_tensor_slot_header!(
    m::TensorSlotHeader256.Encoder,
    frame_id::UInt64,
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

    TensorSlotHeader256.frameId!(m, frame_id)
    TensorSlotHeader256.timestampNs!(m, timestamp_ns)
    TensorSlotHeader256.metaVersion!(m, meta_version)
    TensorSlotHeader256.valuesLenBytes!(m, values_len_bytes)
    TensorSlotHeader256.payloadSlot!(m, payload_slot)
    TensorSlotHeader256.payloadOffset!(m, payload_offset)
    TensorSlotHeader256.poolId!(m, pool_id)
    TensorSlotHeader256.dtype!(m, dtype)
    TensorSlotHeader256.majorOrder!(m, major_order)
    TensorSlotHeader256.ndims!(m, ndims)
    TensorSlotHeader256.padAlign!(m, UInt8(0))

    dims_len = length(dims)
    dims_view = TensorSlotHeader256.dims!(m)
    for i in 1:MAX_DIMS
        dims_view[i] = i <= dims_len ? dims[i] : Int32(0)
    end

    strides_len = length(strides)
    strides_view = TensorSlotHeader256.strides!(m)
    for i in 1:MAX_DIMS
        strides_view[i] = i <= strides_len ? strides[i] : Int32(0)
    end
    return nothing
end

"""
Keyword-based wrapper for write_tensor_slot_header!.
"""
@inline function write_tensor_slot_header!(
    m::TensorSlotHeader256.Encoder;
    frame_id::UInt64,
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
        frame_id,
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
Decode a tensor slot header into a TensorSlotHeader struct.
"""
function read_tensor_slot_header(m::TensorSlotHeader256.Decoder)
    return TensorSlotHeader(
        TensorSlotHeader256.commitWord(m),
        TensorSlotHeader256.frameId(m),
        TensorSlotHeader256.timestampNs(m),
        TensorSlotHeader256.metaVersion(m),
        TensorSlotHeader256.valuesLenBytes(m),
        TensorSlotHeader256.payloadSlot(m),
        TensorSlotHeader256.payloadOffset(m),
        TensorSlotHeader256.poolId(m),
        TensorSlotHeader256.dtype(m),
        TensorSlotHeader256.majorOrder(m),
        TensorSlotHeader256.ndims(m),
        TensorSlotHeader256.padAlign(m),
        TensorSlotHeader256.dims(m, NTuple{MAX_DIMS, Int32}),
        TensorSlotHeader256.strides(m, NTuple{MAX_DIMS, Int32}),
    )
end
