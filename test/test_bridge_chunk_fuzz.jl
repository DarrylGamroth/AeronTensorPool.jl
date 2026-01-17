using Random
using Test

@testset "Bridge chunk fuzz" begin
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

                announce = build_shm_pool_announce(
                    stream_id = UInt32(9),
                    epoch = UInt64(1),
                    layout_version = UInt32(1),
                    nslots = UInt32(8),
                    stride_bytes = UInt32(4096),
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                )
                @test Bridge.bridge_apply_source_announce!(receiver, announce.dec)

                header_bytes = fill(UInt8(0x00), HEADER_SLOT_BYTES)
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

                rng = Random.MersenneTwister(0x6c12_95aa)
                max_payload = bridge_cfg.max_payload_bytes
                for _ in 1:200
                    case = rand(rng, 1:7)
                    chunk_index = UInt32(0)
                    chunk_count = UInt32(1)
                    chunk_offset = UInt32(0)
                    chunk_length = UInt32(16)
                    payload_length = UInt32(16)
                    header_included = true
                    header_in = header_bytes
                    payload_in = payload

                    if case == 1
                        chunk_count = UInt32(0)
                    elseif case == 2
                        chunk_index = UInt32(1)
                        chunk_count = UInt32(1)
                    elseif case == 3
                        chunk_offset = UInt32(17)
                        chunk_length = UInt32(1)
                    elseif case == 4
                        chunk_length = UInt32(17)
                    elseif case == 5
                        payload_length = max_payload + UInt32(1)
                    elseif case == 6
                        header_in = UInt8[]
                    elseif case == 7
                        payload_in = payload[1:15]
                    end

                    dec = encode_chunk!(
                        chunk_index = chunk_index,
                        chunk_count = chunk_count,
                        chunk_offset = chunk_offset,
                        chunk_length = chunk_length,
                        payload_length = payload_length,
                        header_included = header_included,
                        header_bytes_in = header_in,
                        payload_bytes_in = payload_in,
                    )
                    dropped_before = receiver.metrics.chunks_dropped
                    @test Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns())) == false
                    @test receiver.metrics.chunks_dropped == dropped_before + 1
                end
            finally
                close_producer_state!(producer_state)
            end
        end
    end
end
