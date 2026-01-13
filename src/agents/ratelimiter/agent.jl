"""
Agent wrapper for running a RateLimiterState with Agent.jl.
"""
struct RateLimiterAgent
    state::RateLimiterState
end

Agent.name(::RateLimiterAgent) = "rate-limiter"

function Agent.do_work(agent::RateLimiterAgent)
    return rate_limiter_do_work!(agent.state)
end

function Agent.on_close(agent::RateLimiterAgent)
    for mapping in agent.state.mappings
        Agent.on_close(mapping.consumer_agent)
        Agent.on_close(mapping.producer_agent)
        mapping.metadata_pub === nothing || close(mapping.metadata_pub)
    end
    if agent.state.metadata_sub !== nothing
        close(agent.state.metadata_sub)
    end
    if agent.state.metadata_pub !== nothing
        close(agent.state.metadata_pub)
    end
    if agent.state.control_sub !== nothing
        close(agent.state.control_sub)
    end
    if agent.state.control_pub !== nothing
        close(agent.state.control_pub)
    end
    if agent.state.qos_sub !== nothing
        close(agent.state.qos_sub)
    end
    if agent.state.qos_pub !== nothing
        close(agent.state.qos_pub)
    end
    return nothing
end
