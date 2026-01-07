function reject_attach!(state::DriverState, msg::ShmAttachRequest.Decoder)
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

function begin_draining!(state::DriverState, sm::DriverLifecycle)
    timeout_ns = UInt64(state.config.policies.shutdown_timeout_ms) * 1_000_000
    timer = driver_shutdown_timer(state)
    set_interval!(timer, timeout_ns)
    reset!(timer, UInt64(Clocks.time_nanos(state.clock)))
    announce_all_streams!(state)
    return Hsm.transition!(sm, :Draining)
end

@on_event function(sm::DriverLifecycle, ::Running, ::ShutdownRequested, state::DriverState)
    return begin_draining!(state, sm)
end

@on_event function(sm::DriverLifecycle, ::Draining, ::ShutdownTimeout, state::DriverState)
    emit_driver_shutdown!(state, state.shutdown_reason, state.shutdown_message)
    disable!(driver_shutdown_timer(state))
    return Hsm.transition!(sm, :Stopped)
end

function driver_lifecycle_dispatch!(state::DriverState, event::Symbol)
    return Hsm.dispatch!(state.lifecycle, event, state)
end
