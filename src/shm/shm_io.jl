"""
Begin a seqlock write by marking the commit_word as odd (WRITING).
"""
@inline function seqlock_begin_write!(commit_ptr::Ptr{UInt64}, frame_id::UInt64)
    unsafe_store!(commit_ptr, (frame_id << 1) | 1, :release)
    return nothing
end

"""
Commit a seqlock write by marking the commit_word as even (COMMITTED).
"""
@inline function seqlock_commit_write!(commit_ptr::Ptr{UInt64}, frame_id::UInt64)
    unsafe_store!(commit_ptr, frame_id << 1, :release)
    return nothing
end

"""
Acquire-load the current seqlock commit_word at the start of a read.
"""
@inline function seqlock_read_begin(commit_ptr::Ptr{UInt64})
    return unsafe_load(commit_ptr, :acquire)
end

"""
Acquire-load the seqlock commit_word at the end of a read.
"""
@inline function seqlock_read_end(commit_ptr::Ptr{UInt64})
    return unsafe_load(commit_ptr, :acquire)
end

"""
Return true if the seqlock indicates an in-progress write.
"""
@inline function seqlock_is_write_in_progress(word::UInt64)
    return isodd(word)
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

"""
Return the canonical epoch directory for SHM files.
"""
@inline function canonical_epoch_dir(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    producer_instance_id::AbstractString,
    epoch::Integer,
)
    return joinpath(shm_base_dir, shm_namespace, producer_instance_id, "epoch-$(epoch)")
end

"""
Return the canonical SHM header URI for the given epoch.
"""
@inline function canonical_header_uri(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    producer_instance_id::AbstractString,
    epoch::Integer,
)
    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, producer_instance_id, epoch)
    return "shm:file?path=$(joinpath(epoch_dir, "header.ring"))"
end

"""
Return the canonical SHM payload URI for the given pool_id and epoch.
"""
@inline function canonical_pool_uri(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    producer_instance_id::AbstractString,
    epoch::Integer,
    pool_id::Integer,
)
    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, producer_instance_id, epoch)
    return "shm:file?path=$(joinpath(epoch_dir, "payload-$(pool_id).pool"))"
end

"""
Return canonical SHM header and payload URIs for the given pool_ids.
"""
function canonical_shm_paths(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    producer_instance_id::AbstractString,
    epoch::Integer,
    pool_ids::AbstractVector{<:Integer},
)
    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, producer_instance_id, epoch)
    header_uri = "shm:file?path=$(joinpath(epoch_dir, "header.ring"))"
    pool_uris = Dict{UInt16, String}()
    for pool_id in pool_ids
        pool_uris[UInt16(pool_id)] = "shm:file?path=$(joinpath(epoch_dir, "payload-$(pool_id).pool"))"
    end
    return header_uri, pool_uris
end

"""
Return byte offset for a header slot index.
"""
@inline function header_slot_offset(index::Integer)
    return SUPERBLOCK_SIZE + Int(index) * HEADER_SLOT_BYTES
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
    dims = TensorSlotHeader256.dims(m, NTuple{MAX_DIMS, Int32})
    strides = TensorSlotHeader256.strides(m, NTuple{MAX_DIMS, Int32})
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

"""
Parse a shm:file URI into a ShmUri.
"""
function parse_shm_uri(uri::String)
    startswith(uri, "shm:file?") || throw(ShmUriError("unsupported shm uri scheme: $uri"))
    params_str = uri[10:end]
    isempty(params_str) && throw(ShmUriError("missing shm uri parameters: $uri"))

    params = split(params_str, '|')
    path = ""
    require_hugepages = false

    for param in params
        parts = split(param, '=', limit = 2)
        length(parts) == 2 || throw(ShmUriError("invalid shm uri parameter: $param"))
        key, value = parts[1], parts[2]
        if key == "path"
            path = value
        elseif key == "require_hugepages"
            value == "true" && (require_hugepages = true)
            value == "false" || value == "true" || throw(ShmUriError("invalid require_hugepages value: $value"))
        else
            throw(ShmUriError("unsupported shm uri parameter: $key"))
        end
    end

    isempty(path) && throw(ShmUriError("missing path in shm uri: $uri"))
    startswith(path, "/") || throw(ShmUriError("shm uri path must be absolute: $path"))

    return ShmUri(path, require_hugepages)
end

"""
Return true if a shm:file URI is valid and supported.
"""
function validate_uri(uri::String)
    try
        parse_shm_uri(uri)
    catch
        return false
    end
    return true
end

"""
Memory-map a shm:file URI with optional write access.
"""
function mmap_shm(uri::String, size::Integer; write::Bool = false)
    parsed = parse_shm_uri(uri)
    if parsed.require_hugepages
        is_hugetlbfs_path(parsed.path) || throw(ShmValidationError("hugetlbfs mount required for path: $(parsed.path)"))
        hugepage_size_bytes() > 0 || throw(ShmValidationError("hugetlbfs mount has unknown hugepage size"))
    end
    open(parsed.path, write ? "w+" : "r") do io
        if write
            truncate(io, size)
        else
            filesize(io) >= size || throw(ShmValidationError("shm file smaller than requested size"))
        end
        return Mmap.mmap(io, Vector{UInt8}, size; grow = write, shared = true)
    end
end

"""
Pick the smallest payload pool that can fit values_len.
"""
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
