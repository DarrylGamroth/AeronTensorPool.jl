@testset "Consumer announce stream separation" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            epoch = UInt64(1)
            layout_version = UInt32(1)
            stream_id = UInt32(4444)

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
            freshness = UInt64(1_000_000_000)

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
                    epoch,
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
                Int32(12083),
                Int32(12081),
                Int32(12084),
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
                freshness,
                "",
                UInt32(0),
                "",
                UInt32(0),
                false,
            )
            consumer_cfg.announce_channel = "aeron:ipc"
            consumer_cfg.announce_stream_id = Int32(12082)
            state = Consumer.init_consumer(consumer_cfg; client = client)
            desc_asm = Consumer.make_descriptor_assembler(state)
            ctrl_asm = Consumer.make_control_assembler(state)
            pub_announce = Aeron.add_publication(
                AeronTensorPool.aeron_client(client),
                consumer_cfg.announce_channel,
                consumer_cfg.announce_stream_id,
            )
            join_before = state.announce_join_ns_ref[]
            wait_for(() -> state.announce_join_ns_ref[] != join_before; timeout = TEST_TIMEOUT_SEC, sleep_s = 0.01)
            announce_ts = max(UInt64(time_ns()), state.announce_join_ns_ref[] + 1)
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
            sent = false
            ok = wait_for(
                () -> begin
                    if !sent
                        sent = Aeron.offer(pub_announce, view(announce.buf, 1:announce.len)) > 0
                    end
                    Consumer.consumer_do_work!(state, desc_asm, ctrl_asm)
                    return state.mappings.header_mmap !== nothing
                end;
                timeout = TEST_TIMEOUT_SEC,
                sleep_s = 0.01,
            )
            @test ok
            close(pub_announce)
            close_consumer_state!(state)
        end
    end
end
