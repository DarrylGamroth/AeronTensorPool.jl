@testset "Bridge assembly timeout" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = 2,
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(dir, "tensorpool", 2, 1)
            pool_uri = canonical_pool_uri(dir, "tensorpool", 2, 1, 1)
            pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))

            producer_cfg = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(2100),
                Int32(2000),
                Int32(2200),
                Int32(2300),
                UInt32(2),
                UInt32(20),
                UInt32(1),
                UInt32(8),
                dir,
                "tensorpool",
                "bridge-timeout",
                header_uri,
                [pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )
            producer = Producer.init_producer(producer_cfg; client = client)

            mapping = BridgeMapping(UInt32(1), UInt32(2), "profile", UInt32(0), Int32(0), Int32(0))
            bridge_cfg = BridgeConfig(
                "bridge-timeout",
                aeron_dir,
                "aeron:ipc",
                Int32(5000),
                "aeron:ipc",
                Int32(5001),
                "",
                Int32(0),
                Int32(0),
                UInt32(1408),
                UInt32(512),
                UInt32(65535),
                UInt32(1_048_576),
                UInt64(1_000_000),
                false,
                false,
                false,
            )
            receiver = Bridge.init_bridge_receiver(bridge_cfg, mapping; producer_state = producer, client = client)

            receiver.assembly.chunk_count = UInt32(1)
            AeronTensorPool.Clocks.fetch!(receiver.clock)
            now_ns = UInt64(AeronTensorPool.Clocks.time_nanos(receiver.clock))
            AeronTensorPool.set_interval!(receiver.assembly.assembly_timer, UInt64(1))
            AeronTensorPool.reset!(receiver.assembly.assembly_timer, now_ns - UInt64(2))

            Bridge.bridge_receiver_do_work!(receiver; fragment_limit = Int32(0))
            @test receiver.assembly.chunk_count == UInt32(0)
            @test receiver.metrics.assemblies_reset == UInt64(1)
        end
    end
end
