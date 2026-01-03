"""
Initialize a supervisor: create Aeron resources and timers.
"""
function init_supervisor(config::SupervisorConfig; client::Aeron.Client)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(config.liveness_check_interval_ns),),
        (SupervisorLivenessHandler(),),
    )

    control = ControlPlaneRuntime(client, pub_control, sub_control)
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
