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
