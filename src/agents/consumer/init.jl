"""
Initialize a consumer: create Aeron resources and initial timers.

Arguments:
- `config`: consumer settings.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `ConsumerState` initialized for polling.
"""
function init_consumer(config::ConsumerConfig; client::Aeron.Client)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)
    announce_join_ns = UInt64(Clocks.time_nanos(clock))
    join_time_ref = Ref{UInt64}(announce_join_ns)
    config.allowed_base_dirs = canonical_allowed_dirs(config.shm_base_dir, config.allowed_base_dirs)

    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    @tp_info "Consumer control publication ready" stream_id = config.control_stream_id channel =
        Aeron.channel(pub_control) max_payload_length = Aeron.max_payload_length(pub_control) max_message_length =
        Aeron.max_message_length(pub_control) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(pub_control)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)
    @tp_info "Consumer qos publication ready" stream_id = config.qos_stream_id channel = Aeron.channel(pub_qos) max_payload_length =
        Aeron.max_payload_length(pub_qos) max_message_length = Aeron.max_message_length(pub_qos) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(pub_qos)

    sub_descriptor = Aeron.add_subscription(client, config.aeron_uri, config.descriptor_stream_id)
    @tp_info "Consumer descriptor subscription ready" stream_id = config.descriptor_stream_id channel =
        Aeron.channel(sub_descriptor) channel_status_indicator_id = Aeron.channel_status_indicator_id(sub_descriptor)
    on_control_available = let ref = join_time_ref
        _ -> begin
            ref[] = UInt64(time_ns())
            @tp_info "Consumer control image available" join_time_ns = ref[]
            return nothing
        end
    end
    on_control_unavailable = _ -> begin
        @tp_info "Consumer control image unavailable"
        return nothing
    end
    sub_control = Aeron.add_subscription(
        client,
        config.aeron_uri,
        config.control_stream_id;
        on_available_image = on_control_available,
        on_unavailable_image = on_control_unavailable,
    )
    @tp_info "Consumer control subscription ready" stream_id = config.control_stream_id channel =
        Aeron.channel(sub_control) channel_status_indicator_id = Aeron.channel_status_indicator_id(sub_control)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)
    @tp_info "Consumer qos subscription ready" stream_id = config.qos_stream_id channel =
        Aeron.channel(sub_qos) channel_status_indicator_id = Aeron.channel_status_indicator_id(sub_qos)
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
        SlotHeaderMsg.Decoder(Vector{UInt8}),
        TensorHeaderMsg.Decoder(Vector{UInt8}),
        ShmRegionSuperblock.Decoder(Vector{UInt8}),
        FixedSizeVectorDefault{Int64}(undef, MAX_DIMS),
        FixedSizeVectorDefault{Int64}(undef, MAX_DIMS),
        ConsumerFrameView(
            SlotHeader(
                UInt64(0),
                UInt64(0),
                UInt32(0),
                UInt32(0),
                UInt32(0),
                UInt32(0),
                UInt16(0),
                TensorHeader(
                    Dtype.UNKNOWN,
                    MajorOrder.ROW,
                    UInt8(0),
                    UInt8(0),
                    ProgressUnit.NONE,
                    UInt32(0),
                    ntuple(_ -> Int32(0), Val(MAX_DIMS)),
                    ntuple(_ -> Int32(0), Val(MAX_DIMS)),
                ),
            ),
            PayloadView(UInt8[], 0, 0),
            UInt64(0),
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
        UInt64[],
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
        UInt64(0),
        false,
    )
    dummy_handler = Aeron.FragmentHandler(nothing) do _, _, _
        nothing
    end
    dummy_assembler = Aeron.FragmentAssembler(dummy_handler)
    phase = config.use_shm ? UNMAPPED : FALLBACK
    mapping_lifecycle = ConsumerMappingLifecycle()
    state = ConsumerState(
        config,
        clock,
        join_time_ref,
        runtime,
        mappings,
        metrics,
        mapping_lifecycle,
        phase,
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
    set_mapping_phase!(state, phase)
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
    config::ConsumerConfig,
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
