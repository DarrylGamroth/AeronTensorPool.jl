@testset "Consumer path containment" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do base_dir
            mktempdir("/dev/shm") do other_dir
                nslots = UInt32(8)
                stride = UInt32(4096)
                stream_id = UInt32(77)
                epoch = UInt64(1)

                consumer_cfg = ConsumerConfig(
                    Aeron.MediaDriver.aeron_dir(driver),
                    "aeron:ipc",
                    Int32(13012),
                    Int32(13011),
                    Int32(13013),
                    stream_id,
                    UInt32(52),
                    UInt32(1),
                    UInt8(MAX_DIMS),
                    Mode.STREAM,
                    UInt32(256),
                    true,
                    true,
                    false,
                    UInt16(0),
                    "",
                    base_dir,
                    [base_dir],
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

                state = Consumer.init_consumer(consumer_cfg; client = client)
                try
                    header_uri = "shm:file?path=$(joinpath(other_dir, "header.ring"))"
                    pool_uri = "shm:file?path=$(joinpath(other_dir, "1.pool"))"

                    buf = Vector{UInt8}(undef, 1024)
                    enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
                    AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(enc, buf, 0)
                    AeronTensorPool.ShmPoolAnnounce.streamId!(enc, stream_id)
                    AeronTensorPool.ShmPoolAnnounce.producerId!(enc, UInt32(7))
                    AeronTensorPool.ShmPoolAnnounce.epoch!(enc, epoch)
                    AeronTensorPool.ShmPoolAnnounce.announceTimestampNs!(enc, UInt64(time_ns()))
                    AeronTensorPool.ShmPoolAnnounce.announceClockDomain!(enc, AeronTensorPool.ClockDomain.MONOTONIC)
                    AeronTensorPool.ShmPoolAnnounce.layoutVersion!(enc, UInt32(1))
                    AeronTensorPool.ShmPoolAnnounce.headerNslots!(enc, nslots)
                    AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(enc, UInt16(HEADER_SLOT_BYTES))
                    pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(enc, 1)
                    pool = AeronTensorPool.ShmPoolAnnounce.PayloadPools.next!(pools)
                    AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolId!(pool, UInt16(1))
                    AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolNslots!(pool, nslots)
                    AeronTensorPool.ShmPoolAnnounce.PayloadPools.strideBytes!(pool, stride)
                    AeronTensorPool.ShmPoolAnnounce.PayloadPools.regionUri!(pool, pool_uri)
                    AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(enc, header_uri)

                    dec = AeronTensorPool.ShmPoolAnnounce.Decoder(Vector{UInt8})
                    header = AeronTensorPool.MessageHeader.Decoder(buf, 0)
                    AeronTensorPool.ShmPoolAnnounce.wrap!(dec, buf, 0; header = header)

                    @test !Consumer.map_from_announce!(state, dec)
                finally
                    close_consumer_state!(state)
                end
            end
        end
    end
end
