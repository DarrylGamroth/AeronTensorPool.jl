@testset "Bridge progress remap" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            stream_id = UInt32(2)
            prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = stream_id,
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(dir, "tensorpool", stream_id, 1)
            pool_uri = canonical_pool_uri(dir, "tensorpool", stream_id, 1, 1)
            pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))

            producer_cfg = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(2100),
                Int32(2000),
                Int32(2200),
                Int32(2300),
                stream_id,
                UInt32(20),
                UInt32(1),
                UInt32(8),
                dir,
                "tensorpool",
                "bridge-progress",
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

            mapping = BridgeMapping(UInt32(1), UInt32(2), "profile", UInt32(0), Int32(6001), Int32(7001))
            bridge_cfg = BridgeConfig(
                "bridge-progress",
                aeron_dir,
                "aeron:ipc",
                Int32(5000),
                "aeron:ipc",
                Int32(5001),
                "aeron:ipc",
                Int32(5002),
                Int32(2300),
                UInt32(1408),
                UInt32(512),
                UInt32(1024),
                UInt32(1_048_576),
                UInt64(250_000_000),
                false,
                false,
                true,
            )
            receiver = Bridge.init_bridge_receiver(bridge_cfg, mapping; producer_state = producer, client = client)
            sub = Aeron.add_subscription(client, "aeron:ipc", mapping.dest_control_stream_id)

            buffer = Vector{UInt8}(undef, AeronTensorPool.FRAME_PROGRESS_LEN)
            enc = FrameProgress.Encoder(Vector{UInt8})
            FrameProgress.wrap_and_apply_header!(enc, buffer, 0)
            FrameProgress.streamId!(enc, mapping.dest_stream_id)
            FrameProgress.epoch!(enc, UInt64(1))
            FrameProgress.frameId!(enc, UInt64(5))
            FrameProgress.payloadBytesFilled!(enc, UInt64(100))
            FrameProgress.state!(enc, AeronTensorPool.ShmTensorpoolControl.FrameProgressState.COMPLETE)

            local_index = UInt32(UInt64(5) & (UInt64(producer.config.nslots) - 1))
            FrameProgress.headerIndex!(enc, local_index + UInt32(1))
            dec = FrameProgress.Decoder(Vector{UInt8})
            FrameProgress.wrap!(dec, buffer, 0; header = MessageHeader.Decoder(buffer, 0))
            @test Bridge.bridge_publish_progress!(receiver, dec) == true

            FrameProgress.headerIndex!(enc, local_index)
            FrameProgress.wrap!(dec, buffer, 0; header = MessageHeader.Decoder(buffer, 0))
            ok = wait_for() do
                Bridge.bridge_publish_progress!(receiver, dec)
            end
            @test ok

            close(sub)
        end
    end
end
