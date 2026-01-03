@inline function (handler::SupervisorLivenessHandler)(state::SupervisorState, now_ns::UInt64)
    return check_liveness!(state, now_ns) ? 1 : 0
end

function poll_timers!(state::SupervisorState, now_ns::UInt64)
    return poll_timers!(state.timer_set, state, now_ns)
end

"""
Create a FragmentAssembler for the control subscription.
"""
function make_control_assembler(state::SupervisorState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.runtime.announce_decoder, buffer, 0; header = header)
            handle_shm_pool_announce!(st, st.runtime.announce_decoder)
        elseif template_id == TEMPLATE_CONSUMER_HELLO
            ConsumerHello.wrap!(st.runtime.hello_decoder, buffer, 0; header = header)
            handle_consumer_hello!(st, st.runtime.hello_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a FragmentAssembler for the QoS subscription.
"""
function make_qos_assembler(state::SupervisorState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_QOS_PRODUCER
            QosProducer.wrap!(st.runtime.qos_producer_decoder, buffer, 0; header = header)
            handle_qos_producer!(st, st.runtime.qos_producer_decoder)
        elseif template_id == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.runtime.qos_consumer_decoder, buffer, 0; header = header)
            handle_qos_consumer!(st, st.runtime.qos_consumer_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll the control subscription for announce and hello messages.
"""
@inline function poll_control!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.control.sub_control, assembler, fragment_limit)
end

"""
Poll the QoS subscription for producer/consumer QoS messages.
"""
@inline function poll_qos!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_qos, assembler, fragment_limit)
end

"""
Supervisor duty cycle: poll subscriptions, check liveness, and return work count.
"""
function supervisor_do_work!(
    state::SupervisorState,
    control_assembler::Aeron.FragmentAssembler,
    qos_assembler::Aeron.FragmentAssembler;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count = 0
    work_count += poll_control!(state, control_assembler, fragment_limit)
    work_count += poll_qos!(state, qos_assembler, fragment_limit)
    work_count += poll_timers!(state, now_ns)
    return work_count
end
