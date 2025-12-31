mutable struct PolledTimer
    interval_ns::UInt64
    last_ns::UInt64
end

@inline function PolledTimer(interval_ns::UInt64)
    return PolledTimer(interval_ns, UInt64(0))
end

@inline function reset!(timer::PolledTimer, now_ns::UInt64)
    timer.last_ns = now_ns
    return nothing
end

@inline function expired(timer::PolledTimer, now_ns::UInt64)
    return now_ns - timer.last_ns >= timer.interval_ns
end

@inline function due!(timer::PolledTimer, now_ns::UInt64)
    if now_ns - timer.last_ns >= timer.interval_ns
        timer.last_ns = now_ns
        return true
    end
    return false
end

struct TimerSet{TTimers <: Tuple, THandlers <: Tuple}
    timers::TTimers
    handlers::THandlers
    function TimerSet(timers::TTimers, handlers::THandlers) where {TTimers <: Tuple, THandlers <: Tuple}
        length(timers) == length(handlers) || throw(ArgumentError("TimerSet length mismatch"))
        return new{TTimers, THandlers}(timers, handlers)
    end
end

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
