"""
Handle a driver control message buffer.

Arguments:
- `state`: driver state.
- `buffer`: raw message buffer.

Returns:
- `true` if handled, `false` otherwise.
"""
function handle_driver_control!(state::DriverState, buffer::AbstractVector{UInt8})
    driver_header = DriverMessageHeader.Decoder(buffer, 0)
    schema_id = DriverMessageHeader.schemaId(driver_header)
    template_id = DriverMessageHeader.templateId(driver_header)
    @tp_info "driver control message" schema_id template_id

    if schema_id == ShmAttachRequest.sbe_schema_id(ShmAttachRequest.Decoder)
        if DriverMessageHeader.version(driver_header) > ShmAttachRequest.sbe_schema_version(ShmAttachRequest.Decoder)
            if template_id == TEMPLATE_SHM_ATTACH_REQUEST
                ShmAttachRequest.wrap!(state.runtime.attach_decoder, buffer, 0; header = driver_header)
                emit_attach_response!(
                    state,
                    ShmAttachRequest.correlationId(state.runtime.attach_decoder),
                    DriverResponseCode.UNSUPPORTED,
                    "unsupported driver schema version",
                    nothing,
                )
                return true
            end
            return false
        end
        if template_id == TEMPLATE_SHM_ATTACH_REQUEST
            ShmAttachRequest.wrap!(state.runtime.attach_decoder, buffer, 0; header = driver_header)
            @tp_info "attach request" correlation_id =
                ShmAttachRequest.correlationId(state.runtime.attach_decoder) stream_id =
                ShmAttachRequest.streamId(state.runtime.attach_decoder) client_id =
                ShmAttachRequest.clientId(state.runtime.attach_decoder) role =
                ShmAttachRequest.role(state.runtime.attach_decoder)
            driver_lifecycle_dispatch!(state, :AttachRequest)
        elseif template_id == TEMPLATE_SHM_DETACH_REQUEST
            ShmDetachRequest.wrap!(state.runtime.detach_decoder, buffer, 0; header = driver_header)
            handle_detach_request!(state, state.runtime.detach_decoder)
        elseif template_id == TEMPLATE_SHM_LEASE_KEEPALIVE
            ShmLeaseKeepalive.wrap!(state.runtime.keepalive_decoder, buffer, 0; header = driver_header)
            handle_keepalive!(state, state.runtime.keepalive_decoder)
        elseif template_id == TEMPLATE_SHM_DRIVER_SHUTDOWN_REQUEST
            ShmDriverShutdownRequest.wrap!(state.runtime.shutdown_request_decoder, buffer, 0; header = driver_header)
            handle_shutdown_request!(state, state.runtime.shutdown_request_decoder)
        else
            return false
        end
        return true
    end

    if schema_id == ConsumerHello.sbe_schema_id(ConsumerHello.Decoder)
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.version(header) > ConsumerHello.sbe_schema_version(ConsumerHello.Decoder)
            return false
        end
        if MessageHeader.templateId(header) == TEMPLATE_CONSUMER_HELLO
            ConsumerHello.wrap!(state.runtime.hello_decoder, buffer, 0; header = header)
            handle_consumer_hello!(state, state.runtime.hello_decoder)
            return true
        end
        return false
    end
    return false
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

function poll_timers!(state::DriverState, now_ns::UInt64)
    return Timers.poll!(state.timer_set, state, now_ns)
end

function find_consumer_lease(
    state::DriverState,
    consumer_id::UInt32,
    stream_id::UInt32,
)
    for lease in values(state.leases)
        if lease.client_id == consumer_id &&
           lease.role == DriverRole.CONSUMER &&
           lease.stream_id == stream_id
            return lease
        end
    end
    return nothing
end

function allocate_descriptor_stream_id!(state::DriverState, consumer_id::UInt32)
    existing = get(state.consumer_descriptor_streams, consumer_id, UInt32(0))
    existing != 0 && return existing
    range = state.config.descriptor_stream_id_range
    range === nothing && return UInt32(0)
    id, next_id = allocate_consumer_stream_id!(
        state.consumer_descriptor_streams,
        range,
        state.next_descriptor_stream_id,
    )
    id == 0 && return UInt32(0)
    state.next_descriptor_stream_id = next_id
    state.consumer_descriptor_streams[consumer_id] = id
    return id
