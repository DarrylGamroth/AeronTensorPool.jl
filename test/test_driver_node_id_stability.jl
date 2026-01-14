using Test

@testset "Driver node_id stability" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            16000,
            "aeron:ipc",
            16001,
            "aeron:ipc",
            16002,
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
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(16001), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client)

        pub = Aeron.add_publication(client, "aeron:ipc", 16000)
        sub = Aeron.add_subscription(client, "aeron:ipc", 16000)

        attach_proxy = AttachRequestProxy(pub)
        detach_proxy = DetachRequestProxy(pub)
        poller = DriverResponsePoller(sub)

        correlation_id = Int64(1)
        sent = send_attach!(
            attach_proxy;
            correlation_id = correlation_id,
            stream_id = UInt32(16001),
            client_id = UInt32(7),
            role = DriverRole.PRODUCER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        @test sent == true

        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok == true
        attach = poller.last_attach
        @test attach !== nothing
        @test attach.code == DriverResponseCode.OK
        first_node_id = attach.node_id
        @test first_node_id != ShmAttachResponse.nodeId_null_value(ShmAttachResponse.Decoder)
        lease_id = attach.lease_id

        detach_id = Int64(2)
        sent = send_detach!(
            detach_proxy;
            correlation_id = detach_id,
            lease_id = lease_id,
            stream_id = UInt32(16001),
            client_id = UInt32(7),
            role = DriverRole.PRODUCER,
        )
        @test sent == true
        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            detach = poller.last_detach
            detach !== nothing && detach.correlation_id == detach_id
        end
        @test ok == true
        detach = poller.last_detach
        @test detach !== nothing
        @test detach.code == DriverResponseCode.OK

        reattach_id = Int64(3)
        sent = send_attach!(
            attach_proxy;
            correlation_id = reattach_id,
            stream_id = UInt32(16001),
            client_id = UInt32(7),
            role = DriverRole.PRODUCER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        @test sent == true

        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == reattach_id
        end
        @test ok == true
        attach = poller.last_attach
        @test attach !== nothing
        @test attach.code == DriverResponseCode.OK
        @test attach.node_id == first_node_id

        close_driver_state!(driver_state)
        close(pub)
        close(sub)
    end
end
