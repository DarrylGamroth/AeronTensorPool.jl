"""
Supervisor-specific counters (config publishes and liveness checks).
"""
struct SupervisorCounters
    base::AeronUtils.Counters
    config_published::Aeron.Counter
    liveness_checks::Aeron.Counter
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
        AeronUtils.Counters(client, agent_id, agent_name),
        AeronUtils.add_counter(client, agent_id, agent_name, 3, "ConfigPublished"),
        AeronUtils.add_counter(client, agent_id, agent_name, 4, "LivenessChecks"),
    )
end

function Base.close(counters::SupervisorCounters)
    AeronUtils.close_counter!(counters.config_published)
    AeronUtils.close_counter!(counters.liveness_checks)
    close(counters.base)
end
