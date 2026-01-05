"""
Compose a 32-bit Aeron counter type id from agent id and counter type.

Arguments:
- `agent_id`: 16-bit agent identifier (0-65535).
- `counter_type`: 16-bit counter type (0-65535).

Returns:
- `Int32` counter type id.
"""
function make_counter_type_id(agent_id, counter_type)
    @assert 0 ≤ agent_id ≤ 65535 "agent_id must be in range 0-65535 (16-bit)"
    @assert 0 ≤ counter_type ≤ 65535 "counter_type must be in range 0-65535 (16-bit)"
    return Int32((Int32(agent_id) << 16) | Int32(counter_type))
end

"""
Create a labeled Aeron counter with a standard key buffer.

Arguments:
- `client`: Aeron client.
- `agent_id`: agent identifier.
- `agent_name`: agent name string.
- `counter_type`: counter type id (16-bit).
- `label`: label prefix.

Returns:
- `Aeron.Counter`.
"""
function add_counter(client::Aeron.Client, agent_id, agent_name, counter_type, label)
    type_id = make_counter_type_id(agent_id, counter_type)
    name_bytes = codeunits(agent_name)
    key_buffer = Vector{UInt8}(undef, sizeof(Int64) + length(name_bytes))
    key_buffer[1:8] .= reinterpret(UInt8, [agent_id])
    key_buffer[9:end] .= name_bytes
    full_label = "$label: NodeId=$agent_id Name=$agent_name"
    return Aeron.add_counter(client, type_id, key_buffer, full_label)
end

"""
Base counters shared by all agents.
"""
struct Counters
    total_duty_cycles::Aeron.Counter
    total_work_done::Aeron.Counter
end

"""
Construct base counters for a given agent identity.

Arguments:
- `client`: Aeron client.
- `agent_id`: agent identifier.
- `agent_name`: agent name string.

Returns:
- `Counters`.
"""
function Counters(client::Aeron.Client, agent_id, agent_name)
    Counters(
        add_counter(client, agent_id, agent_name, 1, "TotalDutyCycles"),
        add_counter(client, agent_id, agent_name, 2, "TotalWorkDone"),
    )
end

"""
Producer-specific counters (frames, announces, QoS).
"""
struct ProducerCounters
    base::Counters
    frames_published::Aeron.Counter
    announces::Aeron.Counter
    qos_published::Aeron.Counter
end

"""
Consumer-specific counters (drops, remaps, hello, QoS).
"""
struct ConsumerCounters
    base::Counters
    drops_gap::Aeron.Counter
    drops_late::Aeron.Counter
    drops_odd::Aeron.Counter
    drops_changed::Aeron.Counter
    drops_frame_id_mismatch::Aeron.Counter
    drops_header_invalid::Aeron.Counter
    drops_payload_invalid::Aeron.Counter
    remaps::Aeron.Counter
    hello_published::Aeron.Counter
    qos_published::Aeron.Counter
end

"""
Supervisor-specific counters (config publishes and liveness checks).
"""
struct SupervisorCounters
    base::Counters
    config_published::Aeron.Counter
    liveness_checks::Aeron.Counter
end

"""
Driver-specific counters (attach, detach, keepalive, revoke, announce).
"""
struct DriverCounters
    base::Counters
    attach_responses::Aeron.Counter
    attach_response_drops::Aeron.Counter
    detach_responses::Aeron.Counter
    keepalives::Aeron.Counter
    lease_revoked::Aeron.Counter
    announces::Aeron.Counter
    lease_hsm_unhandled::Aeron.Counter
end

"""
Bridge-specific counters (rematerialized frames).
"""
struct BridgeCounters
    base::Counters
    frames_forwarded::Aeron.Counter
    chunks_sent::Aeron.Counter
    chunks_dropped::Aeron.Counter
    assemblies_reset::Aeron.Counter
    control_forwarded::Aeron.Counter
    frames_rematerialized::Aeron.Counter
end

"""
Construct producer counters for a given agent identity.

Arguments:
- `client`: Aeron client.
- `agent_id`: agent identifier.
- `agent_name`: agent name string.

Returns:
- `ProducerCounters`.
"""
function ProducerCounters(client::Aeron.Client, agent_id, agent_name)
    ProducerCounters(
        Counters(client, agent_id, agent_name),
        add_counter(client, agent_id, agent_name, 3, "FramesPublished"),
        add_counter(client, agent_id, agent_name, 4, "AnnouncesPublished"),
        add_counter(client, agent_id, agent_name, 5, "QosPublished"),
    )
end

