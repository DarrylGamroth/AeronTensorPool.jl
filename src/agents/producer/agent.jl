"""
Agent wrapper for running a ProducerState with Agent.jl.
"""
struct ProducerAgent
    state::ProducerState
    control_assembler::Aeron.FragmentAssembler
    qos_assembler::Aeron.FragmentAssembler
    counters::ProducerCounters
    callbacks::ProducerCallbacks
    qos_monitor::Union{AbstractQosMonitor, Nothing}
    qos_timer::PolledTimer
end

"""
Construct a ProducerAgent from a ProducerConfig.

Arguments:
- `config`: producer configuration.
- `client`: Aeron client to use for publications/subscriptions.
- `callbacks`: optional producer callbacks.

Returns:
- `ProducerAgent` wrapping the producer state and assemblers.
"""
function ProducerAgent(
    config::ProducerConfig;
    client::Aeron.Client,
    callbacks::ProducerCallbacks = NOOP_PRODUCER_CALLBACKS,
    qos_monitor::Union{AbstractQosMonitor, Nothing} = nothing,
    qos_interval_ns::UInt64 = config.qos_interval_ns,
)
    state = init_producer(config; client = client)
    control_assembler = make_control_assembler(state; callbacks = callbacks)
    qos_assembler = make_qos_assembler(state; callbacks = callbacks)
    counters = ProducerCounters(state.runtime.control.client, Int(config.producer_id), "Producer")
    return ProducerAgent(
        state,
        control_assembler,
        qos_assembler,
        counters,
        callbacks,
        qos_monitor,
        PolledTimer(qos_interval_ns),
    )
end

Agent.name(agent::ProducerAgent) = "producer"

function Agent.do_work(agent::ProducerAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = producer_do_work!(agent.state, agent.control_assembler, agent.qos_assembler)
    if work_done > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    end
    agent.counters.frames_published[] = Int64(agent.state.seq)
    agent.counters.announces[] = Int64(agent.state.metrics.announce_count)
    agent.counters.qos_published[] = Int64(agent.state.metrics.qos_count)
    if agent.qos_monitor !== nothing
        now_ns = UInt64(Clocks.time_nanos(agent.state.clock))
        if expired(agent.qos_timer, now_ns)
            Core.poll_qos!(agent.qos_monitor)
            snapshot = Core.producer_qos(agent.qos_monitor, agent.state.config.producer_id)
            if snapshot !== nothing
                agent.callbacks.on_qos_producer!(agent.state, snapshot)
            end
            reset!(agent.qos_timer, now_ns)
        end
    end
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
        close(agent.state.runtime.sub_qos)
        agent.qos_monitor === nothing || close(agent.qos_monitor)
        for entry in values(agent.state.consumer_streams)
            entry.descriptor_pub === nothing || close(entry.descriptor_pub)
            entry.control_pub === nothing || close(entry.control_pub)
        end
    catch
    end
    return nothing
end

export ProducerAgent
