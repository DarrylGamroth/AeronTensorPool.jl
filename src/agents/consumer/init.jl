"""
Initialize a consumer: create Aeron resources and initial timers.

Arguments:
- `config`: consumer settings.
- `client`: TensorPool client (owns Aeron resources).

Returns:
- `ConsumerState` initialized for polling.
"""
function init_consumer(config::ConsumerConfig; client::AbstractTensorPoolClient)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)
    announce_join_ns = UInt64(Clocks.time_nanos(clock))
    join_time_ref = Ref{UInt64}(announce_join_ns)
    config.allowed_base_dirs = canonical_allowed_dirs(config.shm_base_dir, config.allowed_base_dirs)
    aeron_client = client.aeron_client
    announce_channel = isempty(config.announce_channel) ? config.aeron_uri : config.announce_channel
    announce_stream_id = config.announce_stream_id == 0 ? config.control_stream_id : config.announce_stream_id
    config.announce_channel = announce_channel
    config.announce_stream_id = announce_stream_id
    announce_shared = announce_channel == config.aeron_uri && announce_stream_id == config.control_stream_id

    pub_control = Aeron.add_publication(aeron_client, config.aeron_uri, config.control_stream_id)
    log_publication_ready("Consumer control", pub_control, config.control_stream_id)
    pub_qos = Aeron.add_publication(aeron_client, config.aeron_uri, config.qos_stream_id)
    log_publication_ready("Consumer qos", pub_qos, config.qos_stream_id)

    sub_descriptor = Aeron.add_subscription(aeron_client, config.aeron_uri, config.descriptor_stream_id)
    log_subscription_ready("Consumer descriptor", sub_descriptor, config.descriptor_stream_id)
    on_announce_available = let ref = join_time_ref
        _ -> begin
            ref[] = UInt64(time_ns())
            @tp_info "Consumer announce image available" join_time_ns = ref[]
            return nothing
        end
    end
    on_announce_unavailable = _ -> begin
        @tp_info "Consumer announce image unavailable"
        return nothing
    end
    on_control_available = announce_shared ? on_announce_available : (_ -> begin
        @tp_info "Consumer control image available"
        return nothing
    end)
    on_control_unavailable = _ -> begin
        @tp_info "Consumer control image unavailable"
        return nothing
    end
    sub_control = Aeron.add_subscription(
        aeron_client,
        config.aeron_uri,
        config.control_stream_id;
        on_available_image = on_control_available,
        on_unavailable_image = on_control_unavailable,
    )
    log_subscription_ready("Consumer control", sub_control, config.control_stream_id)
    sub_announce = if announce_shared
        nothing
    else
        sub = Aeron.add_subscription(
            aeron_client,
            announce_channel,
            announce_stream_id;
            on_available_image = on_announce_available,
            on_unavailable_image = on_announce_unavailable,
        )
        log_subscription_ready("Consumer announce", sub, announce_stream_id)
        sub
    end
    sub_qos = Aeron.add_subscription(aeron_client, config.aeron_uri, config.qos_stream_id)
    log_subscription_ready("Consumer qos", sub_qos, config.qos_stream_id)
    sub_progress = nothing

    announce_wait_timer = PolledTimer(UInt64(0))
    backoff_timer = PolledTimer(UInt64(0))
    timer_set = TimerSet(
        (
            PolledTimer(config.hello_interval_ns),
            PolledTimer(config.qos_interval_ns),
            announce_wait_timer,
            backoff_timer,
        ),
        (
            ConsumerHelloHandler(),
            ConsumerQosHandler(),
            ConsumerAnnounceTimeoutHandler(),
            ConsumerBackoffHandler(),
        ),
    )

    control = ControlPlaneRuntime(aeron_client, pub_control, sub_control)
    runtime = ConsumerRuntime(
        control,
        pub_qos,
        sub_descriptor,
        sub_announce,
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
        UInt64(0),
        false,
    )
    dummy_handler = Aeron.FragmentHandler(nothing) do _, _, _
        nothing
    end
    dummy_assembler = Aeron.FragmentAssembler(dummy_handler)
    phase = config.use_shm ? UNMAPPED : FALLBACK
    mapping_lifecycle = ConsumerMappingLifecycle()
    driver_lifecycle = ConsumerDriverLifecycle()
    announce_lifecycle = ConsumerAnnounceLifecycle()
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
        driver_lifecycle,
        Int64(0),
        UInt64(0),
        backoff_timer,
        timer_set,
        "",
        UInt32(0),
        "",
        UInt32(0),
        dummy_assembler,
        true,
        UInt64(0),
        announce_wait_timer,
        false,
        announce_lifecycle,
        UInt64(0),
        UInt64(0),
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
- `client`: Tensor pool client/runtime to use for publications/subscriptions.

Returns:
- `ConsumerState` mapped to the driver-provisioned regions.
"""
function init_consumer_from_attach(
    config::ConsumerConfig,
    attach::AttachResponse;
    driver_client::Union{DriverClientState, Nothing} = nothing,
    client::AbstractTensorPoolClient,
)
    attach.code == DriverResponseCode.OK || throw(ArgumentError("attach failed"))
    attach.stream_id == config.stream_id || throw(ArgumentError("stream_id mismatch"))
    if config.consumer_id == 0 && driver_client !== nothing
        config.consumer_id = driver_client.client_id
    end
    state = init_consumer(config; client = client)
    ok = map_from_attach_response!(state, attach)
    ok || throw(ArgumentError("failed to map SHM from attach"))
    state.driver_client = driver_client
    state.driver_active = true
    Hsm.dispatch!(state.driver_lifecycle, :AttachOk, state)
    return state
end