"""
Construct consumer counters for a given agent identity.

Arguments:
- `client`: Aeron client.
- `agent_id`: agent identifier.
- `agent_name`: agent name string.

Returns:
- `ConsumerCounters`.
"""
function ConsumerCounters(client::Aeron.Client, agent_id, agent_name)
    ConsumerCounters(
        Counters(client, agent_id, agent_name),
        add_counter(client, agent_id, agent_name, 3, "DropsGap"),
        add_counter(client, agent_id, agent_name, 4, "DropsLate"),
        add_counter(client, agent_id, agent_name, 5, "DropsOdd"),
        add_counter(client, agent_id, agent_name, 6, "DropsChanged"),
        add_counter(client, agent_id, agent_name, 7, "DropsFrameIdMismatch"),
        add_counter(client, agent_id, agent_name, 8, "DropsHeaderInvalid"),
        add_counter(client, agent_id, agent_name, 9, "DropsPayloadInvalid"),
        add_counter(client, agent_id, agent_name, 10, "Remaps"),
        add_counter(client, agent_id, agent_name, 11, "HelloPublished"),
        add_counter(client, agent_id, agent_name, 12, "QosPublished"),
    )
end

"""
Construct supervisor counters for a given agent identity.

Arguments:
- `client`: Aeron client.
- `agent_id`: agent identifier.
- `agent_name`: agent name string.

Returns:
- `SupervisorCounters`.
"""
function SupervisorCounters(client::Aeron.Client, agent_id, agent_name)
    SupervisorCounters(
        Counters(client, agent_id, agent_name),
        add_counter(client, agent_id, agent_name, 3, "ConfigPublished"),
        add_counter(client, agent_id, agent_name, 4, "LivenessChecks"),
    )
end

"""
Construct driver counters for a given agent identity.

Arguments:
- `client`: Aeron client.
- `agent_id`: agent identifier.
- `agent_name`: agent name string.

Returns:
- `DriverCounters`.
"""
function DriverCounters(client::Aeron.Client, agent_id, agent_name)
    DriverCounters(
        Counters(client, agent_id, agent_name),
        add_counter(client, agent_id, agent_name, 3, "AttachResponses"),
        add_counter(client, agent_id, agent_name, 4, "AttachResponseDrops"),
        add_counter(client, agent_id, agent_name, 5, "DetachResponses"),
        add_counter(client, agent_id, agent_name, 6, "Keepalives"),
        add_counter(client, agent_id, agent_name, 7, "LeaseRevoked"),
        add_counter(client, agent_id, agent_name, 8, "Announces"),
        add_counter(client, agent_id, agent_name, 9, "LeaseHsmUnhandled"),
    )
end

"""
Construct bridge counters for a given agent identity.

Arguments:
- `client`: Aeron client.
- `agent_id`: agent identifier.
- `agent_name`: agent name string.

Returns:
- `BridgeCounters`.
"""
function BridgeCounters(client::Aeron.Client, agent_id, agent_name)
    BridgeCounters(
        Counters(client, agent_id, agent_name),
        add_counter(client, agent_id, agent_name, 3, "FramesForwarded"),
        add_counter(client, agent_id, agent_name, 4, "ChunksSent"),
        add_counter(client, agent_id, agent_name, 5, "ChunksDropped"),
        add_counter(client, agent_id, agent_name, 6, "AssembliesReset"),
        add_counter(client, agent_id, agent_name, 7, "ControlForwarded"),
        add_counter(client, agent_id, agent_name, 8, "FramesRematerialized"),
    )
end

function Base.close(counters::Counters)
    close(counters.total_duty_cycles)
    close(counters.total_work_done)
end

function Base.close(counters::ProducerCounters)
    close(counters.frames_published)
    close(counters.announces)
    close(counters.qos_published)
    close(counters.base)
end

function Base.close(counters::ConsumerCounters)
    close(counters.drops_gap)
    close(counters.drops_late)
    close(counters.drops_odd)
    close(counters.drops_changed)
    close(counters.drops_frame_id_mismatch)
    close(counters.drops_header_invalid)
    close(counters.drops_payload_invalid)
    close(counters.remaps)
    close(counters.hello_published)
    close(counters.qos_published)
    close(counters.base)
end

function Base.close(counters::SupervisorCounters)
    close(counters.config_published)
    close(counters.liveness_checks)
    close(counters.base)
end

function Base.close(counters::DriverCounters)
    close(counters.attach_responses)
    close(counters.attach_response_drops)
    close(counters.detach_responses)
    close(counters.keepalives)
    close(counters.lease_revoked)
    close(counters.announces)
    close(counters.lease_hsm_unhandled)
    close(counters.base)
end

function Base.close(counters::BridgeCounters)
    close(counters.frames_forwarded)
    close(counters.chunks_sent)
    close(counters.chunks_dropped)
    close(counters.assemblies_reset)
    close(counters.control_forwarded)
    close(counters.frames_rematerialized)
    close(counters.base)
end
