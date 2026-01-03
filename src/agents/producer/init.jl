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
        config.progress_interval_ns,
        config.progress_bytes_delta,
        nothing,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
        true,
        false,
        true,
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
        driver_config.progress_interval_ns,
        driver_config.progress_bytes_delta,
        driver_client,
        Int64(0),
        timer_set,
        Dict{UInt32, ProducerConsumerStream}(),
        true,
        false,
        false,
    )
    return state
end
