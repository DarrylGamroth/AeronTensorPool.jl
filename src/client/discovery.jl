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
