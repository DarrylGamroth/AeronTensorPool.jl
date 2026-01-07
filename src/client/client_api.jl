"""
High-level client context for TensorPool, modeled after Aeron.Context.
"""
mutable struct TensorPoolContext
    aeron_dir::String
    control_channel::String
    control_stream_id::Int32
    announce_channel::String
    announce_stream_id::Int32
    discovery_channel::String
    discovery_stream_id::Int32
    discovery_response_channel::String
    discovery_response_stream_id::UInt32
    use_invoker::Bool
    client_lock::Union{ReentrantLock, Nothing}
    attach_timeout_ns::UInt64
    attach_retry_interval_ns::UInt64
    discovery_timeout_ns::UInt64
    discovery_retry_interval_ns::UInt64
    keepalive_interval_ns::UInt64
    attach_purge_interval_ns::UInt64
end

"""
Create a TensorPoolContext from driver endpoints.
"""
function TensorPoolContext(endpoints::DriverEndpoints; kwargs...)
    return TensorPoolContext(;
        aeron_dir = endpoints.aeron_dir,
        control_channel = endpoints.control_channel,
        control_stream_id = endpoints.control_stream_id,
        announce_channel = endpoints.announce_channel,
        announce_stream_id = endpoints.announce_stream_id,
        kwargs...,
    )
end

"""
Create a TensorPoolContext with explicit settings.

Defaults follow Aeron-style choices (invoker disabled, timeouts in seconds).
"""
function TensorPoolContext(;
    aeron_dir::AbstractString = "",
    control_channel::AbstractString,
    control_stream_id::Int32,
    announce_channel::AbstractString = "",
    announce_stream_id::Int32 = Int32(0),
    discovery_channel::AbstractString = "",
    discovery_stream_id::Int32 = Int32(0),
    discovery_response_channel::AbstractString = "",
    discovery_response_stream_id::UInt32 = UInt32(0),
    use_invoker::Bool = false,
    client_lock::Union{ReentrantLock, Nothing} = nothing,
    attach_timeout_ns::UInt64 = UInt64(5_000_000_000),
    attach_retry_interval_ns::UInt64 = UInt64(1_000_000_000),
    discovery_timeout_ns::UInt64 = UInt64(5_000_000_000),
    discovery_retry_interval_ns::UInt64 = UInt64(1_000_000_000),
    keepalive_interval_ns::UInt64 = UInt64(1_000_000_000),
    attach_purge_interval_ns::UInt64 = UInt64(3_000_000_000),
)
    return TensorPoolContext(
        String(aeron_dir),
        String(control_channel),
        control_stream_id,
        String(announce_channel),
        announce_stream_id,
        String(discovery_channel),
        discovery_stream_id,
        String(discovery_response_channel),
        discovery_response_stream_id,
        use_invoker,
        client_lock,
        attach_timeout_ns,
        attach_retry_interval_ns,
        discovery_timeout_ns,
        discovery_retry_interval_ns,
        keepalive_interval_ns,
        attach_purge_interval_ns,
    )
end

"""
TensorPool client entry point (Aeron-style).
"""
mutable struct TensorPoolClient
    context::TensorPoolContext
    aeron_context::Union{Aeron.Context, Nothing}
    aeron_client::Aeron.Client
    owns_aeron_client::Bool
end

"""
Connect a TensorPoolClient using the given context.

If `aeron_client` is supplied, it is not owned and will not be closed.
"""
function connect(
    context::TensorPoolContext;
    aeron_client::Union{Aeron.Client, Nothing} = nothing,
    aeron_context::Union{Aeron.Context, Nothing} = nothing,
)
    if aeron_client !== nothing
        return TensorPoolClient(context, nothing, aeron_client, false)
    end

    local ctx = aeron_context === nothing ? Aeron.Context() : aeron_context
    if !isempty(context.aeron_dir)
        set_aeron_dir!(ctx, context.aeron_dir)
    end
    Aeron.use_conductor_agent_invoker!(ctx, context.use_invoker)
    local client = Aeron.Client(ctx)
    return TensorPoolClient(context, ctx, client, true)
