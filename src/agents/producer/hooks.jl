"""
Hook container for producer events.
"""
struct ProducerHooks{FHello, FQos, FFrame}
    on_consumer_hello!::FHello
    on_qos_consumer!::FQos
    on_frame_published!::FFrame
end

noop_producer_hello!(::ProducerState, ::ConsumerHello.Decoder) = nothing

noop_producer_qos!(::ProducerState, ::QosConsumer.Decoder) = nothing

noop_producer_frame!(::ProducerState, ::UInt64, ::UInt32) = nothing

const NOOP_PRODUCER_HOOKS =
    ProducerHooks(noop_producer_hello!, noop_producer_qos!, noop_producer_frame!)
