using Test

@testset "Bridge chunk basic validation" begin
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
                Int32(17020),
                Int32(17021),
                Int32(17022),
                Int32(17023),
                UInt32(9),
                UInt32(90),
                UInt32(1),
                UInt32(8),
                base,
                "tensorpool",
                "bridge-chunk",
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
                    "bridge-chunk",
                    Aeron.MediaDriver.aeron_dir(driver),
                    "aeron:ipc",
                    Int32(17110),
                    "aeron:ipc",
                    Int32(17111),
                    "",
                    Int32(0),
                    Int32(0),
                    UInt32(1408),
                    UInt32(512),
                    UInt32(1024),
                    UInt32(2048),
                    false,
                    UInt64(1_000_000_000),
                    false,
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

                payload = fill(UInt8(0x7f), 16)

                function encode_chunk!(;
                    chunk_index::UInt32,
                    chunk_count::UInt32,
                    chunk_offset::UInt32,
                    chunk_length::UInt32,
                    payload_length::UInt32,
                    header_included::Bool,
                    header_bytes_in::Vector{UInt8},
                    payload_bytes_in::Vector{UInt8},
                )
                    buf = Vector{UInt8}(
                        undef,
                        AeronTensorPool.Bridge.bridge_chunk_message_length(
                            length(header_bytes_in),
                            length(payload_bytes_in),
                        ),
                    )
                    enc = AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.Encoder(Vector{UInt8})
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.wrap_and_apply_header!(enc, buf, 0)
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.streamId!(enc, UInt32(9))
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.epoch!(enc, UInt64(1))
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.seq!(enc, UInt64(1))
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkIndex!(enc, chunk_index)
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkCount!(enc, chunk_count)
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkOffset!(enc, chunk_offset)
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.chunkLength!(enc, chunk_length)
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.payloadLength!(enc, payload_length)
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.headerIncluded!(
                        enc,
                        header_included ? AeronTensorPool.ShmTensorpoolBridge.Bool_.TRUE :
                        AeronTensorPool.ShmTensorpoolBridge.Bool_.FALSE,
                    )
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.headerBytes!(enc, header_bytes_in)
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.payloadBytes!(enc, payload_bytes_in)

                    header = AeronTensorPool.ShmTensorpoolBridge.MessageHeader.Decoder(buf, 0)
                    dec = AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.Decoder(Vector{UInt8})
                    AeronTensorPool.ShmTensorpoolBridge.BridgeFrameChunk.wrap!(dec, buf, 0; header = header)
                    return dec
                end

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(0),
                    chunk_count = UInt32(0),
                    chunk_offset = UInt32(0),
                    chunk_length = UInt32(16),
                    payload_length = UInt32(16),
                    header_included = true,
                    header_bytes_in = header_bytes,
                    payload_bytes_in = payload,
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(1),
                    chunk_count = UInt32(1),
                    chunk_offset = UInt32(0),
                    chunk_length = UInt32(16),
                    payload_length = UInt32(16),
                    header_included = true,
                    header_bytes_in = header_bytes,
                    payload_bytes_in = payload,
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(1),
                    chunk_count = UInt32(2),
                    chunk_offset = UInt32(0),
                    chunk_length = UInt32(8),
                    payload_length = UInt32(16),
                    header_included = true,
                    header_bytes_in = header_bytes,
                    payload_bytes_in = payload[1:8],
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(0),
                    chunk_count = UInt32(1),
                    chunk_offset = UInt32(0),
                    chunk_length = UInt32(5),
                    payload_length = UInt32(5),
                    header_included = false,
                    header_bytes_in = UInt8[],
                    payload_bytes_in = payload[1:4],
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(1),
                    chunk_count = UInt32(2),
                    chunk_offset = UInt32(0),
                    chunk_length = UInt32(8),
                    payload_length = UInt32(16),
                    header_included = true,
                    header_bytes_in = header_bytes,
                    payload_bytes_in = payload[1:8],
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(0),
                    chunk_count = UInt32(65536),
                    chunk_offset = UInt32(0),
                    chunk_length = UInt32(16),
                    payload_length = UInt32(16),
                    header_included = true,
                    header_bytes_in = header_bytes,
                    payload_bytes_in = payload,
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(0),
                    chunk_count = UInt32(1),
                    chunk_offset = UInt32(1),
                    chunk_length = UInt32(15),
                    payload_length = UInt32(16),
                    header_included = true,
                    header_bytes_in = header_bytes,
                    payload_bytes_in = payload[1:15],
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1

                dropped_before = receiver.metrics.chunks_dropped
                dec = encode_chunk!(
                    chunk_index = UInt32(0),
                    chunk_count = UInt32(1),
                    chunk_offset = UInt32(0),
                    chunk_length = UInt32(16),
                    payload_length = UInt32(16),
                    header_included = true,
                    header_bytes_in = UInt8[],
                    payload_bytes_in = payload,
                )
                @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                @test receiver.metrics.chunks_dropped == dropped_before + 1
            finally
                close_producer_state!(producer_state)
            end
        end
    end
end
