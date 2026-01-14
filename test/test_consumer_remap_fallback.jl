@testset "Consumer remap and fallback handling" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            layout_version = UInt32(1)
            stream_id = UInt32(77)

            epoch1 = UInt64(1)
            epoch2 = UInt64(2)
            _, header_path1, pool_path1 = prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = stream_id,
                epoch = Int(epoch1),
                pool_id = 1,
            )
            _, header_path2, pool_path2 = prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = stream_id,
                epoch = Int(epoch2),
                pool_id = 1,
            )
            header_uri1 = "shm:file?path=$(header_path1)"
            pool_uri1 = "shm:file?path=$(pool_path1)"
            header_uri2 = "shm:file?path=$(header_path2)"
            pool_uri2 = "shm:file?path=$(pool_path2)"

            header_mmap1 = mmap_shm(header_uri1, SUPERBLOCK_SIZE + Int(nslots) * HEADER_SLOT_BYTES; write = true)
            pool_mmap1 = mmap_shm(pool_uri1, SUPERBLOCK_SIZE + Int(nslots) * Int(stride); write = true)
            header_mmap2 = mmap_shm(header_uri2, SUPERBLOCK_SIZE + Int(nslots) * HEADER_SLOT_BYTES; write = true)
            pool_mmap2 = mmap_shm(pool_uri2, SUPERBLOCK_SIZE + Int(nslots) * Int(stride); write = true)

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
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "aeron:udp?endpoint=127.0.0.1:14000",
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
            fallback_state = nothing
            now_ns = UInt64(time_ns())
            try
                    wrap_superblock!(sb_enc, header_mmap1, 0)
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
                            now_ns,
                            now_ns,
                        ),
                    )
                    wrap_superblock!(sb_enc, pool_mmap1, 0)
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
                            now_ns,
                            now_ns,
                        ),
                    )

                    announce = build_shm_pool_announce(
                        stream_id = stream_id,
                        epoch = epoch1,
                        layout_version = layout_version,
                        nslots = nslots,
                        stride_bytes = stride,
                        header_uri = header_uri1,
                        pool_uri = pool_uri1,
                    )
                    announce_dec1 = announce.dec
                    @test Consumer.handle_shm_pool_announce!(state, announce_dec1)
                    @test state.mappings.mapped_epoch == epoch1

                    wrap_superblock!(sb_enc, header_mmap2, 0)
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
                            now_ns,
                            now_ns,
                        ),
                    )
                    wrap_superblock!(sb_enc, pool_mmap2, 0)
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
                            now_ns,
                            now_ns,
                        ),
                    )

                    announce = build_shm_pool_announce(
                        stream_id = stream_id,
                        epoch = epoch2,
                        layout_version = layout_version,
                        nslots = nslots,
                        stride_bytes = stride,
                        header_uri = header_uri2,
                        pool_uri = pool_uri2,
                    )
                    announce_dec2 = announce.dec
                    @test Consumer.handle_shm_pool_announce!(state, announce_dec2)
                    @test state.mappings.mapped_epoch == epoch2

                    bad_pool_uri = "shm:file?path=$(pool_path2)|require_hugepages=true"

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
                        UInt32(256),
                        true,
                        true,
                        false,
                UInt16(0),
                "aeron:udp?endpoint=127.0.0.1:14000",
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
                    fallback_state = Consumer.init_consumer(fallback_cfg; client = client)
                    announce = build_shm_pool_announce(
                        stream_id = stream_id,
                        epoch = epoch2,
                        layout_version = layout_version,
                        nslots = nslots,
                        stride_bytes = stride,
                        header_uri = header_uri2,
                        pool_uri = bad_pool_uri,
                    )
                    announce_dec_bad = announce.dec
                    @test Consumer.handle_shm_pool_announce!(fallback_state, announce_dec_bad)
                    @test fallback_state.config.use_shm == false
                    @test fallback_state.mappings.header_mmap === nothing

            finally
                if fallback_state !== nothing
                    close_consumer_state!(fallback_state)
                end
                close_consumer_state!(state)
            end
        end
    end
end
