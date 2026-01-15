"""
Bridge-specific counters (rematerialized frames).
"""
struct BridgeCounters
    base::AeronUtils.Counters
    frames_forwarded::Aeron.Counter
    chunks_sent::Aeron.Counter
    chunks_dropped::Aeron.Counter
    assemblies_reset::Aeron.Counter
    control_forwarded::Aeron.Counter
    frames_rematerialized::Aeron.Counter
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
        AeronUtils.Counters(client, agent_id, agent_name),
        AeronUtils.add_counter(client, agent_id, agent_name, 3, "FramesForwarded"),
        AeronUtils.add_counter(client, agent_id, agent_name, 4, "ChunksSent"),
        AeronUtils.add_counter(client, agent_id, agent_name, 5, "ChunksDropped"),
        AeronUtils.add_counter(client, agent_id, agent_name, 6, "AssembliesReset"),
        AeronUtils.add_counter(client, agent_id, agent_name, 7, "ControlForwarded"),
        AeronUtils.add_counter(client, agent_id, agent_name, 8, "FramesRematerialized"),
    )
end

function Base.close(counters::BridgeCounters)
    AeronUtils.close_counter!(counters.frames_forwarded)
    AeronUtils.close_counter!(counters.chunks_sent)
    AeronUtils.close_counter!(counters.chunks_dropped)
    AeronUtils.close_counter!(counters.assemblies_reset)
    AeronUtils.close_counter!(counters.control_forwarded)
    AeronUtils.close_counter!(counters.frames_rematerialized)
    close(counters.base)
end
