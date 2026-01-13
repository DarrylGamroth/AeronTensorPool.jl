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

            buf = Vector{UInt8}(undef, 512)
            enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(enc, buf, 0)
            AeronTensorPool.ShmPoolAnnounce.streamId!(enc, stream_id)
            AeronTensorPool.ShmPoolAnnounce.producerId!(enc, UInt32(1))
            AeronTensorPool.ShmPoolAnnounce.epoch!(enc, epoch)
            AeronTensorPool.ShmPoolAnnounce.announceTimestampNs!(enc, UInt64(time_ns()))
            AeronTensorPool.ShmPoolAnnounce.announceClockDomain!(enc, AeronTensorPool.ClockDomain.MONOTONIC)
            AeronTensorPool.ShmPoolAnnounce.layoutVersion!(enc, layout_version)
            AeronTensorPool.ShmPoolAnnounce.headerNslots!(enc, nslots)
            AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(enc, UInt16(HEADER_SLOT_BYTES))
            pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(enc, 0)
            AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(enc, "shm:file?path=/dev/shm/none")
            header = MessageHeader.Decoder(buf, 0)
            dec = AeronTensorPool.ShmPoolAnnounce.Decoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap!(dec, buf, 0; header = header)

            AeronTensorPool.ShmPoolAnnounce.wrap!(dec, buf, 0; header = header)
            AeronTensorPool.Agents.Discovery.update_entry_from_announce!(
                state,
                dec,
                "driver-a",
                "aeron:ipc",
                UInt32(18010),
            )
            AeronTensorPool.ShmPoolAnnounce.wrap!(dec, buf, 0; header = header)
            AeronTensorPool.Agents.Discovery.update_entry_from_announce!(
                state,
                dec,
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
