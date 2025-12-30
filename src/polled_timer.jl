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

@inline function due!(timer::PolledTimer, now_ns::UInt64)
    if now_ns - timer.last_ns >= timer.interval_ns
        timer.last_ns = now_ns
        return true
    end
    return false
end
