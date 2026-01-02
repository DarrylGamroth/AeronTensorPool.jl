@inline function driver_lifecycle_tick!(state::DriverState)
    state.work_count += poll_driver_control!(state)
    state.work_count += poll_timers!(state, state.now_ns)
    return Hsm.EventHandled
end

@on_event function(sm::DriverLifecycle, ::Running, ::Tick, state::DriverState)
    return driver_lifecycle_tick!(state)
end

@on_event function(sm::DriverLifecycle, ::Draining, ::Tick, state::DriverState)
    return driver_lifecycle_tick!(state)
end

@on_event function(sm::DriverLifecycle, ::Running, ::ShutdownRequested, ::DriverState)
    return Hsm.transition!(sm, :Draining)
end

@on_event function(sm::DriverLifecycle, ::Draining, ::ShutdownTimeout, ::DriverState)
    return Hsm.transition!(sm, :Stopped)
end

@inline function driver_lifecycle_dispatch!(state::DriverState, event::Symbol)
    return Hsm.dispatch!(state.lifecycle, event, state)
end
