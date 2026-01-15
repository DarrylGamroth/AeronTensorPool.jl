"""
Consumer-specific counters (drops, remaps, hello, QoS).
"""
struct ConsumerCounters
    base::AeronUtils.Counters
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
        AeronUtils.Counters(client, agent_id, agent_name),
        AeronUtils.add_counter(client, agent_id, agent_name, 3, "DropsGap"),
        AeronUtils.add_counter(client, agent_id, agent_name, 4, "DropsLate"),
        AeronUtils.add_counter(client, agent_id, agent_name, 5, "DropsOdd"),
        AeronUtils.add_counter(client, agent_id, agent_name, 6, "DropsChanged"),
        AeronUtils.add_counter(client, agent_id, agent_name, 7, "DropsFrameIdMismatch"),
        AeronUtils.add_counter(client, agent_id, agent_name, 8, "DropsHeaderInvalid"),
        AeronUtils.add_counter(client, agent_id, agent_name, 9, "DropsPayloadInvalid"),
        AeronUtils.add_counter(client, agent_id, agent_name, 10, "Remaps"),
        AeronUtils.add_counter(client, agent_id, agent_name, 11, "HelloPublished"),
        AeronUtils.add_counter(client, agent_id, agent_name, 12, "QosPublished"),
    )
end

function Base.close(counters::ConsumerCounters)
    AeronUtils.close_counter!(counters.drops_gap)
    AeronUtils.close_counter!(counters.drops_late)
    AeronUtils.close_counter!(counters.drops_odd)
    AeronUtils.close_counter!(counters.drops_changed)
    AeronUtils.close_counter!(counters.drops_frame_id_mismatch)
    AeronUtils.close_counter!(counters.drops_header_invalid)
    AeronUtils.close_counter!(counters.drops_payload_invalid)
    AeronUtils.close_counter!(counters.remaps)
    AeronUtils.close_counter!(counters.hello_published)
    AeronUtils.close_counter!(counters.qos_published)
    close(counters.base)
end
