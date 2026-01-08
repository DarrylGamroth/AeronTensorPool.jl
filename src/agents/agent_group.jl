module AgentGroups

using Agent

"""
Group multiple agents into a single Agent.jl-compatible unit without allocation in `do_work`.
"""
struct AgentGroup{T<:Tuple}
    agents::T
    group_name::String
end

function AgentGroup(agents::Tuple)
    isempty(agents) && throw(ArgumentError("requires at least one sub-agent"))
    names = String[]
    for agent in agents
        agent === nothing && throw(ArgumentError("agent cannot be nothing"))
        push!(names, Agent.name(agent))
    end
    group_name = "[" * join(names, ",") * "]"
    return AgentGroup(agents, group_name)
end

AgentGroup(agents::Vararg{Any}) = AgentGroup(agents)

Agent.name(agent::AgentGroup) = agent.group_name

@inline _do_work_tuple(::Tuple{}) = 0
@inline function _do_work_tuple(agents::Tuple)
    return Agent.do_work(first(agents)) + _do_work_tuple(Base.tail(agents))
end

@inline _on_start_tuple(::Tuple{}) = nothing
@inline function _on_start_tuple(agents::Tuple)
    Agent.on_start(first(agents))
    return _on_start_tuple(Base.tail(agents))
end

@inline _on_close_tuple(::Tuple{}) = nothing
@inline function _on_close_tuple(agents::Tuple)
    Agent.on_close(first(agents))
    return _on_close_tuple(Base.tail(agents))
end

function Agent.do_work(agent::AgentGroup)
    return _do_work_tuple(agent.agents)
end

function Agent.on_start(agent::AgentGroup)
    _on_start_tuple(agent.agents)
    return nothing
end

function Agent.on_close(agent::AgentGroup)
    _on_close_tuple(agent.agents)
    return nothing
end

export AgentGroup

end
