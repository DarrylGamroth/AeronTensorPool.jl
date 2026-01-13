struct DriverAnnounceHandler end
struct DriverLeaseCheckHandler end
struct DriverShutdownHandler end

"""
Lease metadata tracked by the driver.
"""
mutable struct DriverLease
    lease_id::UInt64
    stream_id::UInt32
    client_id::UInt32
    node_id::UInt32
    expiry_ns::UInt64
    lifecycle::LeaseLifecycle
    role::DriverRole.SbeEnum
end

"""
Per-stream driver state.
"""
mutable struct DriverStreamState
    stream_id::UInt32
    profile::DriverProfileConfig
    epoch::UInt64
    epoch_start_ns::Dict{UInt64, UInt64}
    header_uri::String
    pool_uris::Dict{UInt16, String}
    producer_lease_id::UInt64
    consumer_lease_ids::Set{UInt64}
end

"""
Driver runtime resources (Aeron client, pubs/subs, codecs).
"""
mutable struct DriverRuntime
    control::ControlPlaneRuntime
    pub_announce::Aeron.Publication
    pub_qos::Aeron.Publication
    control_buf::FixedSizeVectorDefault{UInt8}
    announce_buf::FixedSizeVectorDefault{UInt8}
    attach_decoder::ShmAttachRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    detach_decoder::ShmDetachRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    keepalive_decoder::ShmLeaseKeepalive.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    shutdown_request_decoder::ShmDriverShutdownRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    hello_decoder::ConsumerHello.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    attach_encoder::ShmAttachResponse.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    detach_encoder::ShmDetachResponse.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    revoke_encoder::ShmLeaseRevoked.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    shutdown_encoder::ShmDriverShutdown.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_encoder::ShmPoolAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    config_encoder::ConsumerConfigMsg.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    superblock_encoder::ShmRegionSuperblock.Encoder{Vector{UInt8}}
    control_claim::Aeron.BufferClaim
    control_assembler::Aeron.FragmentAssembler
end

"""
Driver mutable state.
"""
mutable struct DriverState{ClockT}
    config::DriverConfig
    clock::ClockT
    runtime::DriverRuntime
    streams::Dict{UInt32, DriverStreamState}
    leases::Dict{UInt64, DriverLease}
    assigned_node_ids::Dict{UInt32, UInt64}
    next_lease_id::UInt64
    next_node_id::UInt32
    next_stream_id::UInt32
    next_descriptor_stream_id::UInt32
    next_control_stream_id::UInt32
    consumer_descriptor_streams::Dict{UInt32, UInt32}
    consumer_control_streams::Dict{UInt32, UInt32}
    metrics::DriverMetrics
    timer_set::TimerSet{
        Tuple{PolledTimer, PolledTimer, PolledTimer},
        Tuple{DriverAnnounceHandler, DriverLeaseCheckHandler, DriverShutdownHandler},
    }
    work_count::Int
    shutdown_reason::DriverShutdownReason.SbeEnum
    shutdown_message::String
    lifecycle::DriverLifecycle
end

const DRIVER_TIMER_ANNOUNCE = 1
const DRIVER_TIMER_LEASE_CHECK = 2
const DRIVER_TIMER_SHUTDOWN = 3

driver_announce_timer(state::DriverState) = state.timer_set.timers[DRIVER_TIMER_ANNOUNCE]
driver_lease_check_timer(state::DriverState) = state.timer_set.timers[DRIVER_TIMER_LEASE_CHECK]
driver_shutdown_timer(state::DriverState) = state.timer_set.timers[DRIVER_TIMER_SHUTDOWN]
