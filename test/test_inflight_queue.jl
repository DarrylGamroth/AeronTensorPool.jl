@testset "InflightQueue" begin
    q = InflightQueue(2)
    @test isempty(q)
    @test !isfull(q)

    r1 = SlotClaim(UInt64(0), UInt32(0), UInt16(1), UInt32(0), Ptr{UInt8}(1), 64)
    r2 = SlotClaim(UInt64(1), UInt32(1), UInt16(1), UInt32(1), Ptr{UInt8}(2), 64)

    push!(q, r1)
    @test first(q).seq == UInt64(0)
    push!(q, r2)
    @test isfull(q)
    @test_throws ArgumentError push!(q, r2)

    out1 = popfirst!(q)
    @test out1.seq == UInt64(0)
    out2 = popfirst!(q)
    @test out2.seq == UInt64(1)
    @test_throws ArgumentError popfirst!(q)
end
