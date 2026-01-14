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

                    announce = build_shm_pool_announce(
                        stream_id = stream_id,
                        epoch = epoch,
                        layout_version = UInt32(1),
                        nslots = nslots,
                        stride_bytes = stride,
                        header_uri = header_uri,
                        pool_uri = pool_uri,
                    )

                    @test !Consumer.map_from_announce!(state, announce.dec)
                finally
                    close_consumer_state!(state)
                end
            end
        end
    end
end
