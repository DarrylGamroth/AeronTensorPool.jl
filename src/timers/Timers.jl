module Timers

include("polled_timer.jl")

export PolledTimer,
    TimerSet,
    reset!,
    expired,
    due!,
    set_interval!,
    disable!,
    poll_timers!

end
