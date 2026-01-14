@testset "Bridge backpressure handling" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = 1,
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(dir, "tensorpool", 1, 1)
            pool_uri = canonical_pool_uri(dir, "tensorpool", 1, 1, 1)
            pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))

            producer_cfg = ProducerConfig(
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
                dir,
                "tensorpool",
                "bridge-backpressure",
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
                dir,
                [dir],
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
            producer = Producer.init_producer(producer_cfg; client = client)
            consumer = Consumer.init_consumer(consumer_cfg; client = client)

            mapping = BridgeMapping(UInt32(1), UInt32(2), "profile", UInt32(0), Int32(0), Int32(0))
            bridge_cfg = BridgeConfig(
                "bridge-backpressure",
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
                false,
            )

            bridge_sender = Bridge.init_bridge_sender(consumer, bridge_cfg, mapping; client = client)
            desc_asm = Consumer.make_descriptor_assembler(consumer)
            ctrl_asm = Consumer.make_control_assembler(consumer)

            ready = wait_for() do
                Producer.emit_announce!(producer)
                Aeron.poll(consumer.runtime.control.sub_control, ctrl_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                consumer.mappings.header_mmap !== nothing
            end
            @test ready

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]
            Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))

            (_, desc_dec) = build_frame_descriptor(
                stream_id = UInt32(1),
                epoch = UInt64(1),
                seq = UInt64(0),
                timestamp_ns = UInt64(time_ns()),
                meta_version = UInt32(0),
                trace_id = UInt64(0),
            )

            sent = Bridge.bridge_send_frame!(bridge_sender, desc_dec)
            if !sent
                @test bridge_sender.metrics.chunks_dropped == UInt64(1)
            end
        end
    end
end

@testset "Bridge sender drops oversized payloads" begin
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
                UInt32(11),
                UInt32(1),
                UInt32(8),
                dir,
                "tensorpool",
                "bridge-oversize",
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
                aeron_dir,
                "aeron:ipc",
                Int32(2100),
                Int32(2000),
                Int32(2200),
                UInt32(2),
                UInt32(43),
                UInt32(1),
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                dir,
                [dir],
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
            producer = Producer.init_producer(producer_cfg; client = client)
            consumer = Consumer.init_consumer(consumer_cfg; client = client)

            mapping = BridgeMapping(UInt32(2), UInt32(3), "profile", UInt32(0), Int32(0), Int32(0))
            bridge_cfg = BridgeConfig(
                "bridge-oversize",
                aeron_dir,
                "aeron:ipc",
                Int32(6000),
                "aeron:ipc",
                Int32(6001),
                "",
                Int32(0),
                Int32(0),
                UInt32(1408),
                UInt32(512),
                UInt32(65535),
                UInt32(2),
                UInt64(250_000_000),
                false,
                false,
                false,
                false,
            )

            bridge_sender = Bridge.init_bridge_sender(consumer, bridge_cfg, mapping; client = client)
            desc_asm = Consumer.make_descriptor_assembler(consumer)
            ctrl_asm = Consumer.make_control_assembler(consumer)

            ready = wait_for() do
                Producer.emit_announce!(producer)
                Aeron.poll(consumer.runtime.control.sub_control, ctrl_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                consumer.mappings.header_mmap !== nothing
            end
            @test ready

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]
            Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))

            (_, desc_dec) = build_frame_descriptor(
                stream_id = UInt32(2),
                epoch = UInt64(1),
                seq = UInt64(0),
                timestamp_ns = UInt64(time_ns()),
                meta_version = UInt32(0),
                trace_id = UInt64(0),
            )

            sent = Bridge.bridge_send_frame!(bridge_sender, desc_dec)
            @test sent == false
        end
    end
end
