using Test

@testset "Driver restart bumps epoch" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()
        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            14000,
            "aeron:ipc",
            14001,
            "aeron:ipc",
            14002,
        )
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
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

        pub = Aeron.add_publication(client, "aeron:ipc", 14000)
        sub = Aeron.add_subscription(client, "aeron:ipc", 14000)
        attach_proxy = AttachRequestProxy(pub)
        poller = DriverResponsePoller(sub)

        driver_state = init_driver(cfg; client = client)
        correlation_id = Int64(1)
        send_attach!(
            attach_proxy;
            correlation_id = correlation_id,
            stream_id = UInt32(1001),
            client_id = UInt32(17),
            role = DriverRole.PRODUCER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok == true
        first_epoch = poller.last_attach.epoch

        close_driver_state!(driver_state)

        driver_state = init_driver(cfg; client = client)
        correlation_id = Int64(2)
        send_attach!(
            attach_proxy;
            correlation_id = correlation_id,
            stream_id = UInt32(1001),
            client_id = UInt32(18),
            role = DriverRole.PRODUCER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok == true
        second_epoch = poller.last_attach.epoch
        @test second_epoch > first_epoch

        close_driver_state!(driver_state)
        close(pub)
        close(sub)
    end
end
