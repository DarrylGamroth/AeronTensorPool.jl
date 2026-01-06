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
Reset a timer's last fire time to `now_ns`.

Arguments:
- `timer`: timer to reset.
- `now_ns`: current time in nanoseconds.

Returns:
- `nothing`.
"""
@inline function reset!(timer::PolledTimer, now_ns::UInt64)
    timer.last_ns = now_ns
    return nothing
end

"""
Return true if a timer has expired at `now_ns`.

Arguments:
- `timer`: timer to check.
- `now_ns`: current time in nanoseconds.

Returns:
- `true` if expired, `false` otherwise.
"""
@inline function expired(timer::PolledTimer, now_ns::UInt64)
    timer.interval_ns == 0 && return false
    return now_ns - timer.last_ns >= timer.interval_ns
end

"""
Check if a timer is due and advance last fire time when due.

Arguments:
- `timer`: timer to check.
- `now_ns`: current time in nanoseconds.

Returns:
- `true` if due and advanced, `false` otherwise.
"""
@inline function due!(timer::PolledTimer, now_ns::UInt64)
    timer.interval_ns == 0 && return false
    if now_ns - timer.last_ns >= timer.interval_ns
        timer.last_ns = now_ns
        return true
    end
    return false
end

"""
Set a timer interval without changing last fire time.

Arguments:
- `timer`: timer to update.
- `interval_ns`: new interval in nanoseconds.

Returns:
- `nothing`.
"""
@inline function set_interval!(timer::PolledTimer, interval_ns::UInt64)
    timer.interval_ns = interval_ns
    return nothing
end

"""
Disable a timer so it never expires until re-enabled.

Arguments:
- `timer`: timer to disable.

Returns:
- `nothing`.
"""
@inline function disable!(timer::PolledTimer)
    timer.interval_ns = UInt64(0)
    return nothing
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

Arguments:
- `set`: timer set and handlers.
- `state`: handler state passed to each handler.
- `now_ns`: current time in nanoseconds.

Returns:
- Total work count from invoked handlers.
"""
@generated function poll!(set::TimerSet{TTimers, THandlers}, state, now_ns::UInt64) where {TTimers <: Tuple, THandlers <: Tuple}
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
