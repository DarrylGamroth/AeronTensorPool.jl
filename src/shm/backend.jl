"""
Backend dispatch for SHM operations.
"""
@inline function page_size_bytes()
    return page_size_bytes_linux()
end

@inline function hugepage_size_bytes()
    return hugepage_size_bytes_linux()
end

@inline function is_hugetlbfs_path(path::AbstractString)
    return is_hugetlbfs_path_linux(path)
end

"""
Memory-map a shm:file URI with optional write access.
"""
function mmap_shm(uri::AbstractString, size::Integer; write::Bool = false)
    return mmap_shm_linux(uri, size; write = write)
end

"""
Map an existing SHM region without truncating the backing file.
"""
function mmap_shm_existing(uri::AbstractString, size::Integer; write::Bool = false)
    return mmap_shm_existing_linux(uri, size; write = write)
end