end

function allocate_control_stream_id!(state::DriverState, consumer_id::UInt32)
    existing = get(state.consumer_control_streams, consumer_id, UInt32(0))
    existing != 0 && return existing
    range = state.config.control_stream_id_range
    range === nothing && return UInt32(0)
    id, next_id = allocate_consumer_stream_id!(
        state.consumer_control_streams,
        range,
        state.next_control_stream_id,
    )
    id == 0 && return UInt32(0)
    state.next_control_stream_id = next_id
    state.consumer_control_streams[consumer_id] = id
    return id
end

function handle_consumer_hello!(state::DriverState, msg::ConsumerHello.Decoder)
    stream_id = ConsumerHello.streamId(msg)
    consumer_id = ConsumerHello.consumerId(msg)
    descriptor_channel = String(ConsumerHello.descriptorChannel(msg))
    control_channel = String(ConsumerHello.controlChannel(msg))
    descriptor_stream_id = ConsumerHello.descriptorStreamId(msg)
    control_stream_id = ConsumerHello.controlStreamId(msg)
    descriptor_null = ConsumerHello.descriptorStreamId_null_value(ConsumerHello.Decoder)
    control_null = ConsumerHello.controlStreamId_null_value(ConsumerHello.Decoder)

    invalid_descriptor_request =
        !isempty(descriptor_channel) && (descriptor_stream_id == 0 || descriptor_stream_id == descriptor_null)
    invalid_control_request =
        !isempty(control_channel) && (control_stream_id == 0 || control_stream_id == control_null)
    descriptor_request =
        !invalid_descriptor_request && !isempty(descriptor_channel) && descriptor_stream_id != 0
    control_request =
        !invalid_control_request && !isempty(control_channel) && control_stream_id != 0

    if !descriptor_request && !control_request && !invalid_descriptor_request && !invalid_control_request
        return false
    end

    lease = find_consumer_lease(state, consumer_id, stream_id)
    lease === nothing && return false

    assigned_descriptor_channel = ""
    assigned_control_channel = ""
    assigned_descriptor_stream_id = UInt32(0)
    assigned_control_stream_id = UInt32(0)

    if invalid_descriptor_request || invalid_control_request
        @tp_info "consumer stream request invalid" stream_id consumer_id
        emit_driver_consumer_config!(
            state,
            stream_id,
            consumer_id;
            descriptor_channel = "",
            descriptor_stream_id = UInt32(0),
            control_channel = "",
            control_stream_id = UInt32(0),
        )
        return false
    end

    if descriptor_request
        assigned_descriptor_stream_id = allocate_descriptor_stream_id!(state, consumer_id)
        if assigned_descriptor_stream_id != 0
            assigned_descriptor_channel = descriptor_channel
        end
    end

    if control_request
        assigned_control_stream_id = allocate_control_stream_id!(state, consumer_id)
        if assigned_control_stream_id != 0
            assigned_control_channel = control_channel
        end
    end

    @tp_info "consumer stream assignment" stream_id consumer_id descriptor_stream_id =
        assigned_descriptor_stream_id control_stream_id = assigned_control_stream_id

    emit_driver_consumer_config!(
        state,
        stream_id,
        consumer_id;
        descriptor_channel = assigned_descriptor_channel,
        descriptor_stream_id = assigned_descriptor_stream_id,
        control_channel = assigned_control_channel,
        control_stream_id = assigned_control_stream_id,
    )
    return true
end

function (handler::DriverAnnounceHandler)(state::DriverState, now_ns::UInt64)
    announce_all_streams!(state)
    return 1
end

function (handler::DriverLeaseCheckHandler)(state::DriverState, now_ns::UInt64)
    check_leases!(state, now_ns)
    return 1
end

function (handler::DriverShutdownHandler)(state::DriverState, now_ns::UInt64)
    driver_lifecycle_dispatch!(state, :ShutdownTimeout)
    return 1
end
