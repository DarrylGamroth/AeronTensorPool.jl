"""
Producer-specific counters (frames, announces, QoS).
"""
struct ProducerCounters
    base::AeronUtils.Counters
    frames_published::Aeron.Counter
    announces::Aeron.Counter
    qos_published::Aeron.Counter
    descriptor_backpressured::Aeron.Counter
    descriptor_not_connected::Aeron.Counter
    descriptor_admin_action::Aeron.Counter
    descriptor_closed::Aeron.Counter
    descriptor_max_position_exceeded::Aeron.Counter
    descriptor_errors::Aeron.Counter
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
        AeronUtils.add_counter(client, agent_id, agent_name, 6, "DescriptorBackpressured"),
        AeronUtils.add_counter(client, agent_id, agent_name, 7, "DescriptorNotConnected"),
        AeronUtils.add_counter(client, agent_id, agent_name, 8, "DescriptorAdminAction"),
        AeronUtils.add_counter(client, agent_id, agent_name, 9, "DescriptorClosed"),
        AeronUtils.add_counter(client, agent_id, agent_name, 10, "DescriptorMaxPositionExceeded"),
        AeronUtils.add_counter(client, agent_id, agent_name, 11, "DescriptorErrors"),
    )
end

function Base.close(counters::ProducerCounters)
    close(counters.frames_published)
    close(counters.announces)
    close(counters.qos_published)
    close(counters.descriptor_backpressured)
    close(counters.descriptor_not_connected)
    close(counters.descriptor_admin_action)
    close(counters.descriptor_closed)
    close(counters.descriptor_max_position_exceeded)
    close(counters.descriptor_errors)
    close(counters.base)
end
