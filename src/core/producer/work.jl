function poll_timers!(state::ProducerState, now_ns::UInt64)
    return Timers.poll_timers!(state.timer_set, state, now_ns)
end

"""
Producer duty cycle: poll control, emit periodic messages, and return work count.

Arguments:
- `state`: producer state.
- `control_assembler`: fragment assembler for control channel.
- `qos_assembler`: optional fragment assembler for QoS channel.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Work count (sum of polled fragments and timer work).
"""
function producer_do_work!(
    state::ProducerState,
    control_assembler::Aeron.FragmentAssembler;
    qos_assembler::Union{Aeron.FragmentAssembler, Nothing} = nothing,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count = 0
    work_count += poll_control!(state, control_assembler, fragment_limit)
    if qos_assembler !== nothing
        work_count += poll_qos!(state, qos_assembler, fragment_limit)
    end
    work_count += poll_timers!(state, now_ns)
    work_count += cleanup_consumer_streams!(state, now_ns)
    if !isnothing(state.driver_client)
        work_count += driver_client_do_work!(state.driver_client, now_ns)
        work_count += handle_driver_events!(state, now_ns)
    end
    return work_count
end
