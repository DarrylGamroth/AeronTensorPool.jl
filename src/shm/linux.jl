page_size_bytes_linux() = Int(ccall(:getpagesize, Cint, ()))

const SHM_O_RDONLY = Cint(0x0)
const SHM_O_RDWR = Cint(0x2)
const SHM_O_CREAT = Cint(0x40)
const SHM_O_TRUNC = Cint(0x200)
const SHM_O_NOFOLLOW = Cint(0x20000)
const SHM_O_CLOEXEC = Cint(0x80000)

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

function is_hugetlbfs_path_linux(path::AbstractString)
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

function open_shm_nofollow(path::AbstractString, flags::Cint; mode::UInt32 = UInt32(0o600))
    fd = ccall(:open, Cint, (Cstring, Cint, UInt32), path, flags | SHM_O_NOFOLLOW | SHM_O_CLOEXEC, mode)
    fd < 0 && throw(ShmValidationError("open failed for path: $(path) (errno=$(Libc.errno()))"))
    io = open(RawFD(fd))
    stat_info = stat(io)
    if !isfile(stat_info)
        close(io)
        throw(ShmValidationError("shm path is not a regular file: $(path)"))
    end
    return io
end

function open_shm_nofollow(f::Function, path::AbstractString, flags::Cint; mode::UInt32 = UInt32(0o600))
    io = open_shm_nofollow(path, flags; mode = mode)
    try
        return f(io)
    finally
        close(io)
    end
end

"""
Memory-map a shm:file URI with optional write access (Linux backend).
"""
function mmap_shm_linux(uri::AbstractString, size::Integer; write::Bool = false)
    parsed = parse_shm_uri(uri)
    if parsed.require_hugepages
        is_hugetlbfs_path_linux(shm_path(parsed)) ||
            throw(ShmValidationError("hugetlbfs mount required for path: $(shm_path(parsed))"))
        hugepage_size_bytes_linux() > 0 || throw(ShmValidationError("hugetlbfs mount has unknown hugepage size"))
    end
    flags = write ? (SHM_O_RDWR | SHM_O_CREAT) : SHM_O_RDONLY
    return open_shm_nofollow(shm_path(parsed), flags) do io
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
function mmap_shm_existing_linux(uri::AbstractString, size::Integer; write::Bool = false)
    parsed = parse_shm_uri(uri)
    if parsed.require_hugepages
        is_hugetlbfs_path_linux(shm_path(parsed)) ||
            throw(ShmValidationError("hugetlbfs mount required for path: $(shm_path(parsed))"))
        hugepage_size_bytes_linux() > 0 || throw(ShmValidationError("hugetlbfs mount has unknown hugepage size"))
    end
    flags = write ? SHM_O_RDWR : SHM_O_RDONLY
    return open_shm_nofollow(shm_path(parsed), flags) do io
        filesize(io) >= size || throw(ShmValidationError("shm file smaller than requested size"))
        return Mmap.mmap(io, Vector{UInt8}, size; grow = false, shared = true)
    end
end

struct StatvfsLinux
    f_bsize::Culong
    f_frsize::Culong
    f_blocks::Culong
    f_bfree::Culong
    f_bavail::Culong
    f_files::Culong
    f_ffree::Culong
    f_favail::Culong
    f_fsid::Culong
    f_flag::Culong
    f_namemax::Culong
end

function shm_available_bytes_linux(path::AbstractString)
    buf = Ref{StatvfsLinux}()
    rc = ccall(:statvfs, Cint, (Cstring, Ref{StatvfsLinux}), path, buf)
    rc == 0 || throw(ShmValidationError("statvfs failed for path: $(path) (errno=$(Libc.errno()))"))
    return Int(buf[].f_bsize) * Int(buf[].f_bavail)
end
