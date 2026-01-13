using Hsm

"""
Driver status snapshot.
"""
struct DriverStatusSnapshot
    instance_id::String
    lifecycle::Symbol
    shutdown_reason::DriverShutdownReason.SbeEnum
    shutdown_message::String
    stream_count::Int
    lease_count::Int
    next_stream_id::UInt32
    next_lease_id::UInt64
    stream_id_range::Union{DriverStreamIdRange, Nothing}
    descriptor_stream_id_range::Union{DriverStreamIdRange, Nothing}
    control_stream_id_range::Union{DriverStreamIdRange, Nothing}
end

"""
Driver lease snapshot.
"""
struct DriverLeaseSnapshot
    lease_id::UInt64
    stream_id::UInt32
    client_id::UInt32
    node_id::UInt32
    role::DriverRole.SbeEnum
    expiry_ns::UInt64
    lifecycle::Symbol
end

"""
Driver stream snapshot.
"""
struct DriverStreamSnapshot
    stream_id::UInt32
    profile::String
    epoch::UInt64
    header_uri::String
    pool_uris::Vector{Pair{UInt16, String}}
    producer_lease_id::UInt64
    consumer_lease_ids::Vector{UInt64}
end

"""
Assigned per-consumer streams snapshot.
"""
struct DriverAssignedStreamSnapshot
    consumer_id::UInt32
    descriptor_stream_id::UInt32
    control_stream_id::UInt32
end

"""
Capture a driver status snapshot.
"""
function driver_status_snapshot(state::DriverState)
    DriverStatusSnapshot(
        state.config.endpoints.instance_id,
        Hsm.current(state.lifecycle),
        state.shutdown_reason,
        state.shutdown_message,
        length(state.streams),
        length(state.leases),
        state.next_stream_id,
        state.next_lease_id,
        state.config.stream_id_range,
        state.config.descriptor_stream_id_range,
        state.config.control_stream_id_range,
    )
end

"""
Capture current leases as snapshots.
"""
function driver_leases_snapshot(state::DriverState)
    leases = DriverLeaseSnapshot[]
    for lease in values(state.leases)
        push!(
            leases,
            DriverLeaseSnapshot(
                lease.lease_id,
                lease.stream_id,
                lease.client_id,
                lease.node_id,
                lease.role,
                lease.expiry_ns,
                Hsm.current(lease.lifecycle),
            ),
        )
    end
    sort!(leases, by = l -> l.lease_id)
    return leases
end

"""
Capture current stream states as snapshots.
"""
function driver_streams_snapshot(state::DriverState)
    streams = DriverStreamSnapshot[]
    for stream in values(state.streams)
        pool_uris = collect(pairs(stream.pool_uris))
        sort!(pool_uris, by = p -> p.first)
        consumer_lease_ids = collect(stream.consumer_lease_ids)
        sort!(consumer_lease_ids)
        push!(
            streams,
            DriverStreamSnapshot(
                stream.stream_id,
                stream.profile.name,
                stream.epoch,
                stream.header_uri,
                pool_uris,
                stream.producer_lease_id,
                consumer_lease_ids,
            ),
        )
    end
    sort!(streams, by = s -> s.stream_id)
    return streams
end

"""
Capture assigned per-consumer streams.
"""
function driver_assigned_streams_snapshot(state::DriverState)
    snapshots = DriverAssignedStreamSnapshot[]
    consumer_ids = union(
        keys(state.consumer_descriptor_streams),
        keys(state.consumer_control_streams),
    )
    for consumer_id in consumer_ids
        desc_id = get(state.consumer_descriptor_streams, consumer_id, UInt32(0))
        ctrl_id = get(state.consumer_control_streams, consumer_id, UInt32(0))
        push!(
            snapshots,
            DriverAssignedStreamSnapshot(consumer_id, desc_id, ctrl_id),
        )
    end
    sort!(snapshots, by = s -> s.consumer_id)
    return snapshots
end
