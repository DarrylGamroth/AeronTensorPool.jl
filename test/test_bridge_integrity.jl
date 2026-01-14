using Test

@testset "Bridge CRC32C integrity validation" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            base = joinpath(dir, "dst")
            mkpath(base)
            prepare_canonical_shm_layout(
                base;
                namespace = "tensorpool",
                stream_id = 12,
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(base, "tensorpool", 12, 1)
            pool_uri = canonical_pool_uri(base, "tensorpool", 12, 1, 1)
            pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))

            producer_cfg = ProducerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(18010),
                Int32(18011),
                Int32(18012),
                Int32(18013),
                UInt32(12),
                UInt32(120),
                UInt32(1),
                UInt32(8),
                base,
                "tensorpool",
                "bridge-crc",
                header_uri,
                [pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )

            producer_state = Producer.init_producer(producer_cfg; client = client)
            producer_state.driver_client = nothing
            try
                mapping = BridgeMapping(UInt32(12), UInt32(12), "default", UInt32(0), Int32(0), Int32(0))
                bridge_cfg = BridgeConfig(
                    "bridge-crc",
                    Aeron.MediaDriver.aeron_dir(driver),
                    "aeron:ipc",
                    Int32(18100),
                    "aeron:ipc",
                    Int32(18101),
                    "",
                    Int32(0),
                    Int32(0),
                    UInt32(1408),
                    UInt32(512),
                    UInt32(1024),
                    UInt32(2048),
                    true,
                    UInt64(1_000_000_000),
                    false,
                    false,
                    false,
                    false,
                )
                receiver = Bridge.init_bridge_receiver(
                    bridge_cfg,
                    mapping;
                    producer_state = producer_state,
                    client = client,
                )

                announce = build_shm_pool_announce(
                    stream_id = UInt32(12),
                    epoch = UInt64(1),
                    layout_version = UInt32(1),
                    nslots = UInt32(8),
                    header_uri = header_uri,
                    payload_entries = [(
                        pool_id = UInt16(1),
                        nslots = UInt32(8),
                        stride_bytes = UInt32(4096),
                        uri = pool_uri,
                    )],
                )
                @test Bridge.bridge_apply_source_announce!(receiver, announce.dec)

                payload = fill(UInt8(0x2a), 16)
                header_bytes = Vector{UInt8}(undef, AeronTensorPool.HEADER_SLOT_BYTES)
                slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
                tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
                wrap_slot_header!(slot_enc, header_bytes, 0)
                write_slot_header!(
                    slot_enc,
                    tensor_enc,
                    UInt64(1),
                    UInt32(0),
                    UInt32(length(payload)),
                    UInt32(0),
                    UInt32(0),
                    UInt16(1),
                    Dtype.UINT8,
                    MajorOrder.ROW,
                    UInt8(1),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    vcat(Int32(length(payload)), zeros(Int32, AeronTensorPool.MAX_DIMS - 1)),
                    vcat(Int32(0), zeros(Int32, AeronTensorPool.MAX_DIMS - 1)),
                )
                SlotHeaderMsg.seqCommit!(slot_enc, UInt64(1) << 1)

                crc = Bridge.bridge_chunk_crc32c(header_bytes, payload, true)
                buf = Vector{UInt8}(
                    undef,
                    AeronTensorPool.Bridge.bridge_chunk_message_length(
                        AeronTensorPool.HEADER_SLOT_BYTES,
                        length(payload),
                    ),
                )
                chunk_enc = AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.Encoder(Vector{UInt8})
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.wrap_and_apply_header!(chunk_enc, buf, 0)
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.streamId!(chunk_enc, UInt32(12))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.epoch!(chunk_enc, UInt64(1))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.seq!(chunk_enc, UInt64(1))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkIndex!(chunk_enc, UInt32(0))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkCount!(chunk_enc, UInt32(1))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkOffset!(chunk_enc, UInt32(0))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkLength!(
                    chunk_enc,
                    UInt32(length(payload)),
                )
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.payloadLength!(
                    chunk_enc,
                    UInt32(length(payload)),
                )
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.payloadCrc32c!(chunk_enc, crc)
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.headerIncluded!(
                    chunk_enc,
                    AeronTensorPool.ShmTensorpoolBridge.Bool_.TRUE,
                )
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.headerBytes!(chunk_enc, header_bytes)
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.payloadBytes!(chunk_enc, payload)

                chunk_header = AeronTensorPool.ShmTensorpoolBridge.MessageHeader.Decoder(buf, 0)
                chunk_dec = AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.Decoder(Vector{UInt8})
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.wrap!(
                    chunk_dec,
                    buf,
                    0;
                    header = chunk_header,
                )

                @test Bridge.bridge_chunk_crc32c(header_bytes, payload, true) == crc
                Bridge.bridge_receive_chunk!(receiver, chunk_dec, UInt64(time_ns()))
                dropped_before = receiver.metrics.chunks_dropped
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.payloadCrc32c!(chunk_enc, crc + 1)
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.wrap!(
                    chunk_dec,
                    buf,
                    0;
                    header = chunk_header,
                )
                @test Bridge.bridge_receive_chunk!(receiver, chunk_dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1
            finally
                close_producer_state!(producer_state)
            end
        end
    end
end
