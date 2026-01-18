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
Map a SHM region, pass the buffer to `f`, and unmap on exit.

This helper is intended for setup/teardown paths, not hot loops.
"""
function with_mmap_shm(f::Function, uri::AbstractString, size::Integer; write::Bool = false)
    buffer = mmap_shm(uri, size; write = write)
    try
        return f(buffer)
    finally
        if write
            try
                Mmap.sync!(buffer)
            catch
            end
        end
        try
            Mmap.munmap(buffer)
        catch
        end
    end
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

"""
Map an existing SHM region, pass the buffer to `f`, and unmap on exit.

This helper is intended for setup/teardown paths, not hot loops.
"""
function with_mmap_shm_existing(f::Function, uri::AbstractString, size::Integer; write::Bool = false)
    buffer = mmap_shm_existing(uri, size; write = write)
    try
        return f(buffer)
    finally
        if write
            try
                Mmap.sync!(buffer)
            catch
            end
        end
        try
            Mmap.munmap(buffer)
        catch
        end
    end
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
    GC.@preserve buffer begin
        ptr = Ptr{UInt8}(pointer(buffer))
        res = Libc.mlock(ptr, length(buffer))
        res == 0 || throw(ArgumentError("mlock failed for $(label) (errno=$(Libc.errno()))"))
    end
    return nothing
end
