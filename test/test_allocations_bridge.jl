@testset "Allocation checks: bridge sender/receiver" begin
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
            prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = 2,
                epoch = 1,
                pool_id = 1,
            )
            src_header_uri = canonical_header_uri(dir, "tensorpool", 1, 1)
            src_pool_uri = canonical_pool_uri(dir, "tensorpool", 1, 1, 1)
            dst_header_uri = canonical_header_uri(dir, "tensorpool", 2, 1)
            dst_pool_uri = canonical_pool_uri(dir, "tensorpool", 2, 1, 1)

            src_pool = PayloadPoolConfig(UInt16(1), src_pool_uri, UInt32(4096), UInt32(8))
            dst_pool = PayloadPoolConfig(UInt16(1), dst_pool_uri, UInt32(4096), UInt32(8))

            src_producer_cfg = ProducerConfig(
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
                "bridge-alloc-src",
                src_header_uri,
                [src_pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )
            dst_producer_cfg = ProducerConfig(
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
                "bridge-alloc-dst",
                dst_header_uri,
                [dst_pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )
            src_consumer_cfg = ConsumerConfig(
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

            producer_src = Producer.init_producer(src_producer_cfg; client = client)
            producer_dst = Producer.init_producer(dst_producer_cfg; client = client)
            consumer_src = Consumer.init_consumer(src_consumer_cfg; client = client)

            mapping = BridgeMapping(UInt32(1), UInt32(2), "profile", UInt32(0), Int32(0), Int32(0))
            bridge_cfg = BridgeConfig(
                "bridge-alloc",
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
                false,
                UInt64(250_000_000),
                false,
                false,
                false,
                false,
            )
            sender = Bridge.init_bridge_sender(consumer_src, bridge_cfg, mapping; client = client)
            receiver = Bridge.init_bridge_receiver(bridge_cfg, mapping; producer_state = producer_dst, client = client)

            ctrl_asm = Consumer.make_control_assembler(consumer_src)
            ready = wait_for() do
                Producer.emit_announce!(producer_src)
                Aeron.poll(consumer_src.runtime.control.sub_control, ctrl_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                consumer_src.mappings.header_mmap !== nothing
            end
            @test ready

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]
            Producer.offer_frame!(producer_src, payload, shape, strides, Dtype.UINT8, UInt32(0))

            desc_buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_DESCRIPTOR_LEN)
            desc_enc = FrameDescriptor.Encoder(Vector{UInt8})
            FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)
            FrameDescriptor.streamId!(desc_enc, UInt32(1))
            FrameDescriptor.epoch!(desc_enc, UInt64(1))
            FrameDescriptor.seq!(desc_enc, UInt64(0))
            FrameDescriptor.timestampNs!(desc_enc, UInt64(time_ns()))
            FrameDescriptor.metaVersion!(desc_enc, UInt32(0))
            FrameDescriptor.traceId!(desc_enc, UInt64(0))
            desc_dec = FrameDescriptor.Decoder(Vector{UInt8})
            FrameDescriptor.wrap!(desc_dec, desc_buf, 0; header = MessageHeader.Decoder(desc_buf, 0))

            Bridge.bridge_send_frame!(sender, desc_dec)
            GC.gc()
            @test @allocated(Bridge.bridge_send_frame!(sender, desc_dec)) == 0

            announce = build_shm_pool_announce(
                stream_id = mapping.dest_stream_id,
                producer_id = UInt32(0),
                epoch = UInt64(1),
                layout_version = UInt32(1),
                nslots = UInt32(8),
                stride_bytes = UInt32(4096),
                header_uri = "shm:file?path=/dev/shm/dummy",
                pool_uri = "shm:file?path=/dev/shm/dummy",
            )
            Bridge.bridge_apply_source_announce!(receiver, announce.dec)

            header_buf = Vector{UInt8}(undef, AeronTensorPool.HEADER_SLOT_BYTES)
            slot_enc = AeronTensorPool.SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = AeronTensorPool.TensorHeaderMsg.Encoder(Vector{UInt8})
            AeronTensorPool.SlotHeaderMsg.wrap!(slot_enc, header_buf, 0)
            AeronTensorPool.SlotHeaderMsg.seqCommit!(slot_enc, UInt64(0))
            dims = Int32[4]
            strides = Int32[1]
            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(time_ns()),
                UInt32(0),
                UInt32(length(payload)),
                UInt32(0),
                UInt32(0),
                UInt16(1),
                Dtype.UINT8,
                AeronTensorPool.MajorOrder.ROW,
                UInt8(1),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                dims,
                strides,
            )

            chunk_buf = Vector{UInt8}(undef, AeronTensorPool.Bridge.bridge_chunk_message_length(AeronTensorPool.HEADER_SLOT_BYTES, length(payload)))
            chunk_enc = AeronTensorPool.BridgeFrameChunk.Encoder(Vector{UInt8})
            AeronTensorPool.BridgeFrameChunk.wrap_and_apply_header!(chunk_enc, chunk_buf, 0)
            AeronTensorPool.BridgeFrameChunk.streamId!(chunk_enc, mapping.dest_stream_id)
            AeronTensorPool.BridgeFrameChunk.epoch!(chunk_enc, UInt64(1))
            AeronTensorPool.BridgeFrameChunk.seq!(chunk_enc, UInt64(0))
            AeronTensorPool.BridgeFrameChunk.chunkIndex!(chunk_enc, UInt32(0))
            AeronTensorPool.BridgeFrameChunk.chunkCount!(chunk_enc, UInt32(1))
            AeronTensorPool.BridgeFrameChunk.payloadLength!(chunk_enc, UInt32(length(payload)))
            AeronTensorPool.BridgeFrameChunk.headerIncluded!(chunk_enc, AeronTensorPool.BridgeBool.TRUE)
            AeronTensorPool.BridgeFrameChunk.headerBytes!(chunk_enc, header_buf)
            AeronTensorPool.BridgeFrameChunk.payloadBytes!(chunk_enc, payload)
            chunk_dec = AeronTensorPool.BridgeFrameChunk.Decoder(Vector{UInt8})
            AeronTensorPool.BridgeFrameChunk.wrap!(chunk_dec, chunk_buf, 0; header = AeronTensorPool.ShmTensorpoolBridge.MessageHeader.Decoder(chunk_buf, 0))

            GC.gc()
            @test @allocated(Bridge.bridge_receive_chunk!(receiver, chunk_dec, UInt64(time_ns()))) == 0
        end
    end
end
