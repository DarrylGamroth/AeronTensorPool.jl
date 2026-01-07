@testset "Bridge backpressure handling" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                producer_instance_id = "bridge-backpressure",
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(dir, "tensorpool", "bridge-backpressure", 1)
            pool_uri = canonical_pool_uri(dir, "tensorpool", "bridge-backpressure", 1, 1)
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

            desc_buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_DESCRIPTOR_LEN)
            desc_enc = FrameDescriptor.Encoder(Vector{UInt8})
            FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)
            FrameDescriptor.streamId!(desc_enc, UInt32(1))
            FrameDescriptor.epoch!(desc_enc, UInt64(1))
            FrameDescriptor.seq!(desc_enc, UInt64(0))
            FrameDescriptor.headerIndex!(desc_enc, UInt32(0))
            FrameDescriptor.timestampNs!(desc_enc, UInt64(time_ns()))
            FrameDescriptor.metaVersion!(desc_enc, UInt32(0))
            desc_dec = FrameDescriptor.Decoder(Vector{UInt8})
            FrameDescriptor.wrap!(desc_dec, desc_buf, 0; header = MessageHeader.Decoder(desc_buf, 0))

            sent = Bridge.bridge_send_frame!(bridge_sender, desc_dec)
            if !sent
                @test bridge_sender.metrics.chunks_dropped == UInt64(1)
            end
        end
    end
end
