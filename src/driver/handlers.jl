"""
Handle a driver control-plane message.
"""
function handle_driver_control!(state::DriverState, buffer::AbstractVector{UInt8})
    header = DriverMessageHeader.Decoder(buffer, 0)
    template_id = DriverMessageHeader.templateId(header)

    if template_id == TEMPLATE_SHM_ATTACH_REQUEST
        ShmAttachRequest.wrap!(state.runtime.attach_decoder, buffer, 0; header = header)
        handle_attach_request!(state, state.runtime.attach_decoder)
    elseif template_id == TEMPLATE_SHM_DETACH_REQUEST
        ShmDetachRequest.wrap!(state.runtime.detach_decoder, buffer, 0; header = header)
        handle_detach_request!(state, state.runtime.detach_decoder)
    elseif template_id == TEMPLATE_SHM_LEASE_KEEPALIVE
        ShmLeaseKeepalive.wrap!(state.runtime.keepalive_decoder, buffer, 0; header = header)
        handle_keepalive!(state, state.runtime.keepalive_decoder)
    else
        return false
    end
    return true
end

"""
Create a FragmentAssembler for driver control messages.
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
