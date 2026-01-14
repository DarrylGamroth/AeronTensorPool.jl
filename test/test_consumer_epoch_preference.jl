@testset "Consumer announce epoch preference" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            epoch1 = UInt64(1)
            epoch2 = UInt64(2)
            layout_version = UInt32(1)
            stream_id = UInt32(4242)

            _, header_path1, pool_path1 = prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = stream_id,
                epoch = Int(epoch1),
                pool_id = 1,
            )
            header_uri1 = "shm:file?path=$(header_path1)"
            pool_uri1 = "shm:file?path=$(pool_path1)"

            _, header_path2, pool_path2 = prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = stream_id,
                epoch = Int(epoch2),
                pool_id = 1,
            )
            header_uri2 = "shm:file?path=$(header_path2)"
            pool_uri2 = "shm:file?path=$(pool_path2)"

            header_mmap = mmap_shm(header_uri2, SUPERBLOCK_SIZE + Int(nslots) * HEADER_SLOT_BYTES; write = true)
            pool_mmap = mmap_shm(pool_uri2, SUPERBLOCK_SIZE + Int(nslots) * Int(stride); write = true)

            now_ns = UInt64(time_ns())
            sb_enc = ShmRegionSuperblock.Encoder(Vector{UInt8})
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
                    UInt64(getpid()),
                    now_ns,
                    now_ns,
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
                    UInt64(getpid()),
                    now_ns,
                    now_ns,
                ),
            )

            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12072),
                Int32(12071),
                Int32(12073),
                stream_id,
                UInt32(77),
                layout_version,
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                dir,
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
                announce2 = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = epoch2,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri2,
                    pool_uri = pool_uri2,
                    announce_ts = now_ns,
                )
                @test Consumer.handle_shm_pool_announce!(state, announce2.dec)
                @test state.mappings.mapped_epoch == epoch2
                @test state.mappings.highest_epoch == epoch2

                announce1 = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = epoch1,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri1,
                    pool_uri = pool_uri1,
                    announce_ts = now_ns,
                )
                @test !Consumer.handle_shm_pool_announce!(state, announce1.dec)
                @test state.mappings.mapped_epoch == epoch2
                @test state.mappings.highest_epoch == epoch2
            finally
                close_consumer_state!(state)
            end
        end
    end
end