end

"""
Close a TensorPoolClient and owned Aeron resources.
"""
function Base.close(client::TensorPoolClient)
    if client.owns_aeron_client
        close(client.aeron_client)
        if client.aeron_context !== nothing
            close(client.aeron_context)
        end
    end
    return nothing
end

"""
Do work for a TensorPoolClient in invoker mode.
"""
function do_work(client::TensorPoolClient)
    client.context.use_invoker || return 0
    return Aeron.do_work(client.aeron_client)
end

"""
Consumer handle returned by attach_consumer.
"""
mutable struct ConsumerHandle
    client::TensorPoolClient
    driver_client::DriverClientState
    consumer_agent::ConsumerAgent
end

"""
Producer handle returned by attach_producer.
"""
mutable struct ProducerHandle
    client::TensorPoolClient
    driver_client::DriverClientState
    producer_agent::ProducerAgent
end

"""
Return the underlying agent for a handle.
"""
agent(handle::ConsumerHandle) = handle.consumer_agent
agent(handle::ProducerHandle) = handle.producer_agent

"""
Return the underlying agent state for a handle.
"""
state(handle::ConsumerHandle) = handle.consumer_agent.state
state(handle::ProducerHandle) = handle.producer_agent.state

"""
Close a ConsumerHandle and its resources.
"""
function Base.close(handle::ConsumerHandle)
    Agent.on_close(handle.consumer_agent)
    try
        close(handle.driver_client.pub)
        close(handle.driver_client.sub)
    catch
    end
    return nothing
end

"""
Close a ProducerHandle and its resources.
"""
function Base.close(handle::ProducerHandle)
    Agent.on_close(handle.producer_agent)
    try
        close(handle.driver_client.pub)
        close(handle.driver_client.sub)
    catch
    end
    return nothing
end

"""
Do work for a ConsumerHandle.
"""
do_work(handle::ConsumerHandle) = Agent.do_work(handle.consumer_agent)

"""
Do work for a ProducerHandle.
"""
do_work(handle::ProducerHandle) = Agent.do_work(handle.producer_agent)

