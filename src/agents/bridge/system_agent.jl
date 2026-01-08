"""
Agent wrapper for running multiple bridge mappings with Agent.jl.
"""
struct BridgeSystemAgent
    senders::Vector{BridgeSenderState}
    receivers::Vector{BridgeReceiverState}
    control_assemblers::Vector{Aeron.FragmentAssembler}
    descriptor_assemblers::Vector{Aeron.FragmentAssembler}
    counters::Vector{BridgeCounters}
end

"""
Construct a BridgeSystemAgent from configs and mappings.

Arguments:
- `bridge_config`: bridge configuration.
- `mappings`: list of bridge mappings.
- `consumer_config`: base consumer configuration (stream_id overridden per mapping).
- `producer_config`: base producer configuration (stream_id overridden per mapping).
- `client`: Aeron client to use for publications/subscriptions.
- `callbacks`: optional bridge callbacks.

Returns:
- `BridgeSystemAgent` wrapping per-mapping sender/receiver state.
"""
function BridgeSystemAgent(
    bridge_config::BridgeConfig,
    mappings::Vector{BridgeMapping},
    consumer_config::ConsumerConfig,
    producer_config::ProducerConfig;
    client::Aeron.Client,
    callbacks::BridgeCallbacks = NOOP_BRIDGE_CALLBACKS,
)
    validate_bridge_config(bridge_config, mappings)
    senders = BridgeSenderState[]
    receivers = BridgeReceiverState[]
    control_assemblers = Aeron.FragmentAssembler[]
    descriptor_assemblers = Aeron.FragmentAssembler[]
    counters = BridgeCounters[]
    for mapping in mappings
        consumer_state = Consumer.init_consumer(
            bridge_consumer_settings(consumer_config, mapping);
            client = client,
        )
        producer_state = Producer.init_producer(
            bridge_producer_config(producer_config, mapping);
            client = client,
        )
        sender = init_bridge_sender(consumer_state, bridge_config, mapping; client = client)
        receiver = init_bridge_receiver(bridge_config, mapping; producer_state = producer_state, client = client, callbacks = callbacks)
        push!(senders, sender)
        push!(receivers, receiver)
        push!(control_assemblers, Consumer.make_control_assembler(consumer_state))
        push!(descriptor_assemblers, make_bridge_descriptor_assembler(sender; callbacks = callbacks))
        push!(counters, BridgeCounters(client, Int(mapping.dest_stream_id), "Bridge"))
    end
    return BridgeSystemAgent(senders, receivers, control_assemblers, descriptor_assemblers, counters)
end

Agent.name(agent::BridgeSystemAgent) = "bridge-system"

function Agent.do_work(agent::BridgeSystemAgent)
    work_count = 0
    for i in eachindex(agent.senders)
        sender = agent.senders[i]
        receiver = agent.receivers[i]
        consumer = sender.consumer_state
        local_work = 0
        local_work += Aeron.poll(
            consumer.runtime.control.sub_control,
            agent.control_assemblers[i],
            DEFAULT_FRAGMENT_LIMIT,
        )
        local_work += Aeron.poll(
            consumer.runtime.sub_descriptor,
            agent.descriptor_assemblers[i],
            DEFAULT_FRAGMENT_LIMIT,
        )
        local_work += bridge_sender_do_work!(sender)
        local_work += bridge_receiver_do_work!(receiver)
        work_count += local_work

        counters = agent.counters[i]
        Aeron.increment!(counters.base.total_duty_cycles)
        if local_work > 0
            Aeron.add!(counters.base.total_work_done, Int64(local_work))
        end
        counters.frames_forwarded[] = Int64(sender.metrics.frames_forwarded)
        counters.chunks_sent[] = Int64(sender.metrics.chunks_sent)
        counters.chunks_dropped[] = Int64(sender.metrics.chunks_dropped)
        counters.assemblies_reset[] = Int64(receiver.metrics.assemblies_reset)
        counters.control_forwarded[] = Int64(sender.metrics.control_forwarded + receiver.metrics.control_forwarded)
        counters.frames_rematerialized[] = Int64(receiver.metrics.frames_rematerialized)
    end
    return work_count
end

function Agent.on_close(agent::BridgeSystemAgent)
    try
        for i in eachindex(agent.senders)
            sender = agent.senders[i]
            receiver = agent.receivers[i]
            consumer = sender.consumer_state
            producer = receiver.producer_state
            close(agent.counters[i])

            close(sender.pub_payload)
            close(sender.pub_control)
            sender.pub_metadata === nothing || close(sender.pub_metadata)
            close(sender.sub_control)
            sender.sub_metadata === nothing || close(sender.sub_metadata)

            close(receiver.sub_payload)
            close(receiver.sub_control)
            receiver.sub_metadata === nothing || close(receiver.sub_metadata)
            receiver.pub_metadata_local === nothing || close(receiver.pub_metadata_local)
            receiver.pub_control_local === nothing || close(receiver.pub_control_local)

            close(consumer.runtime.control.pub_control)
            close(consumer.runtime.pub_qos)
            close(consumer.runtime.sub_descriptor)
            close(consumer.runtime.control.sub_control)
            close(consumer.runtime.sub_qos)

            if producer !== nothing
                close(producer.runtime.pub_descriptor)
                close(producer.runtime.control.pub_control)
                close(producer.runtime.pub_qos)
                close(producer.runtime.pub_metadata)
                close(producer.runtime.control.sub_control)
            end
        end
    catch
    end
    return nothing
end

export BridgeSystemAgent
