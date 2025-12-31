@testset "Consumer remap and fallback handling" begin
    with_embedded_driver() do driver
        mktempdir() do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            layout_version = UInt32(1)
            stream_id = UInt32(77)

            header_path = joinpath(dir, "tp_header")
            pool_path = joinpath(dir, "tp_pool")
            header_uri = "shm:file?path=$(header_path)"
            pool_uri = "shm:file?path=$(pool_path)"

            header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + Int(nslots) * HEADER_SLOT_BYTES; write = true)
            pool_mmap = mmap_shm(pool_uri, SUPERBLOCK_SIZE + Int(nslots) * Int(stride); write = true)

            sb_enc = ShmRegionSuperblock.Encoder(Vector{UInt8})

            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12012),
                Int32(12011),
                Int32(12013),
                stream_id,
                UInt32(52),
                layout_version,
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt16(1),
                true,
                true,
                false,
                UInt16(0),
                "aeron:udp?endpoint=127.0.0.1:14000",
                false,
                UInt32(250),
                UInt32(65536),
                UInt32(0),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
            )
            state = init_consumer(consumer_cfg)

            function build_announce(epoch::UInt64, pool_region_uri::String)
                buf = Vector{UInt8}(undef, 2048)
                enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
                AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(enc, buf, 0)
                AeronTensorPool.ShmPoolAnnounce.streamId!(enc, stream_id)
                AeronTensorPool.ShmPoolAnnounce.producerId!(enc, UInt32(7))
                AeronTensorPool.ShmPoolAnnounce.epoch!(enc, epoch)
                AeronTensorPool.ShmPoolAnnounce.layoutVersion!(enc, layout_version)
                AeronTensorPool.ShmPoolAnnounce.headerNslots!(enc, nslots)
                AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(enc, UInt16(HEADER_SLOT_BYTES))
                AeronTensorPool.ShmPoolAnnounce.maxDims!(enc, UInt8(MAX_DIMS))
                AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(enc, header_uri)

                pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(enc, 1)
                pool = AeronTensorPool.ShmPoolAnnounce.PayloadPools.next!(pools)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolId!(pool, UInt16(1))
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.regionUri!(pool, pool_region_uri)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolNslots!(pool, nslots)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.strideBytes!(pool, stride)

                header = MessageHeader.Decoder(buf, 0)
                dec = AeronTensorPool.ShmPoolAnnounce.Decoder(Vector{UInt8})
                AeronTensorPool.ShmPoolAnnounce.wrap!(dec, buf, 0; header = header)
                return buf, dec
            end

            epoch1 = UInt64(1)
            wrap_superblock!(sb_enc, header_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    layout_version,
                    epoch1,
                    stream_id,
                    RegionType.HEADER_RING,
                    UInt16(0),
                    nslots,
                    UInt32(HEADER_SLOT_BYTES),
                    UInt32(0),
                    UInt64(1234),
                    UInt64(0),
                    UInt64(0),
                ),
            )
            wrap_superblock!(sb_enc, pool_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    layout_version,
                    epoch1,
                    stream_id,
                    RegionType.PAYLOAD_POOL,
                    UInt16(1),
                    nslots,
                    stride,
                    stride,
                    UInt64(1234),
                    UInt64(0),
                    UInt64(0),
                ),
            )

            (_, announce_dec1) = build_announce(epoch1, pool_uri)
            @test handle_shm_pool_announce!(state, announce_dec1)
            @test state.mapped_epoch == epoch1

            epoch2 = UInt64(2)
            wrap_superblock!(sb_enc, header_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    layout_version,
                    epoch2,
                    stream_id,
                    RegionType.HEADER_RING,
                    UInt16(0),
                    nslots,
                    UInt32(HEADER_SLOT_BYTES),
                    UInt32(0),
                    UInt64(1234),
                    UInt64(0),
                    UInt64(0),
                ),
            )
            wrap_superblock!(sb_enc, pool_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    layout_version,
                    epoch2,
                    stream_id,
                    RegionType.PAYLOAD_POOL,
                    UInt16(1),
                    nslots,
                    stride,
                    stride,
                    UInt64(1234),
                    UInt64(0),
                    UInt64(0),
                ),
            )

            (_, announce_dec2) = build_announce(epoch2, pool_uri)
            @test handle_shm_pool_announce!(state, announce_dec2)
            @test state.mapped_epoch == epoch2

            bad_pool_uri = "shm:file?path=$(pool_path)|require_hugepages=true"

            fallback_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12022),
                Int32(12021),
                Int32(12023),
                stream_id,
                UInt32(53),
                layout_version,
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt16(1),
                true,
                true,
                false,
                UInt16(0),
                "aeron:udp?endpoint=127.0.0.1:14000",
                false,
                UInt32(250),
                UInt32(65536),
                UInt32(0),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
            )
            fallback_state = init_consumer(fallback_cfg)
            (_, announce_dec_bad) = build_announce(epoch2, bad_pool_uri)
            @test handle_shm_pool_announce!(fallback_state, announce_dec_bad)
            @test fallback_state.config.use_shm == false
            @test fallback_state.header_mmap === nothing

            maxdims_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12032),
                Int32(12031),
                Int32(12033),
                stream_id,
                UInt32(54),
                layout_version,
                UInt8(MAX_DIMS - 1),
                Mode.STREAM,
                UInt16(1),
                true,
                true,
                false,
                UInt16(0),
                "aeron:udp?endpoint=127.0.0.1:14001",
                false,
                UInt32(250),
                UInt32(65536),
                UInt32(0),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
            )
            maxdims_state = init_consumer(maxdims_cfg)
            (_, announce_dec_good) = build_announce(epoch2, pool_uri)
            @test handle_shm_pool_announce!(maxdims_state, announce_dec_good)
            @test maxdims_state.config.use_shm == false
            @test maxdims_state.header_mmap === nothing
        end
    end
end
