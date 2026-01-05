@testset "Bridge discovery integration" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            src_base = joinpath(dir, "src")
            dst_base = joinpath(dir, "dst")
            mkpath(src_base)
            mkpath(dst_base)

            prepare_canonical_shm_layout(
                src_base;
                namespace = "tensorpool",
                producer_instance_id = "bridge-disc-src",
                epoch = 1,
                pool_id = 1,
            )
            prepare_canonical_shm_layout(
                dst_base;
                namespace = "tensorpool",
                producer_instance_id = "bridge-disc-dst",
                epoch = 1,
                pool_id = 1,
            )

            src_header_uri = canonical_header_uri(src_base, "tensorpool", "bridge-disc-src", 1)
            src_pool_uri = canonical_pool_uri(src_base, "tensorpool", "bridge-disc-src", 1, 1)
            dst_header_uri = canonical_header_uri(dst_base, "tensorpool", "bridge-disc-dst", 1)
            dst_pool_uri = canonical_pool_uri(dst_base, "tensorpool", "bridge-disc-dst", 1, 1)

            src_pool = PayloadPoolConfig(UInt16(1), src_pool_uri, UInt32(4096), UInt32(8))
            dst_pool = PayloadPoolConfig(UInt16(1), dst_pool_uri, UInt32(4096), UInt32(8))

            src_config = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(1100),
                Int32(1000),
                Int32(1200),
                Int32(1300),
                UInt32(1),
                UInt32(10),
                UInt32(1),
                UInt32(8),
                src_base,
                "tensorpool",
                "bridge-disc-src",
                src_header_uri,
                [src_pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )
            dst_config = ProducerConfig(
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
                dst_base,
                "tensorpool",
                "bridge-disc-dst",
                dst_header_uri,
                [dst_pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )
            src_consumer = ConsumerSettings(
                aeron_dir,
                "aeron:ipc",
                Int32(1100),
                Int32(1000),
                Int32(1200),
                UInt32(1),
                UInt32(42),
                UInt32(1),
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                src_base,
                [src_base],
                false,
                UInt32(250),
                UInt32(65536),
                UInt32(0),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(3_000_000_000),
                "",
                UInt32(0),
                "",
                UInt32(0),
                false,
            )

            producer_src = init_producer(src_config; client = client)
            producer_dst = init_producer(dst_config; client = client)
            consumer_src = init_consumer(src_consumer; client = client)

            mapping = BridgeMapping(UInt32(1), UInt32(2), "profile", UInt32(0), Int32(0), Int32(0))
            bridge_cfg = BridgeConfig(
                "bridge-disc",
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
                UInt64(250_000_000),
                false,
                false,
                false,
            )

            bridge_sender = init_bridge_sender(consumer_src, bridge_cfg, mapping; client = client)
            bridge_receiver = init_bridge_receiver(bridge_cfg, mapping; producer_state = producer_dst, client = client)
            src_ctrl = make_control_assembler(consumer_src)

            discovery_cfg = DiscoveryConfig(
                bridge_cfg.control_channel,
                bridge_cfg.control_stream_id,
                bridge_cfg.control_channel,
                bridge_cfg.control_stream_id,
                "",
                0,
                "bridge-discovery",
                "aeron:ipc",
                UInt32(0),
                AeronTensorPool.DISCOVERY_MAX_RESULTS_DEFAULT,
                UInt64(5_000_000_000),
                AeronTensorPool.DISCOVERY_RESPONSE_BUF_BYTES,
                AeronTensorPool.DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
                AeronTensorPool.DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
            )
            discovery = init_discovery_provider(discovery_cfg; client = client)
            announce_asm = AeronTensorPool.make_announce_assembler(discovery)

            ready = wait_for() do
                emit_announce!(producer_src)
                Aeron.poll(consumer_src.runtime.control.sub_control, src_ctrl, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                AeronTensorPool.bridge_sender_do_work!(bridge_sender)
                AeronTensorPool.bridge_receiver_do_work!(bridge_receiver)
                Aeron.poll(discovery.runtime.sub_announce, announce_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                !isempty(discovery.entries)
            end
            @test ready
        end
    end
end
