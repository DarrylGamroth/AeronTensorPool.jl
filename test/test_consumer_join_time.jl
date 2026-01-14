using Test
using AeronTensorPool

@testset "Consumer join-time gating" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            epoch = UInt64(1)
            layout_version = UInt32(1)
            stream_id = UInt32(12345)

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
                    epoch,
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

            cfg = default_consumer_config(
                aeron_dir = Aeron.MediaDriver.aeron_dir(driver),
                stream_id = stream_id,
                shm_base_dir = dir,
                expected_layout_version = layout_version,
                announce_freshness_ns = UInt64(1_000_000_000),
            )
            state = Consumer.init_consumer(cfg; client = client)
            try
                now_ns = UInt64(Clocks.time_nanos(state.clock))
                state.announce_join_ns_ref[] = now_ns + state.config.announce_freshness_ns + 1

                announce = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = epoch,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                    announce_ts = now_ns - 1,
                    clock_domain = AeronTensorPool.ClockDomain.MONOTONIC,
                )
                @test !Consumer.handle_shm_pool_announce!(state, announce.dec)

                announce = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = epoch,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                    announce_ts = now_ns - 1,
                    clock_domain = AeronTensorPool.ClockDomain.REALTIME_SYNCED,
                )
                @test Consumer.handle_shm_pool_announce!(state, announce.dec)
            finally
                close_consumer_state!(state)
            end
        end
    end
end
