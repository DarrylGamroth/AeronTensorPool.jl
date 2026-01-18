@testset "Metadata helpers" begin
    with_driver_and_client() do _, client
        metadata_stream_id = Int32(1300)
        metadata_channel = "aeron:ipc"
        pub = Aeron.add_publication(client.aeron_client, metadata_channel, metadata_stream_id)
        cache = MetadataCache(metadata_channel, metadata_stream_id; client = client.aeron_client)
        publisher = MetadataPublisher(pub, UInt32(1), UInt32(7), UInt64(1))

        attrs = MetadataAttribute[
            MetadataAttribute("camera_serial", "text/plain", Vector{UInt8}(codeunits("ABC123"))),
        ]

        try
            sent_announce = emit_metadata_announce!(publisher, UInt32(3), "camera-1"; summary = "metadata-test")
            sent_meta = emit_metadata_meta!(publisher, UInt32(3), UInt64(1234), attrs)
            @test sent_announce
            @test sent_meta

            ready = wait_for() do
                poll_metadata!(cache)
                entry = metadata_entry(cache, UInt32(1))
                entry !== nothing && entry.meta_version == UInt32(3)
            end
            @test ready

            entry = metadata_entry(cache, UInt32(1))
            @test entry !== nothing
            @test entry.name == "camera-1"
            @test entry.summary == "metadata-test"
            @test entry.timestamp_ns == UInt64(1234)
            @test length(entry.attributes) == 1
            @test entry.attributes[1].key == "camera_serial"
        finally
            close(cache)
            close(pub)
        end
    end
end
