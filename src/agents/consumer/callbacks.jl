"""
Hook container for consumer events.
"""
struct ConsumerCallbacks{FFrame, FMeta, FQosProd, FQosCons}
    on_frame!::FFrame
    on_metadata!::FMeta
    on_qos_producer!::FQosProd
    on_qos_consumer!::FQosCons
end

noop_consumer_frame!(::ConsumerState, ::ConsumerFrameView) = nothing
noop_consumer_metadata!(::ConsumerState, ::MetadataEntry) = nothing
noop_consumer_qos_producer!(::ConsumerState, ::QosProducerSnapshot) = nothing
noop_consumer_qos_consumer!(::ConsumerState, ::QosConsumerSnapshot) = nothing

ConsumerCallbacks(on_frame!) =
    ConsumerCallbacks(
        on_frame!,
        noop_consumer_metadata!,
        noop_consumer_qos_producer!,
        noop_consumer_qos_consumer!,
    )

ConsumerCallbacks(;
    on_frame! = noop_consumer_frame!,
    on_metadata! = noop_consumer_metadata!,
    on_qos_producer! = noop_consumer_qos_producer!,
    on_qos_consumer! = noop_consumer_qos_consumer!,
) = ConsumerCallbacks(on_frame!, on_metadata!, on_qos_producer!, on_qos_consumer!)

const NOOP_CONSUMER_CALLBACKS =
    ConsumerCallbacks(
        noop_consumer_frame!,
        noop_consumer_metadata!,
        noop_consumer_qos_producer!,
        noop_consumer_qos_consumer!,
    )
