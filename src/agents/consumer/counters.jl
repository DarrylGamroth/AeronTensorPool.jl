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
    drops_epoch_mismatch::Aeron.Counter
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
        AeronUtils.add_counter(client, agent_id, agent_name, 13, "DropsEpochMismatch"),
        AeronUtils.add_counter(client, agent_id, agent_name, 8, "DropsHeaderInvalid"),
        AeronUtils.add_counter(client, agent_id, agent_name, 9, "DropsPayloadInvalid"),
        AeronUtils.add_counter(client, agent_id, agent_name, 10, "Remaps"),
        AeronUtils.add_counter(client, agent_id, agent_name, 11, "HelloPublished"),
        AeronUtils.add_counter(client, agent_id, agent_name, 12, "QosPublished"),
    )
end

function Base.close(counters::ConsumerCounters)
    close(counters.drops_gap)
    close(counters.drops_late)
    close(counters.drops_odd)
    close(counters.drops_changed)
    close(counters.drops_frame_id_mismatch)
    close(counters.drops_epoch_mismatch)
    close(counters.drops_header_invalid)
    close(counters.drops_payload_invalid)
    close(counters.remaps)
    close(counters.hello_published)
    close(counters.qos_published)
    close(counters.base)
end
