using Test
using AeronTensorPool

@testset "Discovery expiry" begin
    entry = AeronTensorPool.DiscoveryEntry()
    entry.last_announce_ns = UInt64(100)
    @test !AeronTensorPool.entry_expired(entry, UInt64(150), UInt64(100))
    @test AeronTensorPool.entry_expired(entry, UInt64(250), UInt64(100))
    entry.last_announce_ns = UInt64(0)
    @test AeronTensorPool.entry_expired(entry, UInt64(100), UInt64(100))
    @test !AeronTensorPool.entry_expired(entry, UInt64(100), UInt64(0))
end
