"""
Agent wrapper for running a ProducerState with Agent.jl.
"""
struct ProducerAgent
    state::ProducerState
    control_assembler::Aeron.FragmentAssembler
    counters::ProducerCounters
end

"""
Construct a ProducerAgent from a ProducerConfig.
"""
function ProducerAgent(
    config::ProducerConfig;
    client::Aeron.Client,
)
    state = init_producer(config; client = client)
    control_assembler = make_control_assembler(state)
    counters = ProducerCounters(state.runtime.control.client, Int(config.producer_id), "Producer")
    return ProducerAgent(state, control_assembler, counters)
end

Agent.name(agent::ProducerAgent) = "producer"

function Agent.do_work(agent::ProducerAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = producer_do_work!(agent.state, agent.control_assembler)
    if work_done > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    end
    agent.counters.frames_published[] = Int64(agent.state.seq)
    agent.counters.announces[] = Int64(agent.state.metrics.announce_count)
    agent.counters.qos_published[] = Int64(agent.state.metrics.qos_count)
    return work_done
end

function Agent.on_close(agent::ProducerAgent)
    try
        close(agent.counters)
        close(agent.state.runtime.pub_descriptor)
        close(agent.state.runtime.control.pub_control)
        close(agent.state.runtime.pub_qos)
        close(agent.state.runtime.pub_metadata)
        close(agent.state.runtime.control.sub_control)
    catch
    end
    return nothing
end
