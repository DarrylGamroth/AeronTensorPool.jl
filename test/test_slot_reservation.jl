@testset "Slot reservation" begin
    with_embedded_driver() do driver
        cfg = ProducerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(1001),
            Int32(1002),
            Int32(1003),
            Int32(1004),
            UInt32(1),
            UInt32(2),
            UInt32(1),
            UInt32(8),
            "",
            "tensorpool",
            "test-producer",
            "shm:file?path=/dev/shm/tp_header_resv",
            [PayloadPoolConfig(UInt16(1), "shm:file?path=/dev/shm/tp_pool_resv", UInt32(64), UInt32(8))],
            UInt8(MAX_DIMS),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(250_000),
            UInt64(65536),
        )

        state = init_producer(cfg)
        try
            res = reserve_slot!(state, UInt16(1))
            @test res.seq == UInt64(0)
            @test res.header_index == UInt32(0)
            @test res.payload_slot == UInt32(0)
            @test res.stride_bytes == 64
            @test state.seq == UInt64(1)
        finally
            close_producer_state!(state)
        end
    end
end
