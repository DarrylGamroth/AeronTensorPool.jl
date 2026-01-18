"""
Owning runtime for Aeron and control-plane resources.
"""
mutable struct TensorPoolRuntime
    context::TensorPoolContext
    aeron_context::Union{Aeron.Context, Nothing}
    aeron_client::Aeron.Client
    control::Union{ControlPlaneRuntime, Nothing}
    clock::Clocks.CachedEpochClock{Clocks.MonotonicClock}
    owns_aeron_client::Bool
    owns_control::Bool
end

"""
Create a TensorPoolRuntime that owns Aeron and control-plane resources.

If `aeron_client` is supplied, it is not owned and will not be closed.
"""
function TensorPoolRuntime(
    context::TensorPoolContext;
    aeron_client::Union{Aeron.Client, Nothing} = nothing,
    aeron_context::Union{Aeron.Context, Nothing} = nothing,
    control_runtime::Union{ControlPlaneRuntime, Nothing} = nothing,
    create_control::Bool = true,
    clock::Union{Clocks.CachedEpochClock{Clocks.MonotonicClock}, Nothing} = nothing,
)
    local ctx = aeron_context
    local client::Aeron.Client
    owns_aeron_client = false
    if aeron_client === nothing
        ctx = aeron_context === nothing ? Aeron.Context() : aeron_context
        if !isempty(context.aeron_dir)
            set_aeron_dir!(ctx, context.aeron_dir)
        end
        Aeron.use_conductor_agent_invoker!(ctx, context.use_invoker)
        client = Aeron.Client(ctx)
        owns_aeron_client = true
    else
        client = aeron_client
    end

    control = control_runtime
    owns_control = false
    if control === nothing && create_control
        pub_control = Aeron.add_publication(client, context.control_channel, context.control_stream_id)
        sub_control = Aeron.add_subscription(client, context.control_channel, context.control_stream_id)
        control = ControlPlaneRuntime(client, pub_control, sub_control)
        owns_control = true
    end

    runtime_clock = clock === nothing ? Clocks.CachedEpochClock(Clocks.MonotonicClock()) : clock
    return TensorPoolRuntime(context, ctx, client, control, runtime_clock, owns_aeron_client, owns_control)
end

"""
Construct a runtime, run `f`, and close owned resources.

This helper is intended for setup/teardown paths, not hot loops.
"""
function with_runtime(
    f::Function,
    context::TensorPoolContext;
    aeron_client::Union{Aeron.Client, Nothing} = nothing,
    aeron_context::Union{Aeron.Context, Nothing} = nothing,
    control_runtime::Union{ControlPlaneRuntime, Nothing} = nothing,
    create_control::Bool = true,
    clock::Union{Clocks.CachedEpochClock{Clocks.MonotonicClock}, Nothing} = nothing,
)
    runtime = TensorPoolRuntime(
        context;
        aeron_client = aeron_client,
        aeron_context = aeron_context,
        control_runtime = control_runtime,
        create_control = create_control,
        clock = clock,
    )
    try
        return f(runtime)
    finally
        close(runtime)
    end
end

"""
Close a TensorPoolRuntime and owned resources.
"""
function Base.close(runtime::TensorPoolRuntime)
    if runtime.owns_control && runtime.control !== nothing
        close(runtime.control.pub_control)
        close(runtime.control.sub_control)
    end
    if runtime.owns_aeron_client
        close(runtime.aeron_client)
        if runtime.aeron_context !== nothing
            close(runtime.aeron_context)
        end
    end
    return nothing
end
