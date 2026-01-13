@testset "Metadata API" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do base_dir
            namespace = "default"
            epoch = 1
            stream_id = UInt32(1)
            _, header_path, pool_path = prepare_canonical_shm_layout(
                base_dir;
                namespace = namespace,
                stream_id = stream_id,
                epoch = epoch,
                pool_id = 1,
            )

            cfg = ProducerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(1011),
                Int32(1012),
                Int32(1013),
                Int32(1014),
                stream_id,
                UInt32(2),
                UInt32(1),
                UInt32(8),
                base_dir,
                namespace,
                "test-producer",
                "shm:file?path=$(header_path)",
                [PayloadPoolConfig(UInt16(1), "shm:file?path=$(pool_path)", UInt32(64), UInt32(8))],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )

            state = Producer.init_producer(cfg; client = client)
            try
                @test metadata_version(state) == UInt32(0)

                announce_data_source!(state, "camera-1"; summary = "first")
                @test metadata_version(state) == UInt32(1)
                @test state.metadata_name == "camera-1"
                @test state.metadata_summary == "first"
                @test state.metadata_dirty

                attrs = MetadataAttribute[
                    MetadataAttribute("pattern" => ("text/plain", "counter")),
                ]
                set_metadata_attributes!(state; attributes = attrs)
                @test metadata_version(state) == UInt32(2)
                @test length(state.metadata_attrs) == 1
                @test state.metadata_attrs[1].key == "pattern"

                set_metadata_attribute!(state, "pattern", "text/plain", "counter-2")
                @test metadata_version(state) == UInt32(3)
                @test state.metadata_attrs[1].key == "pattern"
                @test String(state.metadata_attrs[1].value) == "counter-2"

                set_metadata_attribute!(state, "pattern" => ("text/plain", "counter-3"))
                @test metadata_version(state) == UInt32(4)
                @test String(state.metadata_attrs[1].value) == "counter-3"

                delete_metadata_attribute!(state, "pattern")
                @test metadata_version(state) == UInt32(5)
                @test isempty(state.metadata_attrs)

                set_metadata_attributes!(state; attributes = attrs)
                announce_data_source!(state, "camera-2"; summary = "second")
                @test metadata_version(state) == UInt32(7)
                @test state.metadata_name == "camera-2"
                @test length(state.metadata_attrs) == 1
            finally
                close_producer_state!(state)
            end
        end
    end
end
