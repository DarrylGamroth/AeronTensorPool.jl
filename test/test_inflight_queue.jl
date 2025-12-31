@testset "InflightQueue" begin
    q = InflightQueue(2)
    @test inflight_empty(q)
    @test !inflight_full(q)

    r1 = SlotReservation(UInt64(0), UInt32(0), UInt16(1), UInt32(0), Ptr{UInt8}(1), 64)
    r2 = SlotReservation(UInt64(1), UInt32(1), UInt16(1), UInt32(1), Ptr{UInt8}(2), 64)

    @test inflight_push!(q, r1)
    @test inflight_peek(q).seq == UInt64(0)
    @test inflight_push!(q, r2)
    @test inflight_full(q)
    @test inflight_push!(q, r2) == false

    out1 = inflight_pop!(q)
    @test out1.seq == UInt64(0)
    out2 = inflight_pop!(q)
    @test out2.seq == UInt64(1)
    @test inflight_pop!(q) === nothing
end
