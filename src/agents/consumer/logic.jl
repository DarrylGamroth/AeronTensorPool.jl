"""
Initialize a consumer: create Aeron resources and initial timers.
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
            PayloadSlice(UInt8[], 0, 0),
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

@inline function consumer_driver_active(state::ConsumerState)
    dc = state.driver_client
    dc === nothing && return true
    return state.driver_active && dc.lease_id != 0 && !dc.revoked && !dc.shutdown
end

"""
Remap consumer SHM from a driver attach response.
"""
function remap_consumer_from_attach!(state::ConsumerState, attach::AttachResponse)
    reset_mappings!(state)
    state.config.use_shm = true
    ok = map_from_attach_response!(state, attach)
    state.driver_active = ok
    return ok
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ConsumerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0

    if dc.revoked || dc.shutdown
        state.driver_active = false
        reset_mappings!(state)
    end

    if !state.driver_active && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.expected_layout_version,
            max_dims = state.config.max_dims,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            require_hugepages = state.config.require_hugepages,
        )
        if cid != 0
            state.pending_attach_id = cid
            work_count += 1
        end
    end

    if state.pending_attach_id != 0
        attach = dc.poller.last_attach
        if attach !== nothing && attach.correlation_id == state.pending_attach_id
            state.pending_attach_id = Int64(0)
            if attach.code == DriverResponseCode.OK
                apply_attach!(dc, attach)
                state.driver_active = remap_consumer_from_attach!(state, attach)
                state.driver_active || (dc.lease_id = UInt64(0))
            else
                state.driver_active = false
            end
        end
    end
    return work_count
end

"""
Apply a ConsumerConfig message to a live consumer.
"""
function apply_consumer_config!(state::ConsumerState, msg::ConsumerConfigMsg.Decoder)
    ConsumerConfigMsg.streamId(msg) == state.config.stream_id || return false
    ConsumerConfigMsg.consumerId(msg) == state.config.consumer_id || return false

    state.config.use_shm = (ConsumerConfigMsg.useShm(msg) == ShmTensorpoolControl.Bool_.TRUE)
    state.config.mode = ConsumerConfigMsg.mode(msg)
    state.config.decimation = ConsumerConfigMsg.decimation(msg)
    state.config.payload_fallback_uri = String(ConsumerConfigMsg.payloadFallbackUri(msg))

    descriptor_channel = String(ConsumerConfigMsg.descriptorChannel(msg))
    descriptor_stream_id = ConsumerConfigMsg.descriptorStreamId(msg)
    descriptor_null = ConsumerConfigMsg.descriptorStreamId_null_value(ConsumerConfigMsg.Decoder)
    descriptor_assigned =
        !isempty(descriptor_channel) && descriptor_stream_id != 0 && descriptor_stream_id != descriptor_null

    if descriptor_assigned
        if state.assigned_descriptor_stream_id != descriptor_stream_id ||
            state.assigned_descriptor_channel != descriptor_channel
            new_sub = Aeron.add_subscription(
                state.runtime.control.client,
                descriptor_channel,
                Int32(descriptor_stream_id),
            )
            close(state.runtime.sub_descriptor)
            state.runtime.sub_descriptor = new_sub
            state.assigned_descriptor_channel = descriptor_channel
            state.assigned_descriptor_stream_id = descriptor_stream_id
        end
    elseif state.assigned_descriptor_stream_id != 0
        new_sub = Aeron.add_subscription(
            state.runtime.control.client,
            state.config.aeron_uri,
            state.config.descriptor_stream_id,
        )
        close(state.runtime.sub_descriptor)
        state.runtime.sub_descriptor = new_sub
        state.assigned_descriptor_channel = ""
        state.assigned_descriptor_stream_id = UInt32(0)
    end

    control_channel = String(ConsumerConfigMsg.controlChannel(msg))
    control_stream_id = ConsumerConfigMsg.controlStreamId(msg)
    control_null = ConsumerConfigMsg.controlStreamId_null_value(ConsumerConfigMsg.Decoder)
    control_assigned =
        !isempty(control_channel) && control_stream_id != 0 && control_stream_id != control_null

    if control_assigned
        if state.assigned_control_stream_id != control_stream_id ||
            state.assigned_control_channel != control_channel
            new_sub = Aeron.add_subscription(
                state.runtime.control.client,
                control_channel,
                Int32(control_stream_id),
            )
            state.runtime.sub_progress === nothing || close(state.runtime.sub_progress)
            state.runtime.sub_progress = new_sub
            state.assigned_control_channel = control_channel
            state.assigned_control_stream_id = control_stream_id
        end
    elseif state.runtime.sub_progress !== nothing
        close(state.runtime.sub_progress)
        state.runtime.sub_progress = nothing
        state.assigned_control_channel = ""
        state.assigned_control_stream_id = UInt32(0)
    end

    if !state.config.use_shm
        reset_mappings!(state)
    end
    return true
end
