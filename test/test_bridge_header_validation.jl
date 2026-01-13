using Test

@testset "Bridge header validation drops invalid TensorHeader" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            base = joinpath(dir, "dst")
            mkpath(base)
            prepare_canonical_shm_layout(
                base;
                namespace = "tensorpool",
                stream_id = 9,
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(base, "tensorpool", 9, 1)
            pool_uri = canonical_pool_uri(base, "tensorpool", 9, 1, 1)

            pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))
            producer_cfg = ProducerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(17010),
                Int32(17011),
                Int32(17012),
                Int32(17013),
                UInt32(9),
                UInt32(90),
                UInt32(1),
                UInt32(8),
                base,
                "tensorpool",
                "bridge-hdr",
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
            try
                mapping = BridgeMapping(UInt32(9), UInt32(9), "default", UInt32(0), Int32(0), Int32(0))
                bridge_cfg = BridgeConfig(
                    "bridge-hdr",
                    Aeron.MediaDriver.aeron_dir(driver),
                    "aeron:ipc",
                    Int32(17100),
                    "aeron:ipc",
                    Int32(17101),
                    "",
                    Int32(0),
                    Int32(0),
                    UInt32(1408),
                    UInt32(512),
                    UInt32(1024),
                    UInt32(2048),
                    UInt64(1_000_000_000),
                    false,
                    false,
                    false,
                )
                receiver = Bridge.init_bridge_receiver(bridge_cfg, mapping; producer_state = producer_state, client = client)

                announce_buf = Vector{UInt8}(undef, 1024)
                announce_enc = AeronTensorPool.Control.ShmPoolAnnounce.Encoder(Vector{UInt8})
                AeronTensorPool.Control.ShmPoolAnnounce.wrap_and_apply_header!(announce_enc, announce_buf, 0)
                AeronTensorPool.Control.ShmPoolAnnounce.streamId!(announce_enc, UInt32(9))
                AeronTensorPool.Control.ShmPoolAnnounce.producerId!(announce_enc, UInt32(10))
                AeronTensorPool.Control.ShmPoolAnnounce.epoch!(announce_enc, UInt64(1))
                AeronTensorPool.Control.ShmPoolAnnounce.announceTimestampNs!(announce_enc, UInt64(time_ns()))
                AeronTensorPool.Control.ShmPoolAnnounce.announceClockDomain!(
                    announce_enc,
                    AeronTensorPool.Control.ClockDomain.MONOTONIC,
                )
                AeronTensorPool.Control.ShmPoolAnnounce.layoutVersion!(announce_enc, UInt32(1))
                AeronTensorPool.Control.ShmPoolAnnounce.headerNslots!(announce_enc, UInt32(8))
                AeronTensorPool.Control.ShmPoolAnnounce.headerSlotBytes!(
                    announce_enc,
                    UInt16(AeronTensorPool.HEADER_SLOT_BYTES),
                )
                pools = AeronTensorPool.Control.ShmPoolAnnounce.payloadPools!(announce_enc, 1)
                pool_entry = AeronTensorPool.Control.ShmPoolAnnounce.PayloadPools.next!(pools)
                AeronTensorPool.Control.ShmPoolAnnounce.PayloadPools.poolId!(pool_entry, UInt16(1))
                AeronTensorPool.Control.ShmPoolAnnounce.PayloadPools.regionUri!(pool_entry, pool_uri)
                AeronTensorPool.Control.ShmPoolAnnounce.PayloadPools.poolNslots!(pool_entry, UInt32(8))
                AeronTensorPool.Control.ShmPoolAnnounce.PayloadPools.strideBytes!(pool_entry, UInt32(4096))
                AeronTensorPool.Control.ShmPoolAnnounce.headerRegionUri!(announce_enc, header_uri)
                announce_header = AeronTensorPool.Control.MessageHeader.Decoder(announce_buf, 0)
                announce_dec = AeronTensorPool.Control.ShmPoolAnnounce.Decoder(Vector{UInt8})
                AeronTensorPool.Control.ShmPoolAnnounce.wrap!(announce_dec, announce_buf, 0; header = announce_header)
                @test Bridge.bridge_apply_source_announce!(receiver, announce_dec)

                header_bytes = Vector{UInt8}(undef, AeronTensorPool.HEADER_SLOT_BYTES)
                slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
                tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
                wrap_slot_header!(slot_enc, header_bytes, 0)
                write_slot_header!(
                    slot_enc,
                    tensor_enc,
                    UInt64(1),
                    UInt32(0),
                    UInt32(16),
                    UInt32(0),
                    UInt32(0),
                    UInt16(1),
                    Dtype.UINT8,
                    MajorOrder.ROW,
                    UInt8(1),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    vcat(Int32(16), zeros(Int32, AeronTensorPool.MAX_DIMS - 1)),
                    vcat(Int32(0), zeros(Int32, AeronTensorPool.MAX_DIMS - 1)),
                )
                SlotHeaderMsg.seqCommit!(slot_enc, UInt64(1) << 1)
                header_pos = SlotHeaderMsg.sbe_position(slot_enc) - AeronTensorPool.TENSOR_HEADER_LEN
                header_view = view(
                    header_bytes,
                    header_pos + 1:header_pos + Int(
                        AeronTensorPool.ShmTensorpoolBridge.MessageHeader.sbe_encoded_length(
                            AeronTensorPool.ShmTensorpoolBridge.MessageHeader.Encoder,
                        ),
                    ),
                )
                header_msg = AeronTensorPool.ShmTensorpoolBridge.MessageHeader.Encoder(header_view)
                AeronTensorPool.ShmTensorpoolBridge.MessageHeader.schemaId!(header_msg, UInt16(999))

                payload = Vector{UInt8}(undef, 16)
                fill!(payload, 0x7f)
                buf = Vector{UInt8}(
                    undef,
                    AeronTensorPool.Bridge.bridge_chunk_message_length(
                        AeronTensorPool.HEADER_SLOT_BYTES,
                        16,
                    ),
                )
                chunk_enc = AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.Encoder(Vector{UInt8})
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.wrap_and_apply_header!(chunk_enc, buf, 0)
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.streamId!(chunk_enc, UInt32(9))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.epoch!(chunk_enc, UInt64(1))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.seq!(chunk_enc, UInt64(1))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkIndex!(chunk_enc, UInt32(0))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkCount!(chunk_enc, UInt32(1))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkOffset!(chunk_enc, UInt32(0))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkLength!(chunk_enc, UInt32(16))
                AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.payloadLength!(chunk_enc, UInt32(16))
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

                dropped_before = receiver.metrics.chunks_dropped
                @test Bridge.bridge_receive_chunk!(receiver, chunk_dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1
            finally
                close_producer_state!(producer_state)
            end
        end
    end
end
