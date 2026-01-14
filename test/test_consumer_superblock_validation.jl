@testset "Consumer superblock validation" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            epoch = UInt64(1)
            layout_version = UInt32(1)
            stream_id = UInt32(99)

            _, header_path, pool_path = prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = stream_id,
                epoch = Int(epoch),
                pool_id = 1,
            )
            header_uri = "shm:file?path=$(header_path)"
            pool_uri = "shm:file?path=$(pool_path)"

            header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + Int(nslots) * HEADER_SLOT_BYTES; write = true)
            pool_mmap = mmap_shm(pool_uri, SUPERBLOCK_SIZE + Int(nslots) * Int(stride); write = true)
            now_ns = UInt64(time_ns())

            sb_enc = ShmRegionSuperblock.Encoder(Vector{UInt8})

            function write_header_superblock(; magic = MAGIC_TPOLSHM1, pool_id = UInt16(0))
                wrap_superblock!(sb_enc, header_mmap, 0)
                write_superblock!(
                    sb_enc,
                    SuperblockFields(
                        magic,
                        layout_version,
                        epoch,
                        stream_id,
                        RegionType.HEADER_RING,
                        pool_id,
                        nslots,
                        UInt32(HEADER_SLOT_BYTES),
                        UInt32(0),
                        UInt64(1234),
                        now_ns,
                        now_ns,
                    ),
                )
            end

            function write_pool_superblock(; pool_id = UInt16(1))
                wrap_superblock!(sb_enc, pool_mmap, 0)
                write_superblock!(
                    sb_enc,
                    SuperblockFields(
                        MAGIC_TPOLSHM1,
                        layout_version,
                        epoch,
                        stream_id,
                        RegionType.PAYLOAD_POOL,
                        pool_id,
                        nslots,
                        stride,
                        stride,
                        UInt64(1234),
                        now_ns,
                        now_ns,
                    ),
                )
            end

            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12132),
                Int32(12131),
                Int32(12133),
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
                function build_announce()
                    return build_shm_pool_announce(
                        stream_id = stream_id,
                        epoch = epoch,
                        layout_version = layout_version,
                        nslots = nslots,
                        stride_bytes = stride,
                        header_uri = header_uri,
                        pool_uri = pool_uri,
                    )
                end

                write_header_superblock(magic = UInt64(0))
                write_pool_superblock()
                @test !Consumer.map_from_announce!(state, build_announce().dec, UInt64(time_ns()))

                write_header_superblock(pool_id = UInt16(1))
                write_pool_superblock()
                @test !Consumer.map_from_announce!(state, build_announce().dec, UInt64(time_ns()))

                write_header_superblock()
                write_pool_superblock(pool_id = UInt16(2))
                @test !Consumer.map_from_announce!(state, build_announce().dec, UInt64(time_ns()))
            finally
                close_consumer_state!(state)
            end
        end
    end
end
