"""
Driver-specific counters (attach, detach, keepalive, revoke, announce).
"""
struct DriverCounters
    base::AeronUtils.Counters
    attach_responses::Aeron.Counter
    attach_response_drops::Aeron.Counter
    detach_responses::Aeron.Counter
    keepalives::Aeron.Counter
    lease_revoked::Aeron.Counter
    announces::Aeron.Counter
    lease_hsm_unhandled::Aeron.Counter
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
        AeronUtils.Counters(client, agent_id, agent_name),
        AeronUtils.add_counter(client, agent_id, agent_name, 3, "AttachResponses"),
        AeronUtils.add_counter(client, agent_id, agent_name, 4, "AttachResponseDrops"),
        AeronUtils.add_counter(client, agent_id, agent_name, 5, "DetachResponses"),
        AeronUtils.add_counter(client, agent_id, agent_name, 6, "Keepalives"),
        AeronUtils.add_counter(client, agent_id, agent_name, 7, "LeaseRevoked"),
        AeronUtils.add_counter(client, agent_id, agent_name, 8, "Announces"),
        AeronUtils.add_counter(client, agent_id, agent_name, 9, "LeaseHsmUnhandled"),
    )
end

function Base.close(counters::DriverCounters)
    AeronUtils.close_counter!(counters.attach_responses)
    AeronUtils.close_counter!(counters.attach_response_drops)
    AeronUtils.close_counter!(counters.detach_responses)
    AeronUtils.close_counter!(counters.keepalives)
    AeronUtils.close_counter!(counters.lease_revoked)
    AeronUtils.close_counter!(counters.announces)
    AeronUtils.close_counter!(counters.lease_hsm_unhandled)
    close(counters.base)
end
