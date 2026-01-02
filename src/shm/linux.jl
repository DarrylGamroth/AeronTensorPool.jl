@inline function page_size_bytes_linux()
    return Int(ccall(:getpagesize, Cint, ()))
end

function hugepage_size_bytes_linux()
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

function is_hugetlbfs_path_linux(path::String)
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
Memory-map a shm:file URI with optional write access (Linux backend).
"""
function mmap_shm_linux(uri::String, size::Integer; write::Bool = false)
    parsed = parse_shm_uri(uri)
    if parsed.require_hugepages
        is_hugetlbfs_path_linux(parsed.path) ||
            throw(ShmValidationError("hugetlbfs mount required for path: $(parsed.path)"))
        hugepage_size_bytes_linux() > 0 || throw(ShmValidationError("hugetlbfs mount has unknown hugepage size"))
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
Map an existing SHM region without truncating the backing file (Linux backend).
"""
function mmap_shm_existing_linux(uri::String, size::Integer; write::Bool = false)
    parsed = parse_shm_uri(uri)
    if parsed.require_hugepages
        is_hugetlbfs_path_linux(parsed.path) ||
            throw(ShmValidationError("hugetlbfs mount required for path: $(parsed.path)"))
        hugepage_size_bytes_linux() > 0 || throw(ShmValidationError("hugetlbfs mount has unknown hugepage size"))
    end
    open(parsed.path, write ? "r+" : "r") do io
        filesize(io) >= size || throw(ShmValidationError("shm file smaller than requested size"))
        return Mmap.mmap(io, Vector{UInt8}, size; grow = false, shared = true)
    end
end
