"""
Backend dispatch for SHM operations.

Returns:
- Page size in bytes for the active backend.
"""
page_size_bytes() = page_size_bytes_linux()

"""
Return the hugepage size in bytes for the active backend.

Returns:
- Hugepage size in bytes.
"""
hugepage_size_bytes() = hugepage_size_bytes_linux()

"""
Return true if a path is on hugetlbfs.

Arguments:
- `path`: filesystem path.

Returns:
- `true` if the path resides on hugetlbfs, `false` otherwise.
"""
is_hugetlbfs_path(path::AbstractString) = is_hugetlbfs_path_linux(path)

"""
Memory-map a `shm:file` URI with optional write access.

Arguments:
- `uri`: shm URI string.
- `size`: mapping size in bytes.
- `write`: enable write access (default: false).

Returns:
- `Vector{UInt8}` backed by the mapping.
"""
function mmap_shm(uri::AbstractString, size::Integer; write::Bool = false)
    return mmap_shm_linux(uri, size; write = write)
end

"""
Map an existing SHM region without truncating the backing file.

Arguments:
- `uri`: shm URI string.
- `size`: mapping size in bytes.
- `write`: enable write access (default: false).

Returns:
- `Vector{UInt8}` backed by the mapping.
"""
function mmap_shm_existing(uri::AbstractString, size::Integer; write::Bool = false)
    return mmap_shm_existing_linux(uri, size; write = write)
end

function shm_available_bytes(path::AbstractString)
    return shm_available_bytes_linux(path)
end

"""
Attempt to mlock a mapped buffer. On non-Unix platforms this is a no-op with a warning.

Arguments:
- `buffer`: mapped bytes.
- `label`: identifier for logging.

Returns:
- `nothing`.
"""
function mlock_buffer!(buffer::AbstractVector{UInt8}, label::AbstractString)
    if !Sys.isunix()
        @tp_warn "mlock unsupported on this platform; skipping" label
        return nothing
    end
    ptr = Ptr{UInt8}(pointer(buffer))
    res = Libc.mlock(ptr, length(buffer))
    res == 0 || throw(ArgumentError("mlock failed for $(label) (errno=$(Libc.errno()))"))
    return nothing
end
