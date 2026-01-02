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
    msg = state.runtime.attach_decoder
    publish_mode = ShmAttachRequest.publishMode(msg)
    if publish_mode == DriverPublishMode.EXISTING_OR_CREATE
        correlation_id = ShmAttachRequest.correlationId(msg)
        emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "driver draining (no create)",
            nothing,
        )
        return Hsm.EventHandled
    end
    return reject_attach!(state, msg)
end

@inline function begin_draining!(state::DriverState, sm::DriverLifecycle)
    timeout_ns = UInt64(state.config.policies.shutdown_timeout_ms) * 1_000_000
    timer = driver_shutdown_timer(state)
    set_interval!(timer, timeout_ns)
    reset!(timer, state.now_ns)
    announce_all_streams!(state)
    return Hsm.transition!(sm, :Draining)
end

@on_event function(sm::DriverLifecycle, ::Running, ::ShutdownRequested, state::DriverState)
    return begin_draining!(state, sm)
end

@on_event function(sm::DriverLifecycle, ::Draining, ::ShutdownTimeout, state::DriverState)
    emit_driver_shutdown!(state, state.shutdown_reason, state.shutdown_message)
    set_interval!(driver_shutdown_timer(state), UInt64(0))
    return Hsm.transition!(sm, :Stopped)
end

@inline function driver_lifecycle_dispatch!(state::DriverState, event::Symbol)
    return Hsm.dispatch!(state.lifecycle, event, state)
end
