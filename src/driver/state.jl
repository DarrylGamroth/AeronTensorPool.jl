struct DriverAnnounceHandler end
struct DriverLeaseCheckHandler end

"""
Lease metadata tracked by the driver.
"""
mutable struct DriverLease
    lease_id::UInt64
    stream_id::UInt32
    client_id::UInt32
    role::DriverRole.SbeEnum
    expiry_ns::UInt64
end

"""
Per-stream driver state.
"""
mutable struct DriverStreamState
    stream_id::UInt32
    profile::DriverProfileConfig
    epoch::UInt64
    header_uri::String
    pool_uris::Dict{UInt16, String}
    producer_lease_id::UInt64
    consumer_lease_ids::Set{UInt64}
end

"""
Driver runtime resources (Aeron client, pubs/subs, codecs).
"""
mutable struct DriverRuntime
    ctx::Aeron.Context
    client::Aeron.Client
    owns_ctx::Bool
    owns_client::Bool
    pub_control::Aeron.Publication
    pub_announce::Aeron.Publication
    pub_qos::Aeron.Publication
    sub_control::Aeron.Subscription
    control_buf::Vector{UInt8}
    announce_buf::Vector{UInt8}
    attach_decoder::ShmAttachRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    detach_decoder::ShmDetachRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    keepalive_decoder::ShmLeaseKeepalive.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    attach_encoder::ShmAttachResponse.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    detach_encoder::ShmDetachResponse.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    revoke_encoder::ShmLeaseRevoked.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    shutdown_encoder::ShmDriverShutdown.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_encoder::ShmPoolAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    superblock_encoder::ShmRegionSuperblock.Encoder{Vector{UInt8}}
    control_claim::Aeron.BufferClaim
    control_assembler::Aeron.FragmentAssembler
end

"""
Driver counters accumulated for metrics.
"""
mutable struct DriverMetrics
    attach_responses::UInt64
    detach_responses::UInt64
    keepalives::UInt64
    lease_revoked::UInt64
    announces::UInt64
end

"""
Driver mutable state.
"""
mutable struct DriverState{ClockT<:Clocks.AbstractClock}
    config::DriverConfig
    clock::ClockT
    runtime::DriverRuntime
    streams::Dict{UInt32, DriverStreamState}
    leases::Dict{UInt64, DriverLease}
    next_lease_id::UInt64
    metrics::DriverMetrics
    timer_set::TimerSet{Tuple{PolledTimer, PolledTimer}, Tuple{DriverAnnounceHandler, DriverLeaseCheckHandler}}
end
