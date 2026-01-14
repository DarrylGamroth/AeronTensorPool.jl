@testset "Discovery multi-host entries" begin
    with_driver_and_client() do driver, client
        config = DiscoveryConfig(
            "aeron:ipc",
            Int32(18000),
            "aeron:ipc",
            Int32(18001),
            "",
            UInt32(0),
            "registry",
            "aeron:ipc",
            UInt32(18002),
            AeronTensorPool.DISCOVERY_MAX_RESULTS_DEFAULT,
            UInt64(5_000_000_000),
            AeronTensorPool.DISCOVERY_RESPONSE_BUF_BYTES,
            AeronTensorPool.DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
            AeronTensorPool.DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
        )
        state = AeronTensorPool.Agents.Discovery.init_discovery_provider(config; client = client)
        try
            stream_id = UInt32(100)
            epoch = UInt64(1)
            layout_version = UInt32(1)
            nslots = UInt32(8)

            announce_a = build_shm_pool_announce(
                stream_id = stream_id,
                producer_id = UInt32(1),
                epoch = epoch,
                layout_version = layout_version,
                nslots = nslots,
                header_uri = "shm:file?path=/dev/shm/none",
                payload_entries = NamedTuple[],
            )

            AeronTensorPool.Agents.Discovery.update_entry_from_announce!(
                state,
                announce_a.dec,
                "driver-a",
                "aeron:ipc",
                UInt32(18010),
            )
            announce_b = build_shm_pool_announce(
                stream_id = stream_id,
                producer_id = UInt32(1),
                epoch = epoch,
                layout_version = layout_version,
                nslots = nslots,
                header_uri = "shm:file?path=/dev/shm/none",
                payload_entries = NamedTuple[],
            )
            AeronTensorPool.Agents.Discovery.update_entry_from_announce!(
                state,
                announce_b.dec,
                "driver-b",
                "aeron:ipc",
                UInt32(18011),
            )
            @test length(state.entries) == 2
            @test haskey(state.entries, ("driver-a", stream_id))
            @test haskey(state.entries, ("driver-b", stream_id))
        finally
            AeronTensorPool.Agents.Discovery.close_discovery_state!(state)
        end
    end
end
