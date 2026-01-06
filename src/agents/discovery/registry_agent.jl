"""
Agent wrapper for running a DiscoveryRegistryState with Agent.jl.
"""
struct DiscoveryRegistryAgent
    state::DiscoveryRegistryState
    request_assembler::Aeron.FragmentAssembler
    announce_assemblers::Vector{Aeron.FragmentAssembler}
    metadata_assemblers::Vector{Aeron.FragmentAssembler}
end

"""
Construct a DiscoveryRegistryAgent from a DiscoveryRegistryConfig.

Arguments:
- `config`: discovery registry configuration.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `DiscoveryRegistryAgent` wrapping the discovery registry state and assemblers.
"""
function DiscoveryRegistryAgent(config::DiscoveryRegistryConfig; client::Aeron.Client)
    state = init_discovery_registry(config; client = client)
    request_assembler = make_request_assembler(state)
    announce_assemblers =
        [make_registry_announce_assembler(state, ep) for ep in config.endpoints]
    metadata_assemblers =
        [make_registry_metadata_assembler(state, ep) for ep in config.endpoints]
    return DiscoveryRegistryAgent(state, request_assembler, announce_assemblers, metadata_assemblers)
end

Agent.name(agent::DiscoveryRegistryAgent) = "discovery_registry"

function Agent.do_work(agent::DiscoveryRegistryAgent)
    return discovery_registry_do_work!(
        agent.state,
        agent.request_assembler,
        agent.announce_assemblers,
        agent.metadata_assemblers,
    )
end

function Agent.on_close(agent::DiscoveryRegistryAgent)
    try
        close(agent.state.runtime.sub_requests)
        for sub in agent.state.runtime.announce_subs
            close(sub)
        end
        for sub in agent.state.runtime.metadata_subs
            sub === nothing || close(sub)
        end
        for pub in values(agent.state.runtime.pubs)
            close(pub)
        end
    catch
    end
    return nothing
end

export DiscoveryRegistryAgent
