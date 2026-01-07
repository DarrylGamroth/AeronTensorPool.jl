"""
Hook container for supervisor events.
"""
struct SupervisorHooks{FAnnounce, FHello, FQosP, FQosC}
    on_announce!::FAnnounce
    on_consumer_hello!::FHello
    on_qos_producer!::FQosP
    on_qos_consumer!::FQosC
end

noop_supervisor_announce!(::SupervisorState, ::ShmPoolAnnounce.Decoder) = nothing

noop_supervisor_hello!(::SupervisorState, ::ConsumerHello.Decoder) = nothing

noop_supervisor_qos_producer!(::SupervisorState, ::QosProducer.Decoder) = nothing

noop_supervisor_qos_consumer!(::SupervisorState, ::QosConsumer.Decoder) = nothing

const NOOP_SUPERVISOR_HOOKS = SupervisorHooks(
    noop_supervisor_announce!,
    noop_supervisor_hello!,
    noop_supervisor_qos_producer!,
    noop_supervisor_qos_consumer!,
)
