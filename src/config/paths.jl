"""
Resolve producer header/pool URIs for a given epoch directory.

If any of the inputs are empty, returns the original header URI and pools.
"""
function resolve_producer_paths(
    header_uri::String,
    payload_pools::Vector{PayloadPoolConfig},
    shm_base_dir::String,
    shm_namespace::String,
    stream_id::UInt32,
    epoch::UInt64,
)
    isempty(shm_base_dir) && return header_uri, payload_pools
    isempty(shm_namespace) && return header_uri, payload_pools
    stream_id == 0 && return header_uri, payload_pools

    epoch_dir = canonical_epoch_dir(shm_base_dir, shm_namespace, stream_id, epoch)
    resolved_header_uri = header_uri
    if isempty(resolved_header_uri)
        resolved_header_uri = "shm:file?path=$(joinpath(epoch_dir, "header.ring"))"
    end

    resolved_pools = PayloadPoolConfig[]
    for pool in payload_pools
        uri = pool.uri
        if isempty(uri)
            uri = "shm:file?path=$(joinpath(epoch_dir, "$(pool.pool_id).pool"))"
        end
        push!(resolved_pools, PayloadPoolConfig(pool.pool_id, uri, pool.stride_bytes, pool.nslots))
    end
    return resolved_header_uri, resolved_pools
end
