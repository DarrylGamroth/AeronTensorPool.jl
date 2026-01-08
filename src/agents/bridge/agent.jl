"""
Agent wrapper for running a bridge sender/receiver with Agent.jl.
"""
struct BridgeAgent
    sender::BridgeSenderState
    receiver::BridgeReceiverState
    control_assembler::Aeron.FragmentAssembler
    descriptor_assembler::Aeron.FragmentAssembler
    counters::BridgeCounters
end

function bridge_consumer_settings(config::ConsumerConfig, mapping::BridgeMapping)
    return ConsumerConfig(
        config.aeron_dir,
        config.aeron_uri,
        config.descriptor_stream_id,
        config.control_stream_id,
        config.qos_stream_id,
        mapping.source_stream_id,
        config.consumer_id,
        config.expected_layout_version,
        config.max_dims,
        config.mode,
        config.max_outstanding_seq_gap,
        config.use_shm,
        config.supports_shm,
        config.supports_progress,
        config.max_rate_hz,
        config.payload_fallback_uri,
        config.shm_base_dir,
        config.allowed_base_dirs,
        config.require_hugepages,
        config.progress_interval_us,
        config.progress_bytes_delta,
        config.progress_major_delta_units,
        config.hello_interval_ns,
        config.qos_interval_ns,
        config.announce_freshness_ns,
        config.requested_descriptor_channel,
        config.requested_descriptor_stream_id,
        config.requested_control_channel,
        config.requested_control_stream_id,
        config.mlock_shm,
    )
end

function bridge_producer_config(config::ProducerConfig, mapping::BridgeMapping)
    return ProducerConfig(
        config.aeron_dir,
        config.aeron_uri,
        config.descriptor_stream_id,
        config.control_stream_id,
        config.qos_stream_id,
        config.metadata_stream_id,
        mapping.dest_stream_id,
        config.producer_id,
        config.layout_version,
        config.nslots,
        config.shm_base_dir,
        config.shm_namespace,
        config.producer_instance_id,
        config.header_uri,
        config.payload_pools,
        config.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        config.mlock_shm,
    )
end

"""
Create a descriptor assembler that forwards frames to the bridge sender.

Arguments:
- `state`: bridge sender state.
- `hooks`: optional bridge hooks.
"""
function make_bridge_descriptor_assembler(state::BridgeSenderState; hooks::BridgeHooks = NOOP_BRIDGE_HOOKS)
    decoder = FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
            FrameDescriptor.wrap!(decoder, buffer, 0; header = header)
            bridge_send_frame!(st, decoder)
            hooks.on_send_frame!(st, decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Construct a BridgeAgent from configs and mapping.

Arguments:
- `consumer_state`: consumer state providing SHM mappings.
- `config`: bridge configuration.
- `mapping`: bridge mapping definition.
- `producer_state`: optional producer state for rematerialization.
- `client`: Aeron client to use for publications/subscriptions.
- `hooks`: optional bridge hooks.

Returns:
- `BridgeAgent` wrapping sender/receiver states and assemblers.
"""
function BridgeAgent(
    bridge_config::BridgeConfig,
    mapping::BridgeMapping,
    consumer_config::ConsumerConfig,
    producer_config::ProducerConfig;
    client::Aeron.Client,
    hooks::BridgeHooks = NOOP_BRIDGE_HOOKS,
)
    validate_bridge_config(bridge_config, [mapping])
    consumer_state = Consumer.init_consumer(
        bridge_consumer_settings(consumer_config, mapping);
        client = client,
    )
    producer_state = Producer.init_producer(
        bridge_producer_config(producer_config, mapping);
        client = client,
    )
    sender = init_bridge_sender(
        consumer_state,
        bridge_config,
        mapping;
        client = client,
    )
    receiver = init_bridge_receiver(
        bridge_config,
        mapping;
        producer_state = producer_state,
        client = client,
        hooks = hooks,
    )

    control_assembler = Consumer.make_control_assembler(consumer_state)
    descriptor_assembler = make_bridge_descriptor_assembler(sender; hooks = hooks)
    counters = BridgeCounters(sender.client, Int(mapping.dest_stream_id), "Bridge")

    return BridgeAgent(sender, receiver, control_assembler, descriptor_assembler, counters)
end

Agent.name(agent::BridgeAgent) = "bridge"

function Agent.do_work(agent::BridgeAgent)
    Aeron.increment!(agent.counters.base.total_duty_cycles)
    work_count = 0
    consumer = agent.sender.consumer_state
    work_count += Aeron.poll(
        consumer.runtime.control.sub_control,
        agent.control_assembler,
        DEFAULT_FRAGMENT_LIMIT,
    )
    work_count += Aeron.poll(consumer.runtime.sub_descriptor, agent.descriptor_assembler, DEFAULT_FRAGMENT_LIMIT)
    work_count += bridge_sender_do_work!(agent.sender)
    work_count += bridge_receiver_do_work!(agent.receiver)
    if work_count > 0
        Aeron.add!(agent.counters.base.total_work_done, Int64(work_count))
    end
    agent.counters.frames_forwarded[] = Int64(agent.sender.metrics.frames_forwarded)
    agent.counters.chunks_sent[] = Int64(agent.sender.metrics.chunks_sent)
    agent.counters.chunks_dropped[] = Int64(agent.sender.metrics.chunks_dropped)
    agent.counters.assemblies_reset[] = Int64(agent.receiver.metrics.assemblies_reset)
    agent.counters.control_forwarded[] = Int64(agent.sender.metrics.control_forwarded +
                                               agent.receiver.metrics.control_forwarded)
    agent.counters.frames_rematerialized[] = Int64(agent.receiver.metrics.frames_rematerialized)
    return work_count
end

function Agent.on_close(agent::BridgeAgent)
    try
        close(agent.counters)
        consumer = agent.sender.consumer_state
        producer = agent.receiver.producer_state

        close(agent.sender.pub_payload)
        close(agent.sender.pub_control)
        agent.sender.pub_metadata === nothing || close(agent.sender.pub_metadata)
        close(agent.sender.sub_control)
        agent.sender.sub_metadata === nothing || close(agent.sender.sub_metadata)

        close(agent.receiver.sub_payload)
        close(agent.receiver.sub_control)
        agent.receiver.sub_metadata === nothing || close(agent.receiver.sub_metadata)
        agent.receiver.pub_metadata_local === nothing || close(agent.receiver.pub_metadata_local)
        agent.receiver.pub_control_local === nothing || close(agent.receiver.pub_control_local)

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
    catch
    end
    return nothing
end

export BridgeAgent
