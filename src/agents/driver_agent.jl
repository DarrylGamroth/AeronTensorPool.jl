"""
Agent wrapper for running a DriverState with Agent.jl.
"""
struct DriverAgent
    state::DriverState
    counters::DriverCounters
end

"""
Construct a DriverAgent from a DriverConfig.
"""
function DriverAgent(config::DriverConfig; agent_id::Int = 0)
    state = init_driver(config)
    counters = DriverCounters(state.runtime.client, agent_id, "Driver")
    return DriverAgent(state, counters)
end

Agent.name(agent::DriverAgent) = "driver"

function Agent.do_work(agent::DriverAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = driver_do_work!(agent.state)
    if work_done > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    end
    agent.counters.attach_responses[] = Int64(agent.state.metrics.attach_responses)
    agent.counters.detach_responses[] = Int64(agent.state.metrics.detach_responses)
    agent.counters.keepalives[] = Int64(agent.state.metrics.keepalives)
    agent.counters.lease_revoked[] = Int64(agent.state.metrics.lease_revoked)
    agent.counters.announces[] = Int64(agent.state.metrics.announces)
    return work_done
end

function Agent.on_close(agent::DriverAgent)
    try
        emit_driver_shutdown!(agent.state)
        close(agent.counters)
        close(agent.state.runtime.pub_control)
        close(agent.state.runtime.pub_announce)
        close(agent.state.runtime.pub_qos)
        close(agent.state.runtime.sub_control)
        close(agent.state.runtime.client)
        close(agent.state.runtime.ctx)
    catch
    end
    return nothing
end
