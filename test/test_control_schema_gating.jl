using Test

@testset "Driver control schema gating" begin
    with_driver_and_client() do driver, client
        sub = Aeron.add_subscription(client, "aeron:ipc", Int32(15501))
        poller = AeronTensorPool.Control.DriverResponsePoller(sub)

        buf = Vector{UInt8}(
            undef,
            AeronTensorPool.Control.DriverMessageHeader.sbe_encoded_length(
                AeronTensorPool.Control.DriverMessageHeader.Encoder,
            ),
        )
        header = AeronTensorPool.Control.DriverMessageHeader.Encoder(buf)
        AeronTensorPool.Control.DriverMessageHeader.blockLength!(header, UInt16(0))
        AeronTensorPool.Control.DriverMessageHeader.templateId!(header, UInt16(0))
        AeronTensorPool.Control.DriverMessageHeader.schemaId!(header, UInt16(999))
        AeronTensorPool.Control.DriverMessageHeader.version!(header, UInt16(1))

        @test AeronTensorPool.Control.handle_driver_response!(poller, buf) == false
        @test poller.last_attach === nothing
        @test isempty(poller.attach_by_correlation)

        AeronTensorPool.Control.DriverMessageHeader.schemaId!(
            header,
            AeronTensorPool.Control.DriverMessageHeader.sbe_schema_id(AeronTensorPool.Control.DriverMessageHeader.Encoder),
        )
        AeronTensorPool.Control.DriverMessageHeader.version!(
            header,
            UInt16(
                AeronTensorPool.Control.DriverMessageHeader.sbe_schema_version(
                    AeronTensorPool.Control.DriverMessageHeader.Encoder,
                ) + 1,
            ),
        )
        @test AeronTensorPool.Control.handle_driver_response!(poller, buf) == false
        @test poller.last_attach === nothing
        @test isempty(poller.attach_by_correlation)
    end
end
