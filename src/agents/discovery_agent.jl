module Discovery

using ...Aeron
using ...Agent
using ...Core
using ...Agents
using ...AeronUtils

"""
Agent wrapper for running a DiscoveryProviderState with Agent.jl.
"""
struct DiscoveryAgent
    state::DiscoveryProviderState
    request_assembler::Aeron.FragmentAssembler
    announce_assembler::Aeron.FragmentAssembler
    metadata_assembler::Aeron.FragmentAssembler
end

"""
Construct a DiscoveryAgent from a DiscoveryConfig.

Arguments:
- `config`: discovery configuration.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `DiscoveryAgent` wrapping the discovery provider state and assemblers.
"""
function DiscoveryAgent(config::DiscoveryConfig; client::Aeron.Client)
    state = init_discovery_provider(config; client = client)
    request_assembler = make_request_assembler(state)
    announce_assembler = make_announce_assembler(state)
    metadata_assembler = make_metadata_assembler(state)
    return DiscoveryAgent(state, request_assembler, announce_assembler, metadata_assembler)
end

Agent.name(agent::DiscoveryAgent) = "discovery"

function Agent.do_work(agent::DiscoveryAgent)
    return discovery_do_work!(
        agent.state,
        agent.request_assembler,
        agent.announce_assembler;
        metadata_assembler = agent.metadata_assembler,
    )
end

function Agent.on_close(agent::DiscoveryAgent)
    try
        close(agent.state.runtime.sub_requests)
        close(agent.state.runtime.sub_announce)
        agent.state.runtime.sub_metadata === nothing || close(agent.state.runtime.sub_metadata)
        for pub in values(agent.state.runtime.pubs)
            close(pub)
        end
    catch
    end
    return nothing
end

export DiscoveryAgent

end
