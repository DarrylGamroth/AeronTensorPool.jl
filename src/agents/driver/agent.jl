"""
Agent wrapper for running a DriverState with Agent.jl.
"""
struct DriverAgent
    state::DriverState
    counters::DriverCounters
end

"""
Construct a DriverAgent from a DriverConfig.

Arguments:
- `config`: driver configuration.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `DriverAgent` wrapping the driver state.
"""
function DriverAgent(
    config::DriverConfig;
    agent_id::Int = 0,
    client::Aeron.Client,
)
    state = init_driver(config; client = client)
    counters = DriverCounters(state.runtime.control.client, agent_id, "Driver")
    return DriverAgent(state, counters)
end

Agent.name(agent::DriverAgent) = "driver"

function Agent.on_start(agent::DriverAgent)
    register_driver!(agent.state)
    return nothing
end

function Agent.do_work(agent::DriverAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = driver_do_work!(agent.state)
    if work_done > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    end
    agent.counters.attach_responses[] = Int64(agent.state.metrics.attach_responses)
    agent.counters.attach_response_drops[] = Int64(agent.state.metrics.attach_response_drops)
    agent.counters.detach_responses[] = Int64(agent.state.metrics.detach_responses)
    agent.counters.keepalives[] = Int64(agent.state.metrics.keepalives)
    agent.counters.lease_revoked[] = Int64(agent.state.metrics.lease_revoked)
    agent.counters.announces[] = Int64(agent.state.metrics.announces)
    agent.counters.lease_hsm_unhandled[] = Int64(agent.state.metrics.lease_hsm_unhandled)
    return work_done
end

function Agent.on_close(agent::DriverAgent)
    try
        fetch!(agent.state.clock)
        driver_lifecycle_dispatch!(agent.state, :ShutdownRequested)
        driver_lifecycle_dispatch!(agent.state, :ShutdownTimeout)
        cleanup_shm_on_exit!(agent.state)
        unregister_driver!(agent.state)
        close(agent.counters)
        close(agent.state.runtime.control.pub_control)
        close(agent.state.runtime.pub_announce)
        close(agent.state.runtime.pub_qos)
        close(agent.state.runtime.control.sub_control)
    catch
    end
    return nothing
end

export DriverAgent
