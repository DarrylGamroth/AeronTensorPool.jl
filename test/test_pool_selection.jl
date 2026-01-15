using Test

@testset "Payload pool selection" begin
    pools = [
        PayloadPoolConfig(UInt16(1), "shm:file?path=/dev/shm/p1", UInt32(4096), UInt32(8)),
        PayloadPoolConfig(UInt16(2), "shm:file?path=/dev/shm/p2", UInt32(1024), UInt32(8)),
        PayloadPoolConfig(UInt16(3), "shm:file?path=/dev/shm/p3", UInt32(2048), UInt32(8)),
    ]

    @test Producer.select_pool(pools, 100) == 2
    @test Producer.select_pool(pools, 1500) == 3
    @test Producer.select_pool(pools, 5000) == 0
end
