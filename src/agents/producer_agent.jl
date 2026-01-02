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
    aeron_ctx::Union{Nothing, Aeron.Context} = nothing,
    aeron_client::Union{Nothing, Aeron.Client} = nothing,
)
    state = init_producer(config; aeron_ctx = aeron_ctx, aeron_client = aeron_client)
    control_assembler = make_control_assembler(state)
    counters = ProducerCounters(state.runtime.client, Int(config.producer_id), "Producer")
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
        close(agent.state.runtime.pub_control)
        close(agent.state.runtime.pub_qos)
        close(agent.state.runtime.pub_metadata)
        close(agent.state.runtime.sub_control)
        agent.state.runtime.owns_client && close(agent.state.runtime.client)
        agent.state.runtime.owns_ctx && close(agent.state.runtime.ctx)
    catch
    end
    return nothing
end
