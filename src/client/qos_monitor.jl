import ..Core: AbstractQosMonitor, QosProducerSnapshot, QosConsumerSnapshot
import ..Core: poll_qos!, producer_qos, consumer_qos

"""
QoS monitor that tracks last-seen producer and consumer QoS messages.
"""
mutable struct QosMonitor{ClockT} <: AbstractQosMonitor
    client::Aeron.Client
    sub_qos::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    producer_decoder::QosProducer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    consumer_decoder::QosConsumer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    clock::ClockT
    producers::Dict{UInt32, QosProducerSnapshot}
    consumers::Dict{UInt32, QosConsumerSnapshot}
    last_poll_ns::UInt64
end

function QosMonitor(aeron_uri::AbstractString, qos_stream_id::Int32; client::Aeron.Client)
    sub_qos = Aeron.add_subscription(client, aeron_uri, qos_stream_id)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    monitor = QosMonitor(
        client,
        sub_qos,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        clock,
        Dict{UInt32, QosProducerSnapshot}(),
        Dict{UInt32, QosConsumerSnapshot}(),
        UInt64(0),
    )
    monitor.assembler = make_qos_monitor_assembler(monitor)
    return monitor
end

QosMonitor(config::ConsumerConfig; client::Aeron.Client) =
    QosMonitor(config.aeron_uri, config.qos_stream_id; client = client)

QosMonitor(config::ProducerConfig; client::Aeron.Client) =
    QosMonitor(config.aeron_uri, config.qos_stream_id; client = client)

QosMonitor(config::SupervisorConfig; client::Aeron.Client) =
    QosMonitor(config.aeron_uri, config.qos_stream_id; client = client)

"""
Return the latest producer QoS snapshot for `producer_id`.
"""
producer_qos(monitor::QosMonitor, producer_id::UInt32) =
    get(monitor.producers, producer_id, nothing)

"""
Return the latest consumer QoS snapshot for `consumer_id`.
"""
consumer_qos(monitor::QosMonitor, consumer_id::UInt32) =
    get(monitor.consumers, consumer_id, nothing)

function make_qos_monitor_assembler(monitor::QosMonitor)
    handler = Aeron.FragmentHandler(monitor) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.schemaId(header) != MessageHeader.sbe_schema_id(MessageHeader.Decoder)
            return nothing
        end
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_QOS_PRODUCER
            QosProducer.wrap!(st.producer_decoder, buffer, 0; header = header)
            handle_qos_producer!(st, st.producer_decoder)
        elseif template_id == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.consumer_decoder, buffer, 0; header = header)
            handle_qos_consumer!(st, st.consumer_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll the QoS subscription and update snapshots.
"""
function poll_qos!(monitor::QosMonitor, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    fetch!(monitor.clock)
    monitor.last_poll_ns = UInt64(Clocks.time_nanos(monitor.clock))
    return Aeron.poll(monitor.sub_qos, monitor.assembler, fragment_limit)
end

"""
Close the monitor subscription.
"""
function Base.close(monitor::QosMonitor)
    close(monitor.sub_qos)
    return nothing
end

function handle_qos_producer!(monitor::QosMonitor, msg::QosProducer.Decoder)
    pid = QosProducer.producerId(msg)
    info = get(monitor.producers, pid, nothing)
    if info === nothing
        monitor.producers[pid] = QosProducerSnapshot(
            QosProducer.streamId(msg),
            pid,
            QosProducer.epoch(msg),
            QosProducer.currentSeq(msg),
            monitor.last_poll_ns,
        )
    else
        info.stream_id = QosProducer.streamId(msg)
        info.epoch = QosProducer.epoch(msg)
        info.current_seq = QosProducer.currentSeq(msg)
        info.last_qos_ns = monitor.last_poll_ns
    end
    return nothing
end

function handle_qos_consumer!(monitor::QosMonitor, msg::QosConsumer.Decoder)
    cid = QosConsumer.consumerId(msg)
    info = get(monitor.consumers, cid, nothing)
    if info === nothing
        monitor.consumers[cid] = QosConsumerSnapshot(
            QosConsumer.streamId(msg),
            cid,
            QosConsumer.epoch(msg),
            QosConsumer.mode(msg),
            QosConsumer.lastSeqSeen(msg),
            QosConsumer.dropsGap(msg),
            QosConsumer.dropsLate(msg),
            monitor.last_poll_ns,
        )
    else
        info.stream_id = QosConsumer.streamId(msg)
        info.epoch = QosConsumer.epoch(msg)
        info.mode = QosConsumer.mode(msg)
        info.last_seq_seen = QosConsumer.lastSeqSeen(msg)
        info.drops_gap = QosConsumer.dropsGap(msg)
        info.drops_late = QosConsumer.dropsLate(msg)
        info.last_qos_ns = monitor.last_poll_ns
    end
    return nothing
end
