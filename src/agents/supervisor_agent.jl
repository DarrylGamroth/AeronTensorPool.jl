"""
Agent wrapper for running a SupervisorState with Agent.jl.
"""
struct SupervisorAgent
    state::SupervisorState
    control_assembler::Aeron.FragmentAssembler
    qos_assembler::Aeron.FragmentAssembler
    counters::SupervisorCounters
end

"""
Construct a SupervisorAgent from a SupervisorConfig.
"""
function SupervisorAgent(
    config::SupervisorConfig;
    aeron_ctx::Union{Nothing, Aeron.Context} = nothing,
    aeron_client::Union{Nothing, Aeron.Client} = nothing,
)
    state = init_supervisor(config; aeron_ctx = aeron_ctx, aeron_client = aeron_client)
    control_assembler = make_control_assembler(state)
    qos_assembler = make_qos_assembler(state)
    counters = SupervisorCounters(state.runtime.client, Int(config.stream_id), "Supervisor")
    return SupervisorAgent(state, control_assembler, qos_assembler, counters)
end

Agent.name(agent::SupervisorAgent) = "supervisor"

function Agent.do_work(agent::SupervisorAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = supervisor_do_work!(agent.state, agent.control_assembler, agent.qos_assembler)
    work_done > 0 && Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    agent.counters.config_published[] = Int64(agent.state.config_count)
    agent.counters.liveness_checks[] = Int64(agent.state.liveness_count)
    return work_done
end

function Agent.on_close(agent::SupervisorAgent)
    try
        close(agent.counters)
        close(agent.state.runtime.pub_control)
        close(agent.state.runtime.sub_control)
        close(agent.state.runtime.sub_qos)
        agent.state.runtime.owns_client && close(agent.state.runtime.client)
        agent.state.runtime.owns_ctx && close(agent.state.runtime.ctx)
    catch
    end
    return nothing
end
