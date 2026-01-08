"""
Hook container for producer events.
"""
struct ProducerCallbacks{FHello, FQos, FFrame, FQosProd}
    on_consumer_hello!::FHello
    on_qos_consumer!::FQos
    on_frame_published!::FFrame
    on_qos_producer!::FQosProd
end

noop_producer_hello!(::ProducerState, ::ConsumerHello.Decoder) = nothing

noop_producer_qos!(::ProducerState, ::QosConsumer.Decoder) = nothing

noop_producer_frame!(::ProducerState, ::UInt64, ::UInt32) = nothing

noop_producer_qos_producer!(::ProducerState, ::QosProducerSnapshot) = nothing

ProducerCallbacks(on_consumer_hello!, on_qos_consumer!, on_frame_published!) =
    ProducerCallbacks(
        on_consumer_hello!,
        on_qos_consumer!,
        on_frame_published!,
        noop_producer_qos_producer!,
    )

const NOOP_PRODUCER_CALLBACKS =
    ProducerCallbacks(
        noop_producer_hello!,
        noop_producer_qos!,
        noop_producer_frame!,
        noop_producer_qos_producer!,
    )

ProducerCallbacks(;
    on_consumer_hello! = noop_producer_hello!,
    on_qos_consumer! = noop_producer_qos!,
    on_frame_published! = noop_producer_frame!,
    on_qos_producer! = noop_producer_qos_producer!,
) = ProducerCallbacks(on_consumer_hello!, on_qos_consumer!, on_frame_published!, on_qos_producer!)
