"""
Initialize a supervisor: create Aeron resources and timers.

Arguments:
- `config`: supervisor configuration.
- `client`: TensorPool client (owns Aeron resources).

Returns:
- `SupervisorState` initialized for polling.
"""
function init_supervisor(config::SupervisorConfig; client::AbstractTensorPoolClient)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    aeron_client = client.aeron_client
    pub_control = Aeron.add_publication(aeron_client, config.aeron_uri, config.control_stream_id)
    sub_control = Aeron.add_subscription(aeron_client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(aeron_client, config.aeron_uri, config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(config.liveness_check_interval_ns),),
        (SupervisorLivenessHandler(),),
    )

    control = ControlPlaneRuntime(aeron_client, pub_control, sub_control)
    runtime = SupervisorRuntime(
        control,
        sub_qos,
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    tracking = SupervisorTracking(
        Dict{UInt32, ProducerInfo}(),
        Dict{UInt32, ConsumerInfo}(),
        UInt64(0),
        UInt64(0),
    )
    return SupervisorState(config, clock, runtime, tracking, timer_set)
end
