"""
Create a FragmentAssembler for the control subscription.
"""
function make_control_assembler(state::ProducerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_CONSUMER_HELLO
            ConsumerHello.wrap!(st.hello_decoder, buffer, 0; header = header)
            handle_consumer_hello!(st, st.hello_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll the control subscription for ConsumerHello messages.
"""
@inline function poll_control!(
    state::ProducerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.sub_control, assembler, fragment_limit)
end

"""
Refresh activity_timestamp_ns in all mapped superblocks.
"""
function refresh_activity_timestamps!(state::ProducerState)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    wrap_superblock!(state.superblock_encoder, state.header_mmap, 0)
    ShmRegionSuperblock.activityTimestampNs!(state.superblock_encoder, now_ns)

    for pmmap in values(state.payload_mmaps)
        wrap_superblock!(state.superblock_encoder, pmmap, 0)
        ShmRegionSuperblock.activityTimestampNs!(state.superblock_encoder, now_ns)
    end
    return nothing
end

@inline function (handler::ProducerAnnounceHandler)(state::ProducerState, now_ns::UInt64)
    emit_announce!(state)
    refresh_activity_timestamps!(state)
    return 1
end

@inline function (handler::ProducerQosHandler)(state::ProducerState, now_ns::UInt64)
    emit_qos!(state)
    return 1
end

function poll_timers!(state::ProducerState, now_ns::UInt64)
    return poll_timers!(state.timer_set, state, now_ns)
end

"""
Producer duty cycle: poll control, emit periodic messages, and return work count.
"""
function producer_do_work!(
    state::ProducerState,
    control_assembler::Aeron.FragmentAssembler;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count = 0
    work_count += poll_control!(state, control_assembler, fragment_limit)
    work_count += poll_timers!(state, now_ns)
    return work_count
end
