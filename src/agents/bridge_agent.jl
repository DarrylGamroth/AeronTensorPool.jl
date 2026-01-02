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

"""
Create a descriptor assembler that forwards frames to the bridge sender.
"""
function make_bridge_descriptor_assembler(state::BridgeSenderState)
    decoder = FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
            FrameDescriptor.wrap!(decoder, buffer, 0; header = header)
            bridge_send_frame!(st, decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Construct a BridgeAgent from configs and mapping.
"""
function BridgeAgent(
    bridge_config::BridgeConfig,
    mapping::BridgeMapping,
    consumer_config::ConsumerSettings,
    producer_config::ProducerConfig;
    client::Aeron.Client,
)
    consumer_state = init_consumer(consumer_config; client = client)
    producer_state = init_producer(producer_config; client = client)
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
    )

    control_assembler = make_control_assembler(consumer_state)
    descriptor_assembler = make_bridge_descriptor_assembler(sender)
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
    producer = agent.receiver.producer_state
    if producer !== nothing
        agent.counters.frames_rematerialized[] = Int64(producer.seq)
    end
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
