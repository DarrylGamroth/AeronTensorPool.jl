"""
Initialize a consumer: create Aeron resources and initial timers.

Arguments:
- `config`: consumer settings.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `ConsumerState` initialized for polling.
"""
function init_consumer(config::ConsumerSettings; client::Aeron.Client)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)
    announce_join_ns = UInt64(Clocks.time_nanos(clock))

    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)

    sub_descriptor = Aeron.add_subscription(client, config.aeron_uri, config.descriptor_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)
    sub_progress = nothing

    timer_set = TimerSet(
        (PolledTimer(config.hello_interval_ns), PolledTimer(config.qos_interval_ns)),
        (ConsumerHelloHandler(), ConsumerQosHandler()),
    )

    control = ControlPlaneRuntime(client, pub_control, sub_control)
    runtime = ConsumerRuntime(
        control,
        pub_qos,
        sub_descriptor,
        sub_qos,
        sub_progress,
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        ConsumerHello.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeader256.Decoder(Vector{UInt8}),
        ShmRegionSuperblock.Decoder(Vector{UInt8}),
        FixedSizeVectorDefault{Int64}(undef, MAX_DIMS),
        FixedSizeVectorDefault{Int64}(undef, MAX_DIMS),
        ConsumerFrameView(
            TensorSlotHeader(
                UInt64(0),
                UInt64(0),
                UInt64(0),
                UInt32(0),
                UInt32(0),
                UInt32(0),
                UInt32(0),
                UInt16(0),
                Dtype.UNKNOWN,
                MajorOrder.ROW,
                UInt8(0),
                UInt8(0),
                ntuple(_ -> Int32(0), Val(MAX_DIMS)),
                ntuple(_ -> Int32(0), Val(MAX_DIMS)),
            ),
            PayloadView(UInt8[], 0, 0),
        ),
    )
    mappings = ConsumerMappings(
        UInt64(0),
        nothing,
        Dict{UInt16, Vector{UInt8}}(),
        Dict{UInt16, UInt32}(),
        UInt32(0),
        UInt64(0),
        UInt64[],
    )
    metrics = ConsumerMetrics(
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        false,
    )
    dummy_handler = Aeron.FragmentHandler(nothing) do _, _, _
        nothing
    end
    dummy_assembler = Aeron.FragmentAssembler(dummy_handler)
    state = ConsumerState(
        config,
        clock,
        announce_join_ns,
        runtime,
        mappings,
        metrics,
        nothing,
        Int64(0),
        timer_set,
        "",
        UInt32(0),
        "",
        UInt32(0),
        dummy_assembler,
        true,
    )
    state.progress_assembler = make_progress_assembler(state)
    return state
end

"""
Initialize a consumer using driver-provisioned SHM regions.

Arguments:
- `config`: consumer settings.
- `attach`: driver attach response.
- `driver_client`: optional driver client state (for keepalives).
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `ConsumerState` mapped to the driver-provisioned regions.
"""
function init_consumer_from_attach(
    config::ConsumerSettings,
    attach::AttachResponse;
    driver_client::Union{DriverClientState, Nothing} = nothing,
    client::Aeron.Client,
)
    attach.code == DriverResponseCode.OK || throw(ArgumentError("attach failed"))
    attach.stream_id == config.stream_id || throw(ArgumentError("stream_id mismatch"))
    state = init_consumer(config; client = client)
    ok = map_from_attach_response!(state, attach)
    ok || throw(ArgumentError("failed to map SHM from attach"))
    state.driver_client = driver_client
    state.driver_active = true
    return state
end
