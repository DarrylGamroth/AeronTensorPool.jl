"""
Initialize a producer: map SHM regions, write superblocks, and create Aeron resources.
"""
function init_producer(config::ProducerConfig; client::Aeron.Client)
    ispow2(config.nslots) || throw(ArgumentError("header nslots must be power of two"))
    for pool in config.payload_pools
        pool.nslots == config.nslots || throw(ArgumentError("payload nslots must match header nslots"))
    end

    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    mappings, sb_encoder = init_producer_shm!(config, clock)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)
    pub_metadata = Aeron.add_publication(client, config.aeron_uri, config.metadata_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(config.announce_interval_ns), PolledTimer(config.qos_interval_ns)),
        (ProducerAnnounceHandler(), ProducerQosHandler()),
    )

    control = ControlPlaneRuntime(client, pub_control, sub_control)
    runtime = ProducerRuntime(
        control,
        pub_descriptor,
        pub_qos,
        pub_metadata,
        sub_qos,
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, ANNOUNCE_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        sb_encoder,
        TensorSlotHeader256.Encoder(Vector{UInt8}),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    metrics = ProducerMetrics(UInt64(0), UInt64(0), UInt64(0), UInt64(0))
    state = ProducerState(
        config,
        clock,
        runtime,
        mappings,
        metrics,
        UInt64(1),
        UInt64(0),
        true,
        false,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        true,
        nothing,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
    )

    emit_announce!(state)

    return state
end

"""
Build a ProducerConfig from a driver attach response.
"""
function producer_config_from_attach(config::ProducerConfig, attach::AttachResponse)
    pools = PayloadPoolConfig[]
    for i in 1:attach.pool_count
        pool = attach.pools[i]
        push!(
            pools,
            PayloadPoolConfig(
                pool.pool_id,
                String(pool.region_uri),
                pool.stride_bytes,
                pool.pool_nslots,
            ),
        )
    end
    return ProducerConfig(
        config.aeron_dir,
        config.aeron_uri,
        config.descriptor_stream_id,
        config.control_stream_id,
        config.qos_stream_id,
        config.metadata_stream_id,
        attach.stream_id,
        config.producer_id,
        attach.layout_version,
        attach.header_nslots,
        config.shm_base_dir,
        config.shm_namespace,
        config.producer_instance_id,
        String(attach.header_region_uri),
        pools,
        attach.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
    )
end

"""
Initialize a producer using driver-provisioned SHM regions.
"""
function init_producer_from_attach(
    config::ProducerConfig,
    attach::AttachResponse;
    driver_client::Union{DriverClientState, Nothing} = nothing,
    client::Aeron.Client,
)
    attach.code == DriverResponseCode.OK || throw(ArgumentError("attach failed"))
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || throw(ArgumentError("header_slot_bytes mismatch"))

    driver_config = producer_config_from_attach(config, attach)
    ispow2(driver_config.nslots) || throw(ArgumentError("header nslots must be power of two"))
    for pool in driver_config.payload_pools
        pool.nslots == driver_config.nslots || throw(ArgumentError("payload nslots must match header nslots"))
    end

    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    mappings = map_producer_from_attach(driver_config, attach)
    mappings === nothing && throw(ArgumentError("payload superblock validation failed"))

    pub_descriptor = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.descriptor_stream_id)
    pub_control = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.control_stream_id)
    pub_qos = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.qos_stream_id)
    pub_metadata = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.metadata_stream_id)
    sub_control = Aeron.add_subscription(client, driver_config.aeron_uri, driver_config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, driver_config.aeron_uri, driver_config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(driver_config.announce_interval_ns), PolledTimer(driver_config.qos_interval_ns)),
        (ProducerAnnounceHandler(), ProducerQosHandler()),
    )

    control = ControlPlaneRuntime(client, pub_control, sub_control)
    runtime = ProducerRuntime(
        control,
        pub_descriptor,
        pub_qos,
        pub_metadata,
        sub_qos,
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, ANNOUNCE_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        ShmRegionSuperblock.Encoder(Vector{UInt8}),
        TensorSlotHeader256.Encoder(Vector{UInt8}),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    metrics = ProducerMetrics(UInt64(0), UInt64(0), UInt64(0), UInt64(0))
    state = ProducerState(
        driver_config,
        clock,
        runtime,
        mappings,
        metrics,
        attach.epoch,
        UInt64(0),
        true,
        false,
        driver_config.progress_interval_ns,
        driver_config.progress_bytes_delta,
        false,
        driver_client,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
    )
    return state
end

"""
Remap producer SHM and epoch from a driver attach response.
"""
function remap_producer_from_attach!(state::ProducerState, attach::AttachResponse)
    attach.code == DriverResponseCode.OK || return false
    driver_config = producer_config_from_attach(state.config, attach)
    ispow2(driver_config.nslots) || return false
    for pool in driver_config.payload_pools
        pool.nslots == driver_config.nslots || return false
    end

    mappings = map_producer_from_attach(driver_config, attach)
    mappings === nothing && return false

    state.config = driver_config
    state.mappings = mappings
    state.epoch = attach.epoch
    state.seq = UInt64(0)
    state.emit_announce = false
    state.driver_active = true
    return true
end

@inline function producer_driver_active(state::ProducerState)
    dc = state.driver_client
    dc === nothing && return true
    return state.driver_active && dc.lease_id != 0 && !dc.revoked && !dc.shutdown
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ProducerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0

    if dc.revoked || dc.shutdown
        state.driver_active = false
    end

    if !state.driver_active && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.layout_version,
            max_dims = state.config.max_dims,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
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
                state.driver_active = remap_producer_from_attach!(state, attach)
                state.driver_active || (dc.lease_id = UInt64(0))
            else
                state.driver_active = false
            end
        end
    end
    return work_count
end


@inline function consumer_stream_timeout_ns(state::ProducerState)
    base = max(state.config.announce_interval_ns, state.config.qos_interval_ns)
    return base * 5
end

@inline function consumer_stream_last_seen_ns(entry::ProducerConsumerStream)
    return max(entry.last_hello_ns, entry.last_qos_ns)
end

function clear_consumer_stream!(entry::ProducerConsumerStream)
    entry.descriptor_pub === nothing || close(entry.descriptor_pub)
    entry.control_pub === nothing || close(entry.control_pub)
    entry.descriptor_pub = nothing
    entry.control_pub = nothing
    entry.descriptor_channel = ""
    entry.control_channel = ""
    entry.descriptor_stream_id = UInt32(0)
    entry.control_stream_id = UInt32(0)
    entry.max_rate_hz = UInt16(0)
    entry.next_descriptor_ns = UInt64(0)
    entry.last_hello_ns = UInt64(0)
    entry.last_qos_ns = UInt64(0)
    return nothing
end

function cleanup_consumer_streams!(state::ProducerState, now_ns::UInt64)
    timeout_ns = consumer_stream_timeout_ns(state)
    closed = 0
    for entry in values(state.consumer_streams)
        last_seen = consumer_stream_last_seen_ns(entry)
        last_seen == 0 && continue
        if now_ns - last_seen > timeout_ns
            clear_consumer_stream!(entry)
            closed += 1
        end
    end
    return closed
end

function update_consumer_streams!(state::ProducerState, msg::ConsumerHello.Decoder)
    consumer_id = ConsumerHello.consumerId(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    descriptor_stream_id = ConsumerHello.descriptorStreamId(msg)
    control_stream_id = ConsumerHello.controlStreamId(msg)
    descriptor_null = ConsumerHello.descriptorStreamId_null_value(ConsumerHello.Decoder)
    control_null = ConsumerHello.controlStreamId_null_value(ConsumerHello.Decoder)
    descriptor_channel = String(ConsumerHello.descriptorChannel(msg))
    control_channel = String(ConsumerHello.controlChannel(msg))
    descriptor_stream_id_provided =
        descriptor_stream_id != 0 && descriptor_stream_id != descriptor_null
    control_stream_id_provided =
        control_stream_id != 0 && control_stream_id != control_null
    descriptor_channel_provided = !isempty(descriptor_channel)
    control_channel_provided = !isempty(control_channel)
    descriptor_requested = descriptor_channel_provided && descriptor_stream_id_provided
    control_requested = control_channel_provided && control_stream_id_provided
    invalid_descriptor_request = descriptor_channel_provided != descriptor_stream_id_provided
    invalid_control_request = control_channel_provided != control_stream_id_provided

    if !descriptor_requested && !control_requested && !invalid_descriptor_request && !invalid_control_request
        return false
    end

    entry = get(state.consumer_streams, consumer_id, nothing)
    if entry === nothing
        entry = ProducerConsumerStream(
            nothing,
            nothing,
            "",
            "",
            UInt32(0),
            UInt32(0),
            UInt16(0),
            UInt64(0),
            now_ns,
            UInt64(0),
        )
        state.consumer_streams[consumer_id] = entry
    end

    entry.last_hello_ns = now_ns
    entry.max_rate_hz = ConsumerHello.maxRateHz(msg)

    changed = false
    if descriptor_requested
        if entry.descriptor_pub === nothing ||
            entry.descriptor_stream_id != descriptor_stream_id ||
            entry.descriptor_channel != descriptor_channel
            entry.descriptor_pub === nothing || close(entry.descriptor_pub)
            try
                entry.descriptor_pub = Aeron.add_publication(
                    state.runtime.control.client,
                    descriptor_channel,
                    Int32(descriptor_stream_id),
                )
                entry.descriptor_stream_id = descriptor_stream_id
                entry.descriptor_channel = descriptor_channel
                entry.next_descriptor_ns = now_ns
                changed = true
            catch
                entry.descriptor_pub = nothing
                entry.descriptor_stream_id = UInt32(0)
                entry.descriptor_channel = ""
                changed = true
            end
        end
    elseif entry.descriptor_pub !== nothing
        close(entry.descriptor_pub)
        entry.descriptor_pub = nothing
        entry.descriptor_channel = ""
        entry.descriptor_stream_id = UInt32(0)
        changed = true
    end

    if control_requested
        if entry.control_pub === nothing ||
            entry.control_stream_id != control_stream_id ||
            entry.control_channel != control_channel
            entry.control_pub === nothing || close(entry.control_pub)
            try
                entry.control_pub = Aeron.add_publication(
                    state.runtime.control.client,
                    control_channel,
                    Int32(control_stream_id),
                )
                entry.control_stream_id = control_stream_id
                entry.control_channel = control_channel
                changed = true
            catch
                entry.control_pub = nothing
                entry.control_stream_id = UInt32(0)
                entry.control_channel = ""
                changed = true
            end
        end
    elseif entry.control_pub !== nothing
        close(entry.control_pub)
        entry.control_pub = nothing
        entry.control_channel = ""
        entry.control_stream_id = UInt32(0)
        changed = true
    end

    if invalid_descriptor_request || invalid_control_request
        emit_consumer_config!(
            state,
            consumer_id;
            use_shm = true,
            mode = ConsumerHello.mode(msg),
            decimation = UInt16(1),
            payload_fallback_uri = "",
            descriptor_channel = "",
            descriptor_stream_id = UInt32(0),
            control_channel = "",
            control_stream_id = UInt32(0),
        )
        return false
    end

    if changed
        emit_consumer_config!(
            state,
            consumer_id;
            use_shm = true,
            mode = ConsumerHello.mode(msg),
            decimation = UInt16(1),
            payload_fallback_uri = "",
            descriptor_channel = entry.descriptor_channel,
            descriptor_stream_id = entry.descriptor_stream_id,
            control_channel = entry.control_channel,
            control_stream_id = entry.control_stream_id,
        )
    end
    return changed
end

function handle_qos_consumer!(state::ProducerState, msg::QosConsumer.Decoder)
    QosConsumer.streamId(msg) == state.config.stream_id || return false
    consumer_id = QosConsumer.consumerId(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    entry = get(state.consumer_streams, consumer_id, nothing)
    if entry === nothing
        entry = ProducerConsumerStream(
            nothing,
            nothing,
            "",
            "",
            UInt32(0),
            UInt32(0),
            UInt16(0),
            UInt64(0),
            UInt64(0),
            now_ns,
        )
        state.consumer_streams[consumer_id] = entry
    end
    entry.last_qos_ns = now_ns
    return true
end

"""
Update progress settings based on a ConsumerHello message.
"""
function handle_consumer_hello!(state::ProducerState, msg::ConsumerHello.Decoder)
    if ConsumerHello.supportsProgress(msg) == ShmTensorpoolControl.Bool_.TRUE
        state.supports_progress = true
        interval = ConsumerHello.progressIntervalUs(msg)
        bytes_delta = ConsumerHello.progressBytesDelta(msg)

        if interval != typemax(UInt32)
            hint_ns = UInt64(interval) * 1000
            state.progress_interval_ns = max(
                state.config.progress_interval_ns,
                min(state.progress_interval_ns, hint_ns),
            )
        end
        if bytes_delta != typemax(UInt32)
            hint_bytes = UInt64(bytes_delta)
            state.progress_bytes_delta = max(
                state.config.progress_bytes_delta,
                min(state.progress_bytes_delta, hint_bytes),
            )
        end
    end
    update_consumer_streams!(state, msg)
    return nothing
end
