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
