@testset "PolledTimer" begin
    timer = PolledTimer(UInt64(10))

    @test due!(timer, UInt64(5)) == false
    @test timer.last_ns == UInt64(0)

    @test due!(timer, UInt64(10)) == true
    @test timer.last_ns == UInt64(10)

    @test due!(timer, UInt64(15)) == false
    @test due!(timer, UInt64(20)) == true
    @test timer.last_ns == UInt64(20)

    reset!(timer, UInt64(7))
    @test timer.last_ns == UInt64(7)
end

struct TestHandler1 end
struct TestHandler2 end

@inline function (handler::TestHandler1)(state::Base.RefValue{Int}, now_ns::UInt64)
    state[] += 1
    return 1
end

@inline function (handler::TestHandler2)(state::Base.RefValue{Int}, now_ns::UInt64)
    state[] += 10
    return 0
end

@testset "TimerSet" begin
    timer_set = TimerSet(
        (PolledTimer(UInt64(5)), PolledTimer(UInt64(10))),
        (TestHandler1(), TestHandler2()),
    )
    state = Ref(0)

    @test poll_timers!(timer_set, state, UInt64(4)) == 0
    @test state[] == 0

    @test poll_timers!(timer_set, state, UInt64(5)) == 1
    @test state[] == 1

    @test poll_timers!(timer_set, state, UInt64(10)) == 1
    @test state[] == 12
end
