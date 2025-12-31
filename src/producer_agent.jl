struct ProducerAgent
    state::ProducerState
    control_assembler::Aeron.FragmentAssembler
    counters::ProducerCounters
end

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
    agent.counters.announces[] = Int64(agent.state.announce_emits)
    agent.counters.qos_published[] = Int64(agent.state.qos_emits)
    return work_done
end

function Agent.on_close(agent::ProducerAgent)
    safe_close(agent.counters)
    safe_close(agent.state.pub_descriptor)
    safe_close(agent.state.pub_control)
    safe_close(agent.state.pub_qos)
    safe_close(agent.state.pub_metadata)
    safe_close(agent.state.sub_control)
    safe_close(agent.state.client)
    return nothing
end
