"""
Attach request handle for async attach flows.
"""
struct AttachRequestHandle
    driver_client::DriverClientState
    correlation_id::Int64
end

function init_driver_client_for_context(
    client::TensorPoolClient,
    role::DriverRole.SbeEnum;
    control_channel::AbstractString = client.context.control_channel,
    control_stream_id::Int32 = client.context.control_stream_id,
    client_id::UInt32,
)
    return init_driver_client(
        client.aeron_client,
        control_channel,
        control_stream_id,
        client_id,
        role;
        keepalive_interval_ns = client.context.keepalive_interval_ns,
        attach_purge_interval_ns = client.context.attach_purge_interval_ns,
    )
end

function await_attach_response(
    client::TensorPoolClient,
    driver_client::DriverClientState,
    correlation_id::Int64;
    timeout_ns::UInt64 = client.context.attach_timeout_ns,
    retry_interval_ns::UInt64 = client.context.attach_retry_interval_ns,
    retry_fn::Union{Nothing, Function} = nothing,
)
    pending = Int64[correlation_id]
    deadline = UInt64(time_ns()) + timeout_ns
    last_retry_ns = UInt64(time_ns())
    while UInt64(time_ns()) < deadline
        do_work(client)
        now_ns = UInt64(time_ns())
        attach = Control.poll_attach_any!(driver_client, pending, now_ns)
        if attach !== nothing
            @tp_info "attach response received" correlation_id = attach.correlation_id code = attach.code lease_id =
                attach.lease_id
            attach.code == DriverResponseCode.OK || throw(AttachRejectedError(String(attach.error_message)))
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
    @tp_warn "attach response timed out" correlation_id = correlation_id timeout_ns = timeout_ns
    throw(AttachTimeoutError("attach timed out"))
end

"""
Send a consumer attach request and return an AttachRequestHandle.
"""
function request_attach_consumer(
    client::TensorPoolClient,
    settings::ConsumerConfig;
    stream_id::UInt32 = settings.stream_id,
    control_channel::AbstractString = client.context.control_channel,
    control_stream_id::Int32 = client.context.control_stream_id,
)
    @tp_info "request attach consumer" stream_id = stream_id client_id = settings.consumer_id control_channel =
        control_channel control_stream_id = control_stream_id
    driver_client = init_driver_client_for_context(
        client,
        DriverRole.CONSUMER;
        control_channel = control_channel,
        control_stream_id = control_stream_id,
        client_id = settings.consumer_id,
    )
    correlation_id = send_attach_request!(
        driver_client;
        stream_id = stream_id,
        expected_layout_version = settings.expected_layout_version,
        max_dims = UInt8(MAX_DIMS),
        require_hugepages = settings.require_hugepages,
    )
    correlation_id == 0 && throw(AttachRejectedError("attach request send failed"))
    return AttachRequestHandle(driver_client, correlation_id)
end

"""
Send a producer attach request and return an AttachRequestHandle.
"""
function request_attach_producer(
    client::TensorPoolClient,
    config::ProducerConfig;
    stream_id::UInt32 = config.stream_id,
    control_channel::AbstractString = client.context.control_channel,
    control_stream_id::Int32 = client.context.control_stream_id,
)
    @tp_info "request attach producer" stream_id = stream_id client_id = config.producer_id control_channel =
        control_channel control_stream_id = control_stream_id
    driver_client = init_driver_client_for_context(
        client,
        DriverRole.PRODUCER;
        control_channel = control_channel,
        control_stream_id = control_stream_id,
        client_id = config.producer_id,
    )
    correlation_id = send_attach_request!(
        driver_client;
        stream_id = stream_id,
        expected_layout_version = config.layout_version,
        max_dims = UInt8(MAX_DIMS),
    )
    correlation_id == 0 && throw(AttachRejectedError("attach request send failed"))
    return AttachRequestHandle(driver_client, correlation_id)
end

"""
Poll an attach request handle for completion.
"""
function poll_attach!(
    request::AttachRequestHandle,
    now_ns::UInt64 = UInt64(time_ns()),
)
    return poll_attach!(request.driver_client, request.correlation_id, now_ns)
end

