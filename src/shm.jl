@inline function atomic_load_u64(ptr::Ptr{UInt64})
    return unsafe_load(ptr, :acquire)
end

@inline function atomic_store_u64!(ptr::Ptr{UInt64}, val::UInt64)
    unsafe_store!(ptr, val, :release)
    return nothing
end

@inline function page_size_bytes()
    return Int(ccall(:getpagesize, Cint, ()))
end

function hugepage_size_bytes()
    Sys.islinux() || return 0
    for line in eachline("/proc/meminfo")
        if startswith(line, "Hugepagesize:")
            parts = split(line)
            length(parts) >= 2 || continue
            size_kb = parse(Int, parts[2])
            return size_kb * 1024
        end
    end
    return 0
end

function is_hugetlbfs_path(path::String)
    Sys.islinux() || return false
    best_len = 0
    best_fstype = ""
    for line in eachline("/proc/mounts")
        fields = split(line)
        length(fields) >= 3 || continue
        mount_point = fields[2]
        if startswith(path, mount_point)
            if length(mount_point) > best_len
                best_len = length(mount_point)
                best_fstype = fields[3]
            end
        end
    end
    return best_fstype == "hugetlbfs"
end

@inline function header_slot_offset(index::Integer)
    return SUPERBLOCK_SIZE + Int(index) * HEADER_SLOT_BYTES
end

@inline function payload_slot_offset(stride_bytes::Integer, slot::Integer)
    return SUPERBLOCK_SIZE + Int(slot) * Int(stride_bytes)
end

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

@inline function payload_slot_ptr(buffer::AbstractVector{UInt8}, stride_bytes::Integer, slot::Integer)
    offset = payload_slot_offset(stride_bytes, slot)
    return Ptr{UInt8}(pointer(buffer, offset + 1)), Int(stride_bytes)
end

@inline function wrap_superblock!(m::ShmRegionSuperblock.Encoder, buffer::AbstractVector{UInt8}, offset::Integer = 0)
    @boundscheck length(buffer) >= offset + SUPERBLOCK_SIZE || throw(ArgumentError("buffer too small for superblock"))
    ShmRegionSuperblock.wrap!(m, buffer, offset)
    return m
end

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

@inline function wrap_tensor_header!(m::TensorSlotHeader256.Encoder, buffer::AbstractVector{UInt8}, offset::Integer)
    @boundscheck length(buffer) >= offset + HEADER_SLOT_BYTES || throw(ArgumentError("buffer too small for header slot"))
    TensorSlotHeader256.wrap!(m, buffer, offset)
    return m
end

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

function write_tensor_slot_header!(
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

    dims_view = TensorSlotHeader256.dims!(m)
    strides_view = TensorSlotHeader256.strides!(m)
    for i in 1:MAX_DIMS
        dims_view[i] = i <= length(dims) ? dims[i] : Int32(0)
        strides_view[i] = i <= length(strides) ? strides[i] : Int32(0)
    end
    return nothing
end

function read_tensor_slot_header(m::TensorSlotHeader256.Decoder)
    dims_view = TensorSlotHeader256.dims(m)
    strides_view = TensorSlotHeader256.strides(m)
    dims = ntuple(i -> dims_view[i], Val(MAX_DIMS))
    strides = ntuple(i -> strides_view[i], Val(MAX_DIMS))
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
        dims,
        strides,
    )
end

function parse_shm_uri(uri::String)
    startswith(uri, "shm:file?") || throw(ArgumentError("unsupported shm uri scheme: $uri"))
    params_str = uri[10:end]
    isempty(params_str) && throw(ArgumentError("missing shm uri parameters: $uri"))

    params = split(params_str, '|')
    path = ""
    require_hugepages = false

    for param in params
        parts = split(param, '=', limit = 2)
        length(parts) == 2 || throw(ArgumentError("invalid shm uri parameter: $param"))
        key, value = parts[1], parts[2]
        if key == "path"
            path = value
        elseif key == "require_hugepages"
            value == "true" && (require_hugepages = true)
            value == "false" || value == "true" || throw(ArgumentError("invalid require_hugepages value: $value"))
        else
            throw(ArgumentError("unsupported shm uri parameter: $key"))
        end
    end

    isempty(path) && throw(ArgumentError("missing path in shm uri: $uri"))
    startswith(path, "/") || throw(ArgumentError("shm uri path must be absolute: $path"))

    return ShmUri(path, require_hugepages)
end

function validate_uri(uri::String)
    try
        parse_shm_uri(uri)
    catch
        return false
    end
    return true
end

function mmap_shm(uri::String, size::Integer; write::Bool = false)
    parsed = parse_shm_uri(uri)
    open(parsed.path, write ? "w+" : "r") do io
        if write
            truncate(io, size)
        else
            filesize(io) >= size || throw(ArgumentError("shm file smaller than requested size"))
        end
        prot = write ? (Mmap.PROT_READ | Mmap.PROT_WRITE) : Mmap.PROT_READ
        return Mmap.mmap(io, Vector{UInt8}, size; prot = prot)
    end
end

function select_pool(pools::AbstractVector{PayloadPoolConfig}, values_len::Integer)
    best = nothing
    for pool in pools
        if pool.stride_bytes >= values_len
            if best === nothing || pool.stride_bytes < best.stride_bytes
                best = pool
            end
        end
    end
    return best
end
