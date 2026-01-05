using Test
using AeronTensorPool

@testset "Discovery endpoint validation" begin
    @test_throws DiscoveryConfigError validate_discovery_endpoints(
        "aeron:ipc",
        Int32(15000),
        "aeron:ipc",
        Int32(15000),
        "aeron:ipc",
        UInt32(16001),
    )
    @test_throws DiscoveryConfigError validate_discovery_endpoints(
        "aeron:ipc",
        Int32(15000),
        "aeron:ipc",
        Int32(16000),
        "aeron:ipc",
        UInt32(15000),
    )
    @test validate_discovery_endpoints(
        "aeron:ipc",
        Int32(15000),
        "aeron:ipc",
        Int32(16000),
        "aeron:ipc",
        UInt32(16001),
    )
end
