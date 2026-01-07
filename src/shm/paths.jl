"""
Return the canonical epoch directory for SHM files.

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `producer_instance_id`: producer instance identifier.
- `epoch`: epoch number.

Returns:
- Filesystem path to the epoch directory.
"""
function canonical_epoch_dir(
    shm_base_dir::AbstractString,
    shm_namespace::AbstractString,
    producer_instance_id::AbstractString,
    epoch::Integer,
)
    return joinpath(shm_base_dir, shm_namespace, producer_instance_id, "epoch-$(epoch)")
end

"""
Return the canonical SHM header URI for the given epoch.

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `producer_instance_id`: producer instance identifier.
- `epoch`: epoch number.

Returns:
- `shm:file` URI for the header ring.
"""
function canonical_header_uri(
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

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `producer_instance_id`: producer instance identifier.
- `epoch`: epoch number.
- `pool_id`: payload pool identifier.

Returns:
- `shm:file` URI for the payload pool.
"""
function canonical_pool_uri(
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

Arguments:
- `shm_base_dir`: base directory for SHM files.
- `shm_namespace`: namespace under `shm_base_dir`.
- `producer_instance_id`: producer instance identifier.
- `epoch`: epoch number.
- `pool_ids`: pool identifiers to include.

Returns:
- Tuple `(header_uri, pool_uris)` where `pool_uris` is a Dict{UInt16,String}.
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
