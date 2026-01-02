using Test

@testset "Driver shutdown notice" begin
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
            policies = DriverPolicies(true, "raw", UInt32(100), UInt32(10_000), UInt32(3), UInt32(2000))
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
            sub = Aeron.add_subscription(client, "aeron:ipc", 1000)
            poller = DriverResponsePoller(sub)

            sent = AeronTensorPool.emit_driver_shutdown!(
                driver_state,
                DriverShutdownReason.ADMIN,
                "maintenance",
            )
            @test sent == true

            ok = wait_for() do
                poll_driver_responses!(poller)
                poller.last_shutdown !== nothing
            end
            @test ok == true
            @test poller.last_shutdown.reason == DriverShutdownReason.ADMIN
            @test poller.last_shutdown.error_message == "maintenance"

        close_driver_state!(driver_state)
        close(sub)
    end
end
