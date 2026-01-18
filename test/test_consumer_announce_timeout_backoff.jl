@testset "Consumer waits for epoch bump after producer revoke" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            epoch = UInt64(1)
            layout_version = UInt32(1)
            stream_id = UInt32(4242)

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

            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12112),
                Int32(12111),
                Int32(12113),
                stream_id,
                UInt32(55),
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
                UInt64(1_000_000_000),
                "",
                UInt32(0),
                "",
                UInt32(0),
                false,
            )
            state = Consumer.init_consumer(consumer_cfg; client = client)
            driver_client = init_driver_client(client.aeron_client,
                "aeron:ipc",
                Int32(14050),
                UInt32(99),
                DriverRole.CONSUMER,
            )
            try
                state.driver_client = driver_client
                state.driver_active = true
                driver_client.lease_id = UInt64(10)

                fetch!(state.clock)
                announce_ts = UInt64(Clocks.time_nanos(state.clock))
                announce = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = epoch,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                    announce_ts = announce_ts,
                )
                @test Consumer.map_from_announce!(state, announce.dec, now_ns)
                @test state.phase == AeronTensorPool.MAPPED

                revoke = LeaseRevoked()
                revoke.lease_id = UInt64(77)
                revoke.stream_id = stream_id
                revoke.role = DriverRole.PRODUCER
                revoke.reason = DriverLeaseRevokeReason.EXPIRED
                driver_client.poller.last_revoke = revoke

                Consumer.handle_driver_events!(state, now_ns)
                @test state.awaiting_announce_epoch == epoch
                @test state.phase == AeronTensorPool.UNMAPPED

                fetch!(state.clock)
                announce_ts = UInt64(Clocks.time_nanos(state.clock))
                announce_same = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = epoch,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                    announce_ts = announce_ts,
                )
                @test !Consumer.handle_shm_pool_announce!(state, announce_same.dec)
                @test state.phase == AeronTensorPool.UNMAPPED

                timeout_ns = state.config.announce_freshness_ns * UInt64(3)
                Consumer.handle_driver_events!(state, now_ns + timeout_ns + 1)
                @test state.announce_wait_active
                @test state.awaiting_announce_epoch == epoch

                fetch!(state.clock)
                announce_ts = UInt64(Clocks.time_nanos(state.clock))
                bump_epoch = epoch + 1
                wrap_superblock!(sb_enc, header_mmap, 0)
                write_superblock!(
                    sb_enc,
                    SuperblockFields(
                        MAGIC_TPOLSHM1,
                        layout_version,
                        bump_epoch,
                        stream_id,
                        RegionType.HEADER_RING,
                        UInt16(0),
                        nslots,
                        UInt32(HEADER_SLOT_BYTES),
                        UInt32(0),
                        UInt64(1234),
                        announce_ts,
                        announce_ts,
                    ),
                )
                wrap_superblock!(sb_enc, pool_mmap, 0)
                write_superblock!(
                    sb_enc,
                    SuperblockFields(
                        MAGIC_TPOLSHM1,
                        layout_version,
                        bump_epoch,
                        stream_id,
                        RegionType.PAYLOAD_POOL,
                        UInt16(1),
                        nslots,
                        stride,
                        stride,
                        UInt64(1234),
                        announce_ts,
                        announce_ts,
                    ),
                )
                announce_bump = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = bump_epoch,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                    announce_ts = announce_ts,
                )
                @test Consumer.handle_shm_pool_announce!(state, announce_bump.dec)
                @test state.phase == AeronTensorPool.MAPPED
                @test state.awaiting_announce_epoch == UInt64(0)
            finally
                close_consumer_state!(state)
                close(driver_client.pub)
                close(driver_client.sub)
            end
        end
    end
end
