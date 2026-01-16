using Test

@testset "Driver expected layout version mismatch" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            16200,
            "aeron:ipc",
            16201,
            "aeron:ipc",
            16202,
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
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(16201), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client)
        AeronTensorPool.Timers.disable!(driver_state.timer_set.timers[1])

        pub = Aeron.add_publication(client, "aeron:ipc", 16200)
        sub = Aeron.add_subscription(client, "aeron:ipc", 16200)
        attach_proxy = AttachRequestProxy(pub)
        poller = DriverResponsePoller(sub)

        mismatch_id = Int64(1)
        sent = send_attach!(
            attach_proxy;
            correlation_id = mismatch_id,
            stream_id = UInt32(16201),
            client_id = UInt32(7),
            role = DriverRole.PRODUCER,
            expected_layout_version = UInt32(2),
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        @test sent == true
        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == mismatch_id
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
