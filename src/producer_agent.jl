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
function ProducerAgent(config::ProducerConfig)
    state = init_producer(config)
    control_assembler = make_control_assembler(state)
    counters = ProducerCounters(state.client, Int(config.producer_id), "Producer")
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
    agent.counters.announces[] = Int64(agent.state.announce_count)
    agent.counters.qos_published[] = Int64(agent.state.qos_count)
    return work_done
end

function Agent.on_close(agent::ProducerAgent)
    try
        close(agent.counters)
        close(agent.state.pub_descriptor)
        close(agent.state.pub_control)
        close(agent.state.pub_qos)
        close(agent.state.pub_metadata)
        close(agent.state.sub_control)
        close(agent.state.client)
        close(agent.state.ctx)
    catch
    end
    return nothing
end
