function await_attach_response!(
    driver_client::DriverClientState,
    correlation_id::Int64;
    timeout_ns::UInt64,
    retry_interval_ns::UInt64,
    retry_fn::Union{Nothing, Function} = nothing,
    driver_work_fn::Union{Nothing, Function} = nothing,
)
    pending = Int64[correlation_id]
    deadline = UInt64(time_ns()) + timeout_ns
    last_retry_ns = UInt64(time_ns())
    while UInt64(time_ns()) < deadline
        driver_work_fn === nothing || driver_work_fn()
        now_ns = UInt64(time_ns())
        attach = Control.poll_attach_any!(driver_client, pending, now_ns)
        if attach !== nothing
            attach.code == DriverResponseCode.OK || throw(ArgumentError("attach rejected: $(attach.error_message)"))
            return attach
        end
        if now_ns - last_retry_ns > retry_interval_ns
            if retry_fn !== nothing
                old_id = pending[end]
                new_id = retry_fn()
                if new_id != 0
                    push!(pending, new_id)
                    @tp_debug "attach retry" old_correlation_id = old_id correlation_id = new_id pending = length(pending)
                end
            end
            last_retry_ns = now_ns
        end
        yield()
    end
    throw(ArgumentError("attach timed out"))
end

function init_mapping_state(
    config::RateLimiterConfig,
    mapping::RateLimiterMapping,
    client::Aeron.Client;
    driver_work_fn::Union{Nothing, Function} = nothing,
)
    driver_control_channel =
        isempty(config.driver_control_channel) ? config.control_channel : config.driver_control_channel
    driver_control_stream_id =
        config.driver_control_stream_id == 0 ? config.control_stream_id : config.driver_control_stream_id

    consumer_id = mapping.source_stream_id
    producer_id = mapping.dest_stream_id

    consumer_cfg = AeronTensorPool.default_consumer_config(
        ;
        aeron_dir = config.aeron_dir,
        aeron_uri = config.aeron_uri,
        shm_base_dir = config.shm_base_dir,
        descriptor_stream_id = config.descriptor_stream_id,
        control_stream_id = config.control_stream_id,
        qos_stream_id = config.qos_stream_id,
        stream_id = mapping.source_stream_id,
        consumer_id = consumer_id,
        supports_progress = config.forward_progress,
        max_rate_hz = UInt16(0),
    )

    producer_cfg = AeronTensorPool.default_producer_config(
        ;
        aeron_dir = config.aeron_dir,
        aeron_uri = config.aeron_uri,
        shm_base_dir = config.shm_base_dir,
        descriptor_stream_id = config.descriptor_stream_id,
        control_stream_id = config.control_stream_id,
        qos_stream_id = config.qos_stream_id,
        metadata_stream_id = Int32(mapping.metadata_stream_id),
        stream_id = mapping.dest_stream_id,
        producer_id = producer_id,
    )

    consumer_driver = init_driver_client(
        client,
        driver_control_channel,
        driver_control_stream_id,
        consumer_id,
        DriverRole.CONSUMER;
        keepalive_interval_ns = config.keepalive_interval_ns,
    )
    corr_consumer = send_attach_request!(
        consumer_driver;
        stream_id = mapping.source_stream_id,
        expected_layout_version = consumer_cfg.expected_layout_version,
        max_dims = UInt8(MAX_DIMS),
        require_hugepages = consumer_cfg.require_hugepages,
    )
    corr_consumer == 0 && throw(ArgumentError("consumer attach request failed"))
    attach_consumer = await_attach_response!(
        consumer_driver,
        corr_consumer;
        timeout_ns = config.attach_timeout_ns,
        retry_interval_ns = config.attach_retry_interval_ns,
        driver_work_fn = driver_work_fn,
        retry_fn = () -> send_attach_request!(
            consumer_driver;
            stream_id = mapping.source_stream_id,
            expected_layout_version = consumer_cfg.expected_layout_version,
            max_dims = UInt8(MAX_DIMS),
            require_hugepages = consumer_cfg.require_hugepages,
        ),
    )
    consumer_state = init_consumer_from_attach(
        consumer_cfg,
        attach_consumer;
        driver_client = consumer_driver,
        client = client,
    )

    producer_driver = init_driver_client(
        client,
        driver_control_channel,
        driver_control_stream_id,
        producer_id,
        DriverRole.PRODUCER;
        keepalive_interval_ns = config.keepalive_interval_ns,
    )
    corr_producer = send_attach_request!(
        producer_driver;
        stream_id = mapping.dest_stream_id,
        expected_layout_version = producer_cfg.layout_version,
        max_dims = UInt8(MAX_DIMS),
    )
    corr_producer == 0 && throw(ArgumentError("producer attach request failed"))
    attach_producer = await_attach_response!(
        producer_driver,
        corr_producer;
        timeout_ns = config.attach_timeout_ns,
        retry_interval_ns = config.attach_retry_interval_ns,
        driver_work_fn = driver_work_fn,
        retry_fn = () -> send_attach_request!(
            producer_driver;
            stream_id = mapping.dest_stream_id,
            expected_layout_version = producer_cfg.layout_version,
            max_dims = UInt8(MAX_DIMS),
        ),
    )
    producer_state = init_producer_from_attach(
        producer_cfg,
        attach_producer;
        driver_client = producer_driver,
        client = client,
    )

    mapping_ref = Ref{RateLimiterMappingState}()
    on_frame = let ref = mapping_ref
        (st::ConsumerState, view::ConsumerFrameView) -> begin
            handle_source_frame!(ref[], st, view)
            return nothing
        end
    end
    consumer_callbacks = ConsumerCallbacks(; on_frame! = on_frame)
    descriptor_assembler = Consumer.make_descriptor_assembler(consumer_state; callbacks = consumer_callbacks)
    control_assembler = Consumer.make_control_assembler(consumer_state)
    consumer_agent = ConsumerAgent(
        consumer_state,
        descriptor_assembler,
        control_assembler,
        ConsumerCounters(consumer_state.runtime.control.client, Int(consumer_id), "RateLimiterConsumer"),
    )

    on_hello = let ref = mapping_ref
        (st::ProducerState, msg::ConsumerHello.Decoder) -> begin
            apply_consumer_hello_rate!(ref[], msg)
            return nothing
        end
    end
    producer_callbacks = ProducerCallbacks(; on_consumer_hello! = on_hello)
    control_asm = Producer.make_control_assembler(producer_state; callbacks = producer_callbacks)
    qos_asm = Producer.make_qos_assembler(producer_state; callbacks = producer_callbacks)
    producer_agent = ProducerAgent(
        producer_state,
        control_asm,
        qos_asm,
        ProducerCounters(producer_state.runtime.control.client, Int(producer_id), "RateLimiterProducer"),
        producer_callbacks,
        nothing,
        PolledTimer(producer_cfg.qos_interval_ns),
    )

    max_stride = UInt32(0)
    for pool in producer_state.config.payload_pools
        max_stride = max(max_stride, pool.stride_bytes)
    end
    pending = RateLimiterPending(
        false,
        UInt64(0),
        UInt64(0),
        SlotHeader(UInt64(0), UInt64(0), UInt32(0), UInt32(0), UInt32(0), UInt32(0), UInt16(0), TensorHeader(
            Dtype.UNKNOWN,
            MajorOrder.ROW,
            UInt8(0),
            UInt8(0),
            ProgressUnit.NONE,
            UInt32(0),
            ntuple(_ -> Int32(0), Val(MAX_DIMS)),
            ntuple(_ -> Int32(0), Val(MAX_DIMS)),
        )),
        UInt32(0),
        Vector{UInt8}(undef, Int(max_stride)),
    )

    metadata_pub =
        config.forward_metadata && !isempty(config.metadata_channel) && mapping.metadata_stream_id != 0 ?
            Aeron.add_publication(client, config.metadata_channel, Int32(mapping.metadata_stream_id)) : nothing

    mapping_state = RateLimiterMappingState(
        mapping,
        consumer_agent,
        producer_agent,
        metadata_pub,
        Aeron.BufferClaim(),
        UInt32(0),
        mapping.max_rate_hz,
        UInt64(0),
        UInt64(0),
        pending,
        FixedSizeVectorDefault{Int32}(undef, MAX_DIMS),
        FixedSizeVectorDefault{Int32}(undef, MAX_DIMS),
    )
    mapping_ref[] = mapping_state
    return mapping_state
