using Test

@testset "Bridge sender max_payload_bytes enforcement" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            base = joinpath(dir, "src")
            mkpath(base)
            prepare_canonical_shm_layout(
                base;
                namespace = "tensorpool",
                stream_id = 55,
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(base, "tensorpool", 55, 1)
            pool_uri = canonical_pool_uri(base, "tensorpool", 55, 1, 1)

            pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(1024), UInt32(8))
            producer_cfg = ProducerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(16500),
                Int32(16501),
                Int32(16502),
                Int32(16503),
                UInt32(55),
                UInt32(77),
                UInt32(1),
                UInt32(8),
                base,
                "tensorpool",
                "bridge-max",
                header_uri,
                [pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )
            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(16500),
                Int32(16501),
                Int32(16502),
                UInt32(55),
                UInt32(78),
                UInt32(1),
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                base,
                [base],
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

            producer_state = Producer.init_producer(producer_cfg; client = client)
            consumer_state = Consumer.init_consumer(consumer_cfg; client = client)
            try
                announce = build_shm_pool_announce(
                    stream_id = UInt32(55),
                    epoch = UInt64(1),
                    layout_version = UInt32(1),
                    nslots = UInt32(8),
                    stride_bytes = UInt32(1024),
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                )
                @test Consumer.handle_shm_pool_announce!(consumer_state, announce.dec)

                payload = fill(UInt8(0x2a), 512)
                shape = Int32[512]
                strides = Int32[1]
                @test Producer.offer_frame!(producer_state, payload, shape, strides, Dtype.UINT8, UInt32(0))
                seq = producer_state.seq - 1

                buf, desc = build_frame_descriptor(
                    stream_id = UInt32(55),
                    epoch = producer_state.epoch,
                    seq = seq,
                )
                mapping = BridgeMapping(UInt32(55), UInt32(56), "default", UInt32(0), Int32(0), Int32(0))
                bridge_cfg = BridgeConfig(
                    "bridge-max",
                    Aeron.MediaDriver.aeron_dir(driver),
                    "aeron:ipc",
                    Int32(16600),
                    "aeron:ipc",
                    Int32(16601),
                    "",
                    Int32(0),
                    Int32(0),
                    UInt32(1408),
                    UInt32(64),
                    UInt32(128),
                    UInt32(128),
                    false,
                    UInt64(1_000_000_000),
                    false,
                    false,
                    false,
                    false,
                )

                sender = Bridge.init_bridge_sender(consumer_state, bridge_cfg, mapping; client = client)
                sent = Bridge.bridge_send_frame!(sender, desc)
                @test sent == false
                @test sender.metrics.chunks_sent == 0
            finally
                close_producer_state!(producer_state)
                close_consumer_state!(consumer_state)
            end
        end
    end
end
