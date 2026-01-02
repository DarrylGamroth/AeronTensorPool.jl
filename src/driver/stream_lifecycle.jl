@hsmdef mutable struct StreamLifecycle end

struct StreamLifecycleContext{StreamsT}
    streams::StreamsT
    stream_id::UInt32
    metrics::DriverMetrics
end

@statedef StreamLifecycle :Live
@statedef StreamLifecycle :Init :Live
@statedef StreamLifecycle :Active :Live
@statedef StreamLifecycle :Draining :Live
@statedef StreamLifecycle :Closed

@on_initial function(sm::StreamLifecycle, ::Root)
    return Hsm.transition!(sm, :Init)
end

@on_event function(sm::StreamLifecycle, ::Init, ::StreamProvisioned, _)
    return Hsm.transition!(sm, :Active)
end

@on_event function(sm::StreamLifecycle, ::Active, ::ProducerAttached, _)
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Active, ::ConsumerAttached, _)
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Active, ::ProducerDetached, _)
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Active, ::ConsumerDetached, _)
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Active, ::EpochBumped, _)
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Draining, ::DriverDraining, _)
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Live, ::DriverDraining, _)
    return Hsm.transition!(sm, :Draining)
end

@on_event function(sm::StreamLifecycle, ::Live, ::DriverShutdown, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::StreamLifecycle, ::Live, ::StreamIdle, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::StreamLifecycle, ::Live, ::StreamIdle, ctx::StreamLifecycleContext)
    delete!(ctx.streams, ctx.stream_id)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::StreamLifecycle, ::Live, ::Close, _)
    return Hsm.transition!(sm, :Closed)
end

@on_event function(sm::StreamLifecycle, ::Closed, ::Close, _)
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Root, event::Any, arg::DriverMetrics)
    arg.stream_hsm_unhandled += 1
    return Hsm.EventHandled
end

@on_event function(sm::StreamLifecycle, ::Root, event::Any, ctx::StreamLifecycleContext)
    ctx.metrics.stream_hsm_unhandled += 1
    return Hsm.EventHandled
end
