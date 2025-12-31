struct ProducerAgent
    state::ProducerState
    control_assembler::Aeron.FragmentAssembler
end

struct ConsumerAgent
    state::ConsumerState
    descriptor_assembler::Aeron.FragmentAssembler
    control_assembler::Aeron.FragmentAssembler
end

struct SupervisorAgent
    state::SupervisorState
    control_assembler::Aeron.FragmentAssembler
    qos_assembler::Aeron.FragmentAssembler
end

function ProducerAgent(config::ProducerConfig)
    state = init_producer(config)
    control_assembler = make_control_assembler(state)
    return ProducerAgent(state, control_assembler)
end

function ConsumerAgent(config::ConsumerConfig)
    state = init_consumer(config)
    descriptor_assembler = make_descriptor_assembler(state)
    control_assembler = make_control_assembler(state)
    return ConsumerAgent(state, descriptor_assembler, control_assembler)
end

function SupervisorAgent(config::SupervisorConfig)
    state = init_supervisor(config)
    control_assembler = make_control_assembler(state)
    qos_assembler = make_qos_assembler(state)
    return SupervisorAgent(state, control_assembler, qos_assembler)
end

Agent.name(agent::ProducerAgent) = "producer"
Agent.name(agent::ConsumerAgent) = "consumer"
Agent.name(agent::SupervisorAgent) = "supervisor"

function Agent.do_work(agent::ProducerAgent)
    return producer_do_work!(agent.state, agent.control_assembler)
end

function Agent.do_work(agent::ConsumerAgent)
    return consumer_do_work!(agent.state, agent.descriptor_assembler, agent.control_assembler)
end

function Agent.do_work(agent::SupervisorAgent)
    return supervisor_do_work!(agent.state, agent.control_assembler, agent.qos_assembler)
end

@inline function safe_close(obj)
    try
        close(obj)
    catch
    end
    return nothing
end

function Agent.on_close(agent::ProducerAgent)
    safe_close(agent.state.pub_descriptor)
    safe_close(agent.state.pub_control)
    safe_close(agent.state.pub_qos)
    safe_close(agent.state.pub_metadata)
    safe_close(agent.state.sub_control)
    safe_close(agent.state.client)
    return nothing
end

function Agent.on_close(agent::ConsumerAgent)
    safe_close(agent.state.pub_control)
    safe_close(agent.state.pub_qos)
    safe_close(agent.state.sub_descriptor)
    safe_close(agent.state.sub_control)
    safe_close(agent.state.sub_qos)
    safe_close(agent.state.client)
    return nothing
end

function Agent.on_close(agent::SupervisorAgent)
    safe_close(agent.state.pub_control)
    safe_close(agent.state.sub_control)
    safe_close(agent.state.sub_qos)
    safe_close(agent.state.client)
    return nothing
end
