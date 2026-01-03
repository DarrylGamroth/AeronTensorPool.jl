function poll_timers!(state::SupervisorState, now_ns::UInt64)
    return poll_timers!(state.timer_set, state, now_ns)
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
