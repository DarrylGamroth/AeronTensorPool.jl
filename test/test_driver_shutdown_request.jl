using Test

@testset "Driver shutdown request" begin
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
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicies(true, "raw", UInt32(100), UInt32(10_000), UInt32(3), UInt32(1), "secret")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            Dict{String, DriverStreamConfig}(),
        )

        driver_state = init_driver(cfg; client = client)
        pub = Aeron.add_publication(client, "aeron:ipc", 1000)
        sub = Aeron.add_subscription(client, "aeron:ipc", 1000)
        poller = DriverResponsePoller(sub)
        shutdown_proxy = AeronTensorPool.ShutdownRequestProxy(pub)

        sent = AeronTensorPool.send_shutdown_request!(
            shutdown_proxy;
            correlation_id = Int64(1),
            reason = DriverShutdownReason.ADMIN,
            token = "bad",
            error_message = "nope",
        )
        @test sent == true
        ok = wait_for(() -> begin
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            poller.last_shutdown !== nothing
        end; timeout = 0.2)
        @test ok == false

        sent = AeronTensorPool.send_shutdown_request!(
            shutdown_proxy;
            correlation_id = Int64(2),
            reason = DriverShutdownReason.ADMIN,
            token = "secret",
            error_message = "maintenance",
        )
        @test sent == true
        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            poller.last_shutdown !== nothing
        end
        @test ok == true
        shutdown = poller.last_shutdown
        @test shutdown !== nothing
        @test shutdown.reason == DriverShutdownReason.ADMIN
        @test String(shutdown.error_message) == "maintenance"

        close_driver_state!(driver_state)
        close(pub)
        close(sub)
    end
end
