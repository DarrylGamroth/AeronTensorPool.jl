"""
Return the canonical epoch root directory for SHM files.

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `stream_id`: stream identifier.

Returns:
- Filesystem path to the epoch root directory.
"""
function canonical_epoch_root_dir(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    stream_id::Integer,
)
    user = canonical_user_name()
    return joinpath(shm_base_dir, "tensorpool-$(user)", shm_namespace, string(stream_id))
end

"""
Return a sanitized user name for canonical paths.
"""
function canonical_user_name()
    user = get(ENV, "USER", get(ENV, "USERNAME", "unknown"))
    return replace(user, r"[^A-Za-z0-9._-]" => "_")
end

"""
Return the canonical epoch directory for SHM files.

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: logical stream namespace (e.g., "default").
- `stream_id`: stream identifier.
- `epoch`: epoch number.

Returns:
- Filesystem path to the epoch directory.
"""
function canonical_epoch_dir(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    stream_id::Integer,
    epoch::Integer,
)
    root = canonical_epoch_root_dir(shm_base_dir, shm_namespace, stream_id)
    return joinpath(root, string(epoch))
end

"""
Return the canonical SHM header URI for the given epoch.

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `stream_id`: stream identifier.
- `epoch`: epoch number.

Returns:
- `shm:file` URI for the header ring.
"""
function canonical_header_uri(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    stream_id::Integer,
    epoch::Integer,
)
    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, stream_id, epoch)
    return "shm:file?path=$(joinpath(epoch_dir, "header.ring"))"
end

"""
Return the canonical SHM payload URI for the given pool_id and epoch.

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `stream_id`: stream identifier.
- `epoch`: epoch number.
- `pool_id`: payload pool identifier.

Returns:
- `shm:file` URI for the payload pool.
"""
function canonical_pool_uri(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    stream_id::Integer,
    epoch::Integer,
    pool_id::Integer,
)
    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, stream_id, epoch)
    return "shm:file?path=$(joinpath(epoch_dir, "$(pool_id).pool"))"
end

"""
Return canonical SHM header and payload URIs for the given pool_ids.

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `stream_id`: stream identifier.
- `epoch`: epoch number.
- `pool_ids`: pool identifiers to include.

Returns:
- Tuple `(header_uri, pool_uris)` where `pool_uris` is a Dict{UInt16,String}.
"""
function canonical_shm_paths(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    stream_id::Integer,
    epoch::Integer,
    pool_ids::AbstractVector{<:Integer},
)
    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, stream_id, epoch)
    header_uri = "shm:file?path=$(joinpath(epoch_dir, "header.ring"))"
    pool_uris = Dict{UInt16, String}()
    for pool_id in pool_ids
        pool_uris[UInt16(pool_id)] = "shm:file?path=$(joinpath(epoch_dir, "$(pool_id).pool"))"
    end
    return header_uri, pool_uris
end
