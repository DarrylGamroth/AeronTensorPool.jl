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

Arguments:
- `config`: supervisor configuration.
- `client`: Aeron client to use for publications/subscriptions.
- `hooks`: optional supervisor hooks.

Returns:
- `SupervisorAgent` wrapping the supervisor state and assemblers.
"""
function SupervisorAgent(
    config::SupervisorConfig;
    client::Aeron.Client,
    hooks::SupervisorHooks = NOOP_SUPERVISOR_HOOKS,
)
    state = init_supervisor(config; client = client)
    control_assembler = make_control_assembler(state; hooks = hooks)
    qos_assembler = make_qos_assembler(state; hooks = hooks)
    counters = SupervisorCounters(state.runtime.control.client, Int(config.stream_id), "Supervisor")
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
        close(agent.state.runtime.control.pub_control)
        close(agent.state.runtime.control.sub_control)
        close(agent.state.runtime.sub_qos)
    catch
    end
    return nothing
end