"""
Attach a consumer using the high-level client API.
"""
function attach_consumer(
    client::TensorPoolClient,
    settings::ConsumerConfig;
    discover::Bool = true,
    data_source_name::AbstractString = "",
    callbacks::Union{ConsumerCallbacks, ClientCallbacks} = Consumer.NOOP_CONSUMER_CALLBACKS,
)
    stream_id = settings.stream_id
    control_channel = client.context.control_channel
    control_stream_id = client.context.control_stream_id

    if discover && discovery_enabled(client.context)
        entry = discover_stream!(client; data_source_name = data_source_name)
        stream_id = entry.stream_id
        settings.stream_id = stream_id
        if !isempty(entry.driver_control_channel) && entry.driver_control_stream_id != 0
            control_channel = String(entry.driver_control_channel)
            control_stream_id = Int32(entry.driver_control_stream_id)
        end
    end

    request = request_attach_consumer(
        client,
        settings;
        stream_id = stream_id,
        control_channel = control_channel,
        control_stream_id = control_stream_id,
    )
    attach = await_attach_response(
        client,
        request.driver_client,
        request.correlation_id;
        retry_fn = () -> send_attach_request!(
            request.driver_client;
            stream_id = stream_id,
            expected_layout_version = settings.expected_layout_version,
            max_dims = UInt8(MAX_DIMS),
            require_hugepages = settings.require_hugepages,
        ),
    )
    consumer_state = Consumer.init_consumer_from_attach(
        settings,
        attach;
        driver_client = request.driver_client,
        client = client.aeron_client,
    )
    consumer_cbs = consumer_callbacks(callbacks)
    descriptor_asm = Consumer.make_descriptor_assembler(consumer_state; callbacks = consumer_cbs)
    control_asm = Consumer.make_control_assembler(consumer_state)
    counters = ConsumerCounters(consumer_state.runtime.control.client, Int(settings.consumer_id), "Consumer")
    consumer_agent = ConsumerAgent(consumer_state, descriptor_asm, control_asm, counters)
    return ConsumerHandle(client, request.driver_client, consumer_agent)
end

"""
Attach a producer using the high-level client API.
"""
function attach_producer(
    client::TensorPoolClient,
    config::ProducerConfig;
    discover::Bool = true,
    data_source_name::AbstractString = "",
    callbacks::Union{ProducerCallbacks, ClientCallbacks} = Producer.NOOP_PRODUCER_CALLBACKS,
    qos_monitor::Union{AbstractQosMonitor, Nothing} = nothing,
    qos_interval_ns::UInt64 = config.qos_interval_ns,
)
    stream_id = config.stream_id
    control_channel = client.context.control_channel
    control_stream_id = client.context.control_stream_id

    if discover && discovery_enabled(client.context)
        entry = discover_stream!(client; data_source_name = data_source_name)
        stream_id = entry.stream_id
        if !isempty(entry.driver_control_channel) && entry.driver_control_stream_id != 0
            control_channel = String(entry.driver_control_channel)
            control_stream_id = Int32(entry.driver_control_stream_id)
        end
    end

    request = request_attach_producer(
        client,
        config;
        stream_id = stream_id,
        control_channel = control_channel,
        control_stream_id = control_stream_id,
    )
    attach = await_attach_response(
        client,
        request.driver_client,
        request.correlation_id;
        retry_fn = () -> send_attach_request!(
            request.driver_client;
            stream_id = stream_id,
            expected_layout_version = config.layout_version,
            max_dims = UInt8(MAX_DIMS),
        ),
    )
    producer_state = Producer.init_producer_from_attach(
        config,
        attach;
        driver_client = request.driver_client,
        client = client.aeron_client,
    )
    producer_cbs = producer_callbacks(callbacks)
    control_asm = Producer.make_control_assembler(producer_state; callbacks = producer_cbs)
    qos_asm = Producer.make_qos_assembler(producer_state; callbacks = producer_cbs)
    counters = ProducerCounters(producer_state.runtime.control.client, Int(config.producer_id), "Producer")
    producer_agent = ProducerAgent(
        producer_state,
        control_asm,
        qos_asm,
        counters,
        producer_cbs,
        qos_monitor,
        PolledTimer(qos_interval_ns),
    )
    return ProducerHandle(client, request.driver_client, producer_agent)
end
