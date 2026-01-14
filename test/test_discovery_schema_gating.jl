using Test

@testset "Discovery response schema gating" begin
    with_driver_and_client() do driver, client
        sub = Aeron.add_subscription(client, "aeron:ipc", Int32(15511))
        poller = AeronTensorPool.DiscoveryClient.DiscoveryResponsePoller(sub)

        out_entries = AeronTensorPool.DiscoveryClient.DiscoveryEntry[]
        slot = AeronTensorPool.DiscoveryClient.DiscoveryResponseSlot(out_entries)
        poller.slots[UInt64(10)] = slot

        buf = Vector{UInt8}(undef, DiscoveryMessageHeader.sbe_encoded_length(DiscoveryMessageHeader.Encoder))
        header = DiscoveryMessageHeader.Encoder(buf)
        DiscoveryMessageHeader.blockLength!(header, UInt16(0))
        DiscoveryMessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_DISCOVERY_RESPONSE)
        DiscoveryMessageHeader.schemaId!(header, UInt16(999))
        DiscoveryMessageHeader.version!(header, UInt16(1))

        AeronTensorPool.DiscoveryClient.handle_discovery_response!(poller, buf)
        @test slot.ready == false
        @test slot.count == 0

        DiscoveryMessageHeader.schemaId!(header, DiscoveryMessageHeader.sbe_schema_id(DiscoveryMessageHeader.Encoder))
        DiscoveryMessageHeader.version!(header, UInt16(DiscoveryResponse.sbe_schema_version(DiscoveryResponse.Decoder) + 1))
        AeronTensorPool.DiscoveryClient.handle_discovery_response!(poller, buf)
        @test slot.ready == false
        @test slot.count == 0
    end
end
