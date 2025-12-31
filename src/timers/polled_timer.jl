"""
Simple polling timer with fixed interval.
"""
mutable struct PolledTimer
    interval_ns::UInt64
    last_ns::UInt64
end

"""
Construct a PolledTimer with the given interval.
"""
@inline function PolledTimer(interval_ns::UInt64)
    return PolledTimer(interval_ns, UInt64(0))
end

"""
Reset a timer's last fire time to now_ns.
"""
@inline function reset!(timer::PolledTimer, now_ns::UInt64)
    timer.last_ns = now_ns
    return nothing
end

"""
Return true if a timer has expired at now_ns.
"""
@inline function expired(timer::PolledTimer, now_ns::UInt64)
    return now_ns - timer.last_ns >= timer.interval_ns
end

"""
Check if a timer is due and advance last fire time when due.
"""
@inline function due!(timer::PolledTimer, now_ns::UInt64)
    if now_ns - timer.last_ns >= timer.interval_ns
        timer.last_ns = now_ns
        return true
    end
    return false
end

"""
Fixed set of timers and handlers with compile-time dispatch.
"""
struct TimerSet{TTimers <: Tuple, THandlers <: Tuple}
    timers::TTimers
    handlers::THandlers
    function TimerSet(timers::TTimers, handlers::THandlers) where {TTimers <: Tuple, THandlers <: Tuple}
        length(timers) == length(handlers) || throw(ArgumentError("TimerSet length mismatch"))
        return new{TTimers, THandlers}(timers, handlers)
    end
end

"""
Poll all timers and invoke handlers that are due.
"""
@generated function poll_timers!(set::TimerSet{TTimers, THandlers}, state, now_ns::UInt64) where {TTimers <: Tuple, THandlers <: Tuple}
    n = length(TTimers.parameters)
    exprs = Vector{Any}(undef, n)
    for i in 1:n
        exprs[i] = quote
            if expired(set.timers[$i], now_ns)
                reset!(set.timers[$i], now_ns)
                work_count += set.handlers[$i](state, now_ns)
            end
        end
    end
    return quote
        work_count = 0
        $(Expr(:block, exprs...))
        return work_count
    end
end
