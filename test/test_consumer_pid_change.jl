@testset "Consumer PID change handling" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            epoch = UInt64(1)
            layout_version = UInt32(1)
            stream_id = UInt32(55)

            _, header_path, pool_path = prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                producer_instance_id = "test-producer",
                epoch = Int(epoch),
                pool_id = 1,
            )
            header_uri = "shm:file?path=$(header_path)"
            pool_uri = "shm:file?path=$(pool_path)"

            header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + Int(nslots) * HEADER_SLOT_BYTES; write = true)
            pool_mmap = mmap_shm(pool_uri, SUPERBLOCK_SIZE + Int(nslots) * Int(stride); write = true)

            sb_enc = ShmRegionSuperblock.Encoder(Vector{UInt8})
            wrap_superblock!(sb_enc, header_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    layout_version,
                    epoch,
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
                    epoch,
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

            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12002),
                Int32(12001),
                Int32(12003),
                stream_id,
                UInt32(42),
                layout_version,
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                "",
                String[],
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

            announce_buf = Vector{UInt8}(undef, 512)
            announce_enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(announce_enc, announce_buf, 0)
            AeronTensorPool.ShmPoolAnnounce.streamId!(announce_enc, stream_id)
            AeronTensorPool.ShmPoolAnnounce.producerId!(announce_enc, UInt32(7))
            AeronTensorPool.ShmPoolAnnounce.epoch!(announce_enc, epoch)
            AeronTensorPool.ShmPoolAnnounce.announceTimestampNs!(announce_enc, UInt64(time_ns()))
            AeronTensorPool.ShmPoolAnnounce.layoutVersion!(announce_enc, layout_version)
            AeronTensorPool.ShmPoolAnnounce.headerNslots!(announce_enc, nslots)
            AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(announce_enc, UInt16(HEADER_SLOT_BYTES))
            AeronTensorPool.ShmPoolAnnounce.maxDims!(announce_enc, UInt8(MAX_DIMS))
            pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(announce_enc, 1)
            pool = AeronTensorPool.ShmPoolAnnounce.PayloadPools.next!(pools)
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolId!(pool, UInt16(1))
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.regionUri!(pool, pool_uri)
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolNslots!(pool, nslots)
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.strideBytes!(pool, stride)
            AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(announce_enc, header_uri)

            header = MessageHeader.Decoder(announce_buf, 0)
            announce_dec = AeronTensorPool.ShmPoolAnnounce.Decoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap!(announce_dec, announce_buf, 0; header = header)

            @test Consumer.map_from_announce!(state, announce_dec)
            @test state.mappings.mapped_pid == UInt64(1234)

            wrap_superblock!(sb_enc, header_mmap, 0)
            ShmRegionSuperblock.pid!(sb_enc, UInt64(5678))

            @test Consumer.validate_mapped_superblocks!(state, announce_dec) == :pid_changed
            @test !Consumer.handle_shm_pool_announce!(state, announce_dec)
            @test state.mappings.header_mmap === nothing
            finally
                close_consumer_state!(state)
            end
        end
    end
end
