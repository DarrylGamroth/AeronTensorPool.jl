"""
Initialize a producer: map SHM regions, write superblocks, and create Aeron resources.

Arguments:
- `config`: producer configuration.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `ProducerState` initialized for publishing.
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
        SlotHeaderMsg.Encoder(Vector{UInt8}),
        TensorHeaderMsg.Encoder(Vector{UInt8}),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    metrics = ProducerMetrics(UInt64(0), UInt64(0), UInt64(0))
    state = ProducerState(
        config,
        clock,
        runtime,
        mappings,
        metrics,
        UInt64(1),
        UInt64(0),
        config.progress_interval_ns,
        config.progress_bytes_delta,
        UInt64(config.progress_major_delta_units),
        UInt64(0),
        PolledTimer(config.progress_interval_ns),
        nothing,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
        true,
        false,
        true,
        UInt32(0),
        "",
        "",
        MetadataAttribute[],
        false,
    )

    emit_announce!(state)

    return state
end

"""
Build a ProducerConfig from a driver attach response.

Arguments:
- `config`: base producer configuration (used for defaults).
- `attach`: driver attach response.

Returns:
- `ProducerConfig` populated from driver-provided regions.
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
        UInt8(MAX_DIMS),
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        config.progress_major_delta_units,
        config.mlock_shm,
    )
end

"""
Initialize a producer using driver-provisioned SHM regions.

Arguments:
- `config`: base producer configuration.
- `attach`: driver attach response.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `ProducerState` initialized for publishing.
"""
function init_producer_from_attach(
    config::ProducerConfig,
    attach::AttachResponse;
    driver_client::Union{DriverClientState, Nothing} = nothing,
    client::Aeron.Client,
)
    attach.code == DriverResponseCode.OK || throw(ArgumentError("attach failed"))
    if attach.lease_id == ShmAttachResponse.leaseId_null_value(ShmAttachResponse.Decoder) ||
       attach.stream_id == ShmAttachResponse.streamId_null_value(ShmAttachResponse.Decoder) ||
       attach.epoch == ShmAttachResponse.epoch_null_value(ShmAttachResponse.Decoder) ||
       attach.layout_version == ShmAttachResponse.layoutVersion_null_value(ShmAttachResponse.Decoder) ||
       attach.header_nslots == ShmAttachResponse.headerNslots_null_value(ShmAttachResponse.Decoder) ||
       attach.header_slot_bytes == ShmAttachResponse.headerSlotBytes_null_value(ShmAttachResponse.Decoder)
        throw(ArgumentError("attach response missing required fields"))
    end
    isempty(view(attach.header_region_uri)) && throw(ArgumentError("header_region_uri missing"))
    attach.pool_count > 0 || throw(ArgumentError("attach response missing payload pools"))
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || throw(ArgumentError("header_slot_bytes mismatch"))

    driver_config = producer_config_from_attach(config, attach)
    ispow2(driver_config.nslots) || throw(ArgumentError("header nslots must be power of two"))
    for pool in driver_config.payload_pools
        pool.nslots == driver_config.nslots || throw(ArgumentError("payload nslots must match header nslots"))
    end

    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    mappings = map_producer_from_attach(driver_config, attach)
    mappings === nothing && throw(ArgumentError("payload superblock validation failed"))

    @tp_info "Producer Aeron endpoints" aeron_uri = driver_config.aeron_uri descriptor_stream_id =
        driver_config.descriptor_stream_id control_stream_id = driver_config.control_stream_id qos_stream_id =
        driver_config.qos_stream_id metadata_stream_id = driver_config.metadata_stream_id
    pub_descriptor = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.descriptor_stream_id)
    @tp_info "Producer publication ready" stream_id = driver_config.descriptor_stream_id channel =
        Aeron.channel(pub_descriptor) max_payload_length = Aeron.max_payload_length(pub_descriptor) max_message_length =
        Aeron.max_message_length(pub_descriptor) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(pub_descriptor)
    pub_control = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.control_stream_id)
    @tp_info "Producer control publication ready" stream_id = driver_config.control_stream_id channel =
        Aeron.channel(pub_control) max_payload_length = Aeron.max_payload_length(pub_control) max_message_length =
        Aeron.max_message_length(pub_control) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(pub_control)
    pub_qos = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.qos_stream_id)
    @tp_info "Producer qos publication ready" stream_id = driver_config.qos_stream_id channel =
        Aeron.channel(pub_qos) max_payload_length = Aeron.max_payload_length(pub_qos) max_message_length =
        Aeron.max_message_length(pub_qos) channel_status_indicator_id = Aeron.channel_status_indicator_id(pub_qos)
    pub_metadata = Aeron.add_publication(client, driver_config.aeron_uri, driver_config.metadata_stream_id)
    @tp_info "Producer metadata publication ready" stream_id = driver_config.metadata_stream_id channel =
        Aeron.channel(pub_metadata) max_payload_length = Aeron.max_payload_length(pub_metadata) max_message_length =
        Aeron.max_message_length(pub_metadata) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(pub_metadata)
    sub_control = Aeron.add_subscription(client, driver_config.aeron_uri, driver_config.control_stream_id)
    @tp_info "Producer control subscription ready" stream_id = driver_config.control_stream_id channel =
        Aeron.channel(sub_control) channel_status_indicator_id = Aeron.channel_status_indicator_id(sub_control)
    sub_qos = Aeron.add_subscription(client, driver_config.aeron_uri, driver_config.qos_stream_id)
    @tp_info "Producer qos subscription ready" stream_id = driver_config.qos_stream_id channel =
        Aeron.channel(sub_qos) channel_status_indicator_id = Aeron.channel_status_indicator_id(sub_qos)

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
        SlotHeaderMsg.Encoder(Vector{UInt8}),
        TensorHeaderMsg.Encoder(Vector{UInt8}),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    metrics = ProducerMetrics(UInt64(0), UInt64(0), UInt64(0))
    state = ProducerState(
        driver_config,
        clock,
        runtime,
        mappings,
        metrics,
        attach.epoch,
        UInt64(0),
        driver_config.progress_interval_ns,
        driver_config.progress_bytes_delta,
        UInt64(driver_config.progress_major_delta_units),
        UInt64(0),
        PolledTimer(driver_config.progress_interval_ns),
        driver_client,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
        true,
        false,
        true,
        UInt32(0),
        "",
        "",
        MetadataAttribute[],
        false,
    )
    emit_announce!(state)
    return state
end
