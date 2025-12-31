struct ProducerAgent
    state::ProducerState
    control_assembler::Aeron.FragmentAssembler
    counters::ProducerCounters
end

struct ConsumerAgent
    state::ConsumerState
    descriptor_assembler::Aeron.FragmentAssembler
    control_assembler::Aeron.FragmentAssembler
    counters::ConsumerCounters
end

struct SupervisorAgent
    state::SupervisorState
    control_assembler::Aeron.FragmentAssembler
    qos_assembler::Aeron.FragmentAssembler
    counters::SupervisorCounters
end

function ProducerAgent(config::ProducerConfig)
    state = init_producer(config)
    control_assembler = make_control_assembler(state)
    counters = ProducerCounters(state.client, Int(config.producer_id), "Producer")
    return ProducerAgent(state, control_assembler, counters)
end

function ConsumerAgent(config::ConsumerConfig)
    state = init_consumer(config)
    descriptor_assembler = make_descriptor_assembler(state)
    control_assembler = make_control_assembler(state)
    counters = ConsumerCounters(state.client, Int(config.consumer_id), "Consumer")
    return ConsumerAgent(state, descriptor_assembler, control_assembler, counters)
end

function SupervisorAgent(config::SupervisorConfig)
    state = init_supervisor(config)
    control_assembler = make_control_assembler(state)
    qos_assembler = make_qos_assembler(state)
    counters = SupervisorCounters(state.client, Int(config.stream_id), "Supervisor")
    return SupervisorAgent(state, control_assembler, qos_assembler, counters)
end

Agent.name(agent::ProducerAgent) = "producer"
Agent.name(agent::ConsumerAgent) = "consumer"
Agent.name(agent::SupervisorAgent) = "supervisor"

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

function Agent.do_work(agent::ConsumerAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = consumer_do_work!(agent.state, agent.descriptor_assembler, agent.control_assembler)
    if work_done > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    end
    agent.counters.drops_gap[] = Int64(agent.state.drops_gap)
    agent.counters.drops_late[] = Int64(agent.state.drops_late)
    agent.counters.drops_odd[] = Int64(agent.state.drops_odd)
    agent.counters.drops_changed[] = Int64(agent.state.drops_changed)
    agent.counters.drops_frame_id_mismatch[] = Int64(agent.state.drops_frame_id_mismatch)
    agent.counters.drops_header_invalid[] = Int64(agent.state.drops_header_invalid)
    agent.counters.drops_payload_invalid[] = Int64(agent.state.drops_payload_invalid)
    agent.counters.remaps[] = Int64(agent.state.remap_count)
    agent.counters.hello_published[] = Int64(agent.state.hello_emits)
    agent.counters.qos_published[] = Int64(agent.state.qos_emits)
    return work_done
end

function Agent.do_work(agent::SupervisorAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = supervisor_do_work!(agent.state, agent.control_assembler, agent.qos_assembler)
    work_done > 0 && Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    agent.counters.config_published[] = Int64(agent.state.config_emits)
    agent.counters.liveness_checks[] = Int64(agent.state.liveness_checks)
    return work_done
end

@inline function safe_close(obj)
    try
        close(obj)
    catch
    end
    return nothing
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

function Agent.on_close(agent::ConsumerAgent)
    safe_close(agent.counters)
    safe_close(agent.state.pub_control)
    safe_close(agent.state.pub_qos)
    safe_close(agent.state.sub_descriptor)
    safe_close(agent.state.sub_control)
    safe_close(agent.state.sub_qos)
    safe_close(agent.state.client)
    return nothing
end

function Agent.on_close(agent::SupervisorAgent)
    safe_close(agent.counters)
    safe_close(agent.state.pub_control)
    safe_close(agent.state.sub_control)
    safe_close(agent.state.sub_qos)
    safe_close(agent.state.client)
    return nothing
end
