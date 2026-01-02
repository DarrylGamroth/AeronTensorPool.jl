@inline function driver_lifecycle_tick!(state::DriverState)
    state.work_count += poll_driver_control!(state)
    state.work_count += poll_timers!(state, state.now_ns)
    return Hsm.EventHandled
end

@inline function reject_attach!(state::DriverState, msg::ShmAttachRequest.Decoder)
    correlation_id = ShmAttachRequest.correlationId(msg)
    emit_attach_response!(
        state,
        correlation_id,
        DriverResponseCode.REJECTED,
        "driver draining",
        nothing,
    )
    return Hsm.EventHandled
end

@on_event function(sm::DriverLifecycle, ::Running, ::AttachRequest, state::DriverState)
    handle_attach_request!(state, state.runtime.attach_decoder)
    return Hsm.EventHandled
end

@on_event function(sm::DriverLifecycle, ::Draining, ::AttachRequest, state::DriverState)
    return reject_attach!(state, state.runtime.attach_decoder)
end

@on_event function(sm::DriverLifecycle, ::Running, ::Tick, state::DriverState)
    return driver_lifecycle_tick!(state)
end

@on_event function(sm::DriverLifecycle, ::Draining, ::Tick, state::DriverState)
    return driver_lifecycle_tick!(state)
end

@on_event function(sm::DriverLifecycle, ::Running, ::ShutdownRequested, state::DriverState)
    timeout_ns = UInt64(state.config.policies.shutdown_timeout_ms) * 1_000_000
    set_interval!(state.timer_set.timers[3], timeout_ns)
    reset!(state.timer_set.timers[3], state.now_ns)
    return Hsm.transition!(sm, :Draining)
end

@on_event function(sm::DriverLifecycle, ::Draining, ::ShutdownTimeout, state::DriverState)
    emit_driver_shutdown!(state)
    set_interval!(state.timer_set.timers[3], UInt64(0))
    return Hsm.transition!(sm, :Stopped)
end

@inline function driver_lifecycle_dispatch!(state::DriverState, event::Symbol)
    return Hsm.dispatch!(state.lifecycle, event, state)
end
