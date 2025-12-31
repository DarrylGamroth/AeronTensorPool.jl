"""
Agent wrapper for running a ConsumerState with Agent.jl.
"""
struct ConsumerAgent
    state::ConsumerState
    descriptor_assembler::Aeron.FragmentAssembler
    control_assembler::Aeron.FragmentAssembler
    counters::ConsumerCounters
end

"""
Construct a ConsumerAgent from a ConsumerConfig.
"""
function ConsumerAgent(config::ConsumerConfig)
    state = init_consumer(config)
    descriptor_assembler = make_descriptor_assembler(state)
    control_assembler = make_control_assembler(state)
    counters = ConsumerCounters(state.runtime.client, Int(config.consumer_id), "Consumer")
    return ConsumerAgent(state, descriptor_assembler, control_assembler, counters)
end

Agent.name(agent::ConsumerAgent) = "consumer"

function Agent.do_work(agent::ConsumerAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = consumer_do_work!(agent.state, agent.descriptor_assembler, agent.control_assembler)
    if work_done > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    end
    agent.counters.drops_gap[] = Int64(agent.state.metrics.drops_gap)
    agent.counters.drops_late[] = Int64(agent.state.metrics.drops_late)
    agent.counters.drops_odd[] = Int64(agent.state.drops_odd)
    agent.counters.drops_changed[] = Int64(agent.state.drops_changed)
    agent.counters.drops_frame_id_mismatch[] = Int64(agent.state.drops_frame_id_mismatch)
    agent.counters.drops_header_invalid[] = Int64(agent.state.drops_header_invalid)
    agent.counters.drops_payload_invalid[] = Int64(agent.state.drops_payload_invalid)
    agent.counters.remaps[] = Int64(agent.state.remap_count)
    agent.counters.hello_published[] = Int64(agent.state.hello_count)
    agent.counters.qos_published[] = Int64(agent.state.metrics.qos_count)
    return work_done
end

function Agent.on_close(agent::ConsumerAgent)
    try
        close(agent.counters)
        close(agent.state.runtime.pub_control)
        close(agent.state.runtime.pub_qos)
        close(agent.state.runtime.sub_descriptor)
        close(agent.state.runtime.sub_control)
        close(agent.state.runtime.sub_qos)
        close(agent.state.runtime.client)
        close(agent.state.runtime.ctx)
    catch
    end
    return nothing
end