"""
Convenience wrapper for publishing a frame via a ProducerHandle.
"""
function offer_frame!(
    handle::ProducerHandle,
    payload::AbstractVector{UInt8},
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return offer_frame!(handle.producer_agent.state, payload, shape, strides, dtype, meta_version)
end

"""
Convenience wrapper for claiming a slot via a ProducerHandle.
"""
function try_claim_slot!(
    handle::ProducerHandle,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return try_claim_slot!(handle.producer_agent.state, values_len, shape, strides, dtype, meta_version)
end

"""
Convenience wrapper for committing a claimed slot via a ProducerHandle.
"""
function commit_slot!(
    handle::ProducerHandle,
    claim::SlotClaim,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return commit_slot!(
        handle.producer_agent.state,
        claim,
        values_len,
        shape,
        strides,
        dtype,
        meta_version,
    )
end

"""
Convenience wrapper for with_claimed_slot! via a ProducerHandle.
"""
function with_claimed_slot!(
    fill_fn::Function,
    handle::ProducerHandle,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return with_claimed_slot!(
        fill_fn,
        handle.producer_agent.state,
        values_len,
        shape,
        strides,
        dtype,
        meta_version,
    )
end

"""
Attach request handle for async attach flows.
"""
struct AttachRequestHandle
    driver_client::DriverClientState
    correlation_id::Int64
end

function discovery_enabled(context::TensorPoolContext)
    return !isempty(context.discovery_channel) && context.discovery_stream_id != 0
end

function resolve_discovery_response(context::TensorPoolContext)
    response_channel =
        isempty(context.discovery_response_channel) ? context.discovery_channel : context.discovery_response_channel
    response_stream_id =
        context.discovery_response_stream_id == 0 ? UInt32(context.discovery_stream_id + 1) :
        context.discovery_response_stream_id
    return response_channel, response_stream_id
end

function init_discovery_client_for_context(
    client::TensorPoolClient;
    response_channel::AbstractString,
    response_stream_id::UInt32,
)
    return init_discovery_client(
        client.aeron_client,
        client.context.discovery_channel,
        client.context.discovery_stream_id,
        response_channel,
        response_stream_id,
        UInt32(Aeron.client_id(client.aeron_client)),
    )
end

function close_discovery_client!(state::DiscoveryClientState)
    try
        close(state.pub)
        close(state.sub)
    catch
    end
    return nothing
end

function discover_stream!(
    client::TensorPoolClient;
    data_source_name::AbstractString = "",
    timeout_ns::UInt64 = client.context.discovery_timeout_ns,
    retry_interval_ns::UInt64 = client.context.discovery_retry_interval_ns,
)
    context = client.context
    discovery_enabled(context) || return nothing
    response_channel, response_stream_id = resolve_discovery_response(context)
    validate_discovery_endpoints(
        context.control_channel,
        context.control_stream_id,
        context.discovery_channel,
        context.discovery_stream_id,
        response_channel,
        response_stream_id,
    )

    state = init_discovery_client_for_context(
        client;
        response_channel = response_channel,
        response_stream_id = response_stream_id,
    )
    entries = Vector{DiscoveryEntry}()
    request_id = UInt64(0)
    last_send_ns = UInt64(0)
    deadline = UInt64(time_ns()) + timeout_ns
    try
        while UInt64(time_ns()) < deadline
            do_work(client)
            now_ns = UInt64(time_ns())
            if request_id == 0 || now_ns - last_send_ns > retry_interval_ns
                request_id = discover_streams!(state, entries; data_source_name = data_source_name)
                last_send_ns = now_ns
            end
            if request_id != 0
                slot = poll_discovery_response!(state, request_id)
                if slot !== nothing
                    if slot.status == DiscoveryStatus.OK && slot.count > 0
                        return slot.out_entries[1]
                    else
                        request_id = UInt64(0)
                    end
                end
            end
            yield()
        end
    finally
        close_discovery_client!(state)
    end
    throw(DiscoveryTimeoutError("discovery timed out"))
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
)
    deadline = UInt64(time_ns()) + timeout_ns
    last_retry_ns = UInt64(time_ns())
    while UInt64(time_ns()) < deadline
        do_work(client)
        now_ns = UInt64(time_ns())
        if now_ns - last_retry_ns > retry_interval_ns
            last_retry_ns = now_ns
        end
        attach = Control.poll_attach!(driver_client, correlation_id, now_ns)
        attach === nothing && (yield(); continue)
        attach.code == DriverResponseCode.OK || throw(AttachRejectedError(String(attach.error_message)))
        return attach
    end
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
    hooks::ConsumerHooks = NOOP_CONSUMER_HOOKS,
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
    attach = await_attach_response(client, request.driver_client, request.correlation_id)
    consumer_state = init_consumer_from_attach(
        settings,
        attach;
        driver_client = request.driver_client,
        client = client.aeron_client,
    )
    descriptor_asm = Consumer.make_descriptor_assembler(consumer_state; hooks = hooks)
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
    hooks::ProducerHooks = NOOP_PRODUCER_HOOKS,
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
    attach = await_attach_response(client, request.driver_client, request.correlation_id)
    producer_state = init_producer_from_attach(
        config,
        attach;
        driver_client = request.driver_client,
        client = client.aeron_client,
    )
    control_asm = Producer.make_control_assembler(producer_state; hooks = hooks)
    qos_asm = make_qos_assembler(producer_state; hooks = hooks)
    counters = ProducerCounters(producer_state.runtime.control.client, Int(config.producer_id), "Producer")
    producer_agent = ProducerAgent(producer_state, control_asm, qos_asm, counters)
    return ProducerHandle(client, request.driver_client, producer_agent)
end
