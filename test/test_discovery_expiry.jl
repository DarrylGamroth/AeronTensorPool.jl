using Test
using AeronTensorPool

@testset "Discovery expiry" begin
    entry = AeronTensorPool.DiscoveryEntry()
    AeronTensorPool.set_interval!(entry.expiry_timer, UInt64(100))
    AeronTensorPool.reset!(entry.expiry_timer, UInt64(100))
    @test !AeronTensorPool.Agents.Discovery.entry_expired(entry, UInt64(150))
    @test AeronTensorPool.Agents.Discovery.entry_expired(entry, UInt64(250))

    entry.expiry_timer.last_ns = UInt64(0)
    @test AeronTensorPool.Agents.Discovery.entry_expired(entry, UInt64(100))

    AeronTensorPool.set_interval!(entry.expiry_timer, UInt64(0))
    AeronTensorPool.reset!(entry.expiry_timer, UInt64(100))
    @test !AeronTensorPool.Agents.Discovery.entry_expired(entry, UInt64(100))
end
