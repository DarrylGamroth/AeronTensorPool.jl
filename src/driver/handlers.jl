"""
Handle a driver control message buffer.

Arguments:
- `state`: driver state.
- `buffer`: raw message buffer.

Returns:
- `true` if handled, `false` otherwise.
"""
function handle_driver_control!(state::DriverState, buffer::AbstractVector{UInt8})
    header = DriverMessageHeader.Decoder(buffer, 0)
    template_id = DriverMessageHeader.templateId(header)
    @info "driver control message" template_id

    if template_id == TEMPLATE_SHM_ATTACH_REQUEST
        ShmAttachRequest.wrap!(state.runtime.attach_decoder, buffer, 0; header = header)
        @info "attach request" correlation_id = ShmAttachRequest.correlationId(state.runtime.attach_decoder) stream_id =
            ShmAttachRequest.streamId(state.runtime.attach_decoder) client_id =
            ShmAttachRequest.clientId(state.runtime.attach_decoder) role =
            ShmAttachRequest.role(state.runtime.attach_decoder)
        driver_lifecycle_dispatch!(state, :AttachRequest)
    elseif template_id == TEMPLATE_SHM_DETACH_REQUEST
        ShmDetachRequest.wrap!(state.runtime.detach_decoder, buffer, 0; header = header)
        handle_detach_request!(state, state.runtime.detach_decoder)
    elseif template_id == TEMPLATE_SHM_LEASE_KEEPALIVE
        ShmLeaseKeepalive.wrap!(state.runtime.keepalive_decoder, buffer, 0; header = header)
        handle_keepalive!(state, state.runtime.keepalive_decoder)
    elseif template_id == TEMPLATE_SHM_DRIVER_SHUTDOWN_REQUEST
        ShmDriverShutdownRequest.wrap!(state.runtime.shutdown_request_decoder, buffer, 0; header = header)
        handle_shutdown_request!(state, state.runtime.shutdown_request_decoder)
    else
        return false
    end
    return true
end

"""
Create a control-channel fragment assembler for the driver.

Arguments:
- `state`: driver state.

Returns:
- `Aeron.FragmentAssembler` configured for driver control messages.
"""
function make_driver_control_assembler(state::DriverState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        handle_driver_control!(st, buffer)
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

@inline function poll_timers!(state::DriverState, now_ns::UInt64)
    return poll_timers!(state.timer_set, state, now_ns)
end

@inline function (handler::DriverAnnounceHandler)(state::DriverState, now_ns::UInt64)
    announce_all_streams!(state)
    return 1
end

@inline function (handler::DriverLeaseCheckHandler)(state::DriverState, now_ns::UInt64)
    check_leases!(state, now_ns)
    return 1
end

@inline function (handler::DriverShutdownHandler)(state::DriverState, now_ns::UInt64)
    driver_lifecycle_dispatch!(state, :ShutdownTimeout)
    return 1
end
