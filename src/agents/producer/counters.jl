"""
Producer-specific counters (frames, announces, QoS).
"""
struct ProducerCounters
    base::AeronUtils.Counters
    frames_published::Aeron.Counter
    announces::Aeron.Counter
    qos_published::Aeron.Counter
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
        AeronUtils.Counters(client, agent_id, agent_name),
        AeronUtils.add_counter(client, agent_id, agent_name, 3, "FramesPublished"),
        AeronUtils.add_counter(client, agent_id, agent_name, 4, "AnnouncesPublished"),
        AeronUtils.add_counter(client, agent_id, agent_name, 5, "QosPublished"),
    )
end

function Base.close(counters::ProducerCounters)
    close(counters.frames_published)
    close(counters.announces)
    close(counters.qos_published)
    close(counters.base)
end
