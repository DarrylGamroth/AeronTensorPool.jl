"""
Agent wrapper for running a ConsumerState with Agent.jl.
"""
struct ConsumerAgent
    state::ConsumerState
    descriptor_assembler::Aeron.FragmentAssembler
    control_assembler::Aeron.FragmentAssembler
    counters::ConsumerCounters
    closed::Base.RefValue{Bool}
end

"""
Construct a ConsumerAgent from a ConsumerConfig.

Arguments:
- `config`: consumer settings.
- `client`: TensorPool client (owns Aeron resources).
- `callbacks`: optional consumer callbacks.

Returns:
- `ConsumerAgent` wrapping the consumer state and assemblers.
"""
function ConsumerAgent(
    config::ConsumerConfig;
    client::AbstractTensorPoolClient,
    callbacks::ConsumerCallbacks = NOOP_CONSUMER_CALLBACKS,
)
    state = init_consumer(config; client = client)
    descriptor_assembler = make_descriptor_assembler(state; callbacks = callbacks)
    control_assembler = make_control_assembler(state)
    counters = ConsumerCounters(state.runtime.control.client, Int(config.consumer_id), "Consumer")
    return ConsumerAgent(state, descriptor_assembler, control_assembler, counters, Ref(false))
end

Agent.name(agent::ConsumerAgent) = "consumer"

ConsumerAgent(
    state::ConsumerState,
    descriptor_assembler::Aeron.FragmentAssembler,
    control_assembler::Aeron.FragmentAssembler,
    counters::ConsumerCounters,
) = ConsumerAgent(state, descriptor_assembler, control_assembler, counters, Ref(false))

function Agent.do_work(agent::ConsumerAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_done = consumer_do_work!(agent.state, agent.descriptor_assembler, agent.control_assembler)
    if work_done > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_done))
    end
    AeronUtils.set_counter!(
        agent.counters.drops_gap,
        Int64(agent.state.metrics.drops_gap),
        :consumer_drops_gap,
    )
    AeronUtils.set_counter!(
        agent.counters.drops_late,
        Int64(agent.state.metrics.drops_late),
        :consumer_drops_late,
    )
    AeronUtils.set_counter!(
        agent.counters.drops_odd,
        Int64(agent.state.metrics.drops_odd),
        :consumer_drops_odd,
    )
    AeronUtils.set_counter!(
        agent.counters.drops_changed,
        Int64(agent.state.metrics.drops_changed),
        :consumer_drops_changed,
    )
    AeronUtils.set_counter!(
        agent.counters.drops_frame_id_mismatch,
        Int64(agent.state.metrics.drops_frame_id_mismatch),
        :consumer_drops_frame_id_mismatch,
    )
    AeronUtils.set_counter!(
        agent.counters.drops_header_invalid,
        Int64(agent.state.metrics.drops_header_invalid),
        :consumer_drops_header_invalid,
    )
    AeronUtils.set_counter!(
        agent.counters.drops_payload_invalid,
        Int64(agent.state.metrics.drops_payload_invalid),
        :consumer_drops_payload_invalid,
    )
    AeronUtils.set_counter!(
        agent.counters.remaps,
        Int64(agent.state.metrics.remap_count),
        :consumer_remaps,
    )
    AeronUtils.set_counter!(
        agent.counters.hello_published,
        Int64(agent.state.metrics.hello_count),
        :consumer_hello_published,
    )
    AeronUtils.set_counter!(
        agent.counters.qos_published,
        Int64(agent.state.metrics.qos_count),
        :consumer_qos_published,
    )
    return work_done
end

function Agent.on_close(agent::ConsumerAgent)
    agent.closed[] && return nothing
    agent.closed[] = true
    try
        close(agent.counters)
        close(agent.state.runtime.control.pub_control)
        close(agent.state.runtime.pub_qos)
        close(agent.state.runtime.sub_descriptor)
        close(agent.state.runtime.control.sub_control)
        close(agent.state.runtime.sub_qos)
        agent.state.runtime.sub_progress === nothing || close(agent.state.runtime.sub_progress)
    catch
    end
    return nothing
end

export ConsumerAgent
