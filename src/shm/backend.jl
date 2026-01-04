"""
Backend dispatch for SHM operations.

Returns:
- Page size in bytes for the active backend.
"""
@inline function page_size_bytes()
    return page_size_bytes_linux()
end

"""
Return the hugepage size in bytes for the active backend.

Returns:
- Hugepage size in bytes.
"""
@inline function hugepage_size_bytes()
    return hugepage_size_bytes_linux()
end

"""
Return true if a path is on hugetlbfs.

Arguments:
- `path`: filesystem path.

Returns:
- `true` if the path resides on hugetlbfs, `false` otherwise.
"""
@inline function is_hugetlbfs_path(path::AbstractString)
    return is_hugetlbfs_path_linux(path)
end

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
