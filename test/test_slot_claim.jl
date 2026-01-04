@testset "Slot claim" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do base_dir
            namespace = "tensorpool"
            producer_instance_id = "test-producer"
            epoch = 1
            epoch_dir = joinpath(base_dir, namespace, producer_instance_id, "epoch-$(epoch)")
            mkpath(epoch_dir)
            header_path = joinpath(epoch_dir, "header.ring")
            pool_path = joinpath(epoch_dir, "payload-1.pool")

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
                base_dir,
                namespace,
                producer_instance_id,
                "shm:file?path=$(header_path)",
                [PayloadPoolConfig(UInt16(1), "shm:file?path=$(pool_path)", UInt32(64), UInt32(8))],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
            )

            state = init_producer(cfg; client = client)
            try
                res = try_claim_slot!(state, UInt16(1))
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
end