end

"""
Initialize the rate limiter for the given mappings.
"""
function init_rate_limiter(
    config::RateLimiterConfig,
    mappings::Vector{RateLimiterMapping};
    client::Aeron.Client,
    driver_work_fn::Union{Nothing, Function} = nothing,
)
    validate_rate_limiter_config!(config)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    mapping_states = RateLimiterMappingState[]
    mapping_by_source = Dict{UInt32, RateLimiterMappingState}()
    for mapping in mappings
        mapping.source_stream_id == 0 && throw(ArgumentError("source_stream_id required"))
        mapping.dest_stream_id == 0 && throw(ArgumentError("dest_stream_id required"))
        state = init_mapping_state(config, mapping, client; driver_work_fn = driver_work_fn)
        push!(mapping_states, state)
        mapping_by_source[mapping.source_stream_id] = state
    end

    metadata_sub =
        config.forward_metadata && !isempty(config.metadata_channel) && config.metadata_stream_id != 0 ?
            Aeron.add_subscription(client, config.metadata_channel, config.metadata_stream_id) : nothing

    control_sub = config.forward_progress && config.source_control_stream_id != 0 ?
        Aeron.add_subscription(client, config.control_channel, config.source_control_stream_id) : nothing
    control_pub = config.forward_progress && config.dest_control_stream_id != 0 ?
        Aeron.add_publication(client, config.control_channel, config.dest_control_stream_id) : nothing

    qos_sub = config.forward_qos && config.source_qos_stream_id != 0 ?
        Aeron.add_subscription(client, config.qos_channel, config.source_qos_stream_id) : nothing
    qos_pub = config.forward_qos && config.dest_qos_stream_id != 0 ?
        Aeron.add_publication(client, config.qos_channel, config.dest_qos_stream_id) : nothing

    state = RateLimiterState(
        config,
        clock,
        mapping_states,
        mapping_by_source,
        metadata_sub,
        nothing,
        control_sub,
        control_pub,
        nothing,
        qos_sub,
        qos_pub,
        nothing,
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
    )

    if metadata_sub !== nothing
        announce_decoder = DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        meta_decoder = DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        handler = Aeron.FragmentHandler(state) do st, buffer, _
            header = MessageHeader.Decoder(buffer, 0)
            if MessageHeader.schemaId(header) != MessageHeader.sbe_schema_id(MessageHeader.Decoder)
                return nothing
            end
            template_id = MessageHeader.templateId(header)
            if template_id == TEMPLATE_DATA_SOURCE_ANNOUNCE
                DataSourceAnnounce.wrap!(announce_decoder, buffer, 0; header = header)
                mapping_state = mapping_for_source(st, DataSourceAnnounce.streamId(announce_decoder))
                mapping_state === nothing && return nothing
                forward_data_source_announce!(st, mapping_state, announce_decoder)
            elseif template_id == TEMPLATE_DATA_SOURCE_META
                DataSourceMeta.wrap!(meta_decoder, buffer, 0; header = header)
                mapping_state = mapping_for_source(st, DataSourceMeta.streamId(meta_decoder))
                mapping_state === nothing && return nothing
                forward_data_source_meta!(st, mapping_state, meta_decoder)
            end
            nothing
        end
        state.metadata_asm = Aeron.FragmentAssembler(handler)
    end

    if control_sub !== nothing
        progress_decoder = FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        handler = Aeron.FragmentHandler(state) do st, buffer, _
            header = MessageHeader.Decoder(buffer, 0)
            if MessageHeader.schemaId(header) != MessageHeader.sbe_schema_id(MessageHeader.Decoder)
                return nothing
            end
            if MessageHeader.templateId(header) == TEMPLATE_FRAME_PROGRESS
                FrameProgress.wrap!(progress_decoder, buffer, 0; header = header)
                mapping_state = mapping_for_source(st, FrameProgress.streamId(progress_decoder))
                mapping_state === nothing && return nothing
                forward_progress!(st, mapping_state, progress_decoder)
            end
            nothing
        end
        state.control_asm = Aeron.FragmentAssembler(handler)
    end

    if qos_sub !== nothing
        qos_prod_decoder = QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        qos_cons_decoder = QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        handler = Aeron.FragmentHandler(state) do st, buffer, _
            header = MessageHeader.Decoder(buffer, 0)
            if MessageHeader.schemaId(header) != MessageHeader.sbe_schema_id(MessageHeader.Decoder)
                return nothing
            end
            template_id = MessageHeader.templateId(header)
            if template_id == TEMPLATE_QOS_PRODUCER
                QosProducer.wrap!(qos_prod_decoder, buffer, 0; header = header)
                mapping_state = mapping_for_source(st, QosProducer.streamId(qos_prod_decoder))
                mapping_state === nothing && return nothing
                forward_qos_producer!(st, mapping_state, qos_prod_decoder)
            elseif template_id == TEMPLATE_QOS_CONSUMER
                QosConsumer.wrap!(qos_cons_decoder, buffer, 0; header = header)
                mapping_state = mapping_for_source(st, QosConsumer.streamId(qos_cons_decoder))
                mapping_state === nothing && return nothing
                forward_qos_consumer!(st, mapping_state, qos_cons_decoder)
            end
            nothing
        end
        state.qos_asm = Aeron.FragmentAssembler(handler)
    end

    return state
end
