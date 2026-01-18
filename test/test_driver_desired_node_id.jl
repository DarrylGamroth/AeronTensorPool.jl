using Test

@testset "Driver desired node_id requests" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            16100,
            "aeron:ipc",
            16101,
            "aeron:ipc",
            16102,
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
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(16101), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client.aeron_client)

        pub = Aeron.add_publication(client.aeron_client, "aeron:ipc", 16100)
        sub = Aeron.add_subscription(client.aeron_client, "aeron:ipc", 16100)
        attach_proxy = AttachRequestProxy(pub)
        poller = DriverResponsePoller(sub)

        desired = UInt32(42)
        ok_id = Int64(1)
        sent = send_attach!(
            attach_proxy;
            correlation_id = ok_id,
            stream_id = UInt32(16101),
            client_id = UInt32(7),
            role = DriverRole.PRODUCER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            desired_node_id = desired,
        )
        @test sent == true
        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == ok_id
        end
        @test ok == true
        attach = poller.last_attach
        @test attach !== nothing
        @test attach.code == DriverResponseCode.OK
        @test attach.node_id == desired

        dup_id = Int64(2)
        sent = send_attach!(
            attach_proxy;
            correlation_id = dup_id,
            stream_id = UInt32(16101),
            client_id = UInt32(8),
            role = DriverRole.CONSUMER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            desired_node_id = desired,
        )
        @test sent == true
        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == dup_id
        end
        @test ok == true
        attach = poller.last_attach
        @test attach !== nothing
        @test attach.code == DriverResponseCode.REJECTED

        close_driver_state!(driver_state)
        close(pub)
        close(sub)
    end
end
