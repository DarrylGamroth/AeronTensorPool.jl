"""
Facade for client-facing callback wiring.
"""
struct ClientCallbacks
    consumer::ConsumerCallbacks
    producer::ProducerCallbacks
end

ClientCallbacks(;
    consumer::ConsumerCallbacks = Consumer.NOOP_CONSUMER_CALLBACKS,
    producer::ProducerCallbacks = Producer.NOOP_PRODUCER_CALLBACKS,
) = ClientCallbacks(consumer, producer)

consumer_callbacks(callbacks::ClientCallbacks) = callbacks.consumer
producer_callbacks(callbacks::ClientCallbacks) = callbacks.producer

consumer_callbacks(callbacks::ConsumerCallbacks) = callbacks
producer_callbacks(callbacks::ProducerCallbacks) = callbacks

