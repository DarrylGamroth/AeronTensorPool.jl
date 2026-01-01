"""
Create a FragmentAssembler for the descriptor subscription.
"""
function make_descriptor_assembler(state::ConsumerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
            FrameDescriptor.wrap!(st.runtime.desc_decoder, buffer, 0; header = header)
            try_read_frame!(st, st.runtime.desc_decoder) && (st.metrics.frames_ok += 1)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a FragmentAssembler for the control subscription.
"""
function make_control_assembler(state::ConsumerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.runtime.announce_decoder, buffer, 0; header = header)
            handle_shm_pool_announce!(st, st.runtime.announce_decoder)
        elseif template_id == TEMPLATE_CONSUMER_CONFIG
            ConsumerConfigMsg.wrap!(st.runtime.config_decoder, buffer, 0; header = header)
            apply_consumer_config!(st, st.runtime.config_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll the descriptor subscription and process frames.
"""
@inline function poll_descriptor!(
    state::ConsumerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_descriptor, assembler, fragment_limit)
end

"""
Poll the control subscription and apply mapping/config updates.
"""
@inline function poll_control!(
    state::ConsumerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_control, assembler, fragment_limit)
end

@inline function (handler::ConsumerHelloHandler)(state::ConsumerState, now_ns::UInt64)
    emit_consumer_hello!(state)
    return 1
end

@inline function (handler::ConsumerQosHandler)(state::ConsumerState, now_ns::UInt64)
    emit_qos!(state)
    return 1
end

function poll_timers!(state::ConsumerState, now_ns::UInt64)
    return poll_timers!(state.timer_set, state, now_ns)
end

"""
Consumer duty cycle: poll subscriptions, emit periodic messages, and return work count.
"""
function consumer_do_work!(
    state::ConsumerState,
    descriptor_assembler::Aeron.FragmentAssembler,
    control_assembler::Aeron.FragmentAssembler;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count = 0
    work_count += poll_descriptor!(state, descriptor_assembler, fragment_limit)
    work_count += poll_control!(state, control_assembler, fragment_limit)
    work_count += poll_timers!(state, now_ns)
    if !isnothing(state.driver_client)
        work_count += driver_client_do_work!(state.driver_client, now_ns)
        work_count += handle_driver_events!(state, now_ns)
    end
    return work_count
end
