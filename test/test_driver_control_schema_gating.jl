using Test
using UnsafeArrays

@testset "Driver control schema gating (attach)" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, false, false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(1001), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client.aeron_client)
        pub = Aeron.add_publication(client.aeron_client, "aeron:ipc", 1000)
        sub = Aeron.add_subscription(client.aeron_client, "aeron:ipc", 1000)
        poller = AeronTensorPool.Control.DriverResponsePoller(sub)

        claim = Aeron.BufferClaim()
        msg_len = AeronTensorPool.DRIVER_MESSAGE_HEADER_LEN +
            Int(ShmAttachRequest.sbe_block_length(ShmAttachRequest.Decoder))
        schema_version =
            UInt16(ShmAttachRequest.sbe_schema_version(ShmAttachRequest.Decoder) + 1)
        correlation_id = Int64(77)
        sent = with_claimed_buffer!(pub, claim, msg_len) do buf
            enc = ShmAttachRequest.Encoder(UnsafeArray{UInt8, 1})
            ShmAttachRequest.wrap_and_apply_header!(enc, buf, 0)
            header = DriverMessageHeader.Encoder(buf, 0)
            DriverMessageHeader.version!(header, schema_version)
            ShmAttachRequest.correlationId!(enc, correlation_id)
            ShmAttachRequest.streamId!(enc, UInt32(1001))
            ShmAttachRequest.clientId!(enc, UInt32(7))
            ShmAttachRequest.role!(enc, DriverRole.PRODUCER)
            ShmAttachRequest.expectedLayoutVersion!(enc, UInt32(0))
            ShmAttachRequest.publishMode!(enc, DriverPublishMode.REQUIRE_EXISTING)
            ShmAttachRequest.requireHugepages!(enc, DriverHugepagesPolicy.UNSPECIFIED)
            ShmAttachRequest.desiredNodeId!(
                enc,
                ShmAttachRequest.desiredNodeId_null_value(ShmAttachRequest.Decoder),
            )
        end
        @test sent == true

        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok == true
        @test poller.last_attach !== nothing
        @test poller.last_attach.code == DriverResponseCode.UNSUPPORTED

        close_driver_state!(driver_state)
    end
end
