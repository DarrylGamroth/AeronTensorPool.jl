using Test

@testset "Driver cleanup_shm_on_exit removes regions" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            15000,
            "aeron:ipc",
            15001,
            "aeron:ipc",
            15002,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, false, false, true, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(4),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(128))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(5001), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client)

        pub = Aeron.add_publication(client, "aeron:ipc", 15000)
        sub = Aeron.add_subscription(client, "aeron:ipc", 15000)

        attach_proxy = AttachRequestProxy(pub)
        poller = DriverResponsePoller(sub)

        correlation_id = Int64(1)
        sent = send_attach!(
            attach_proxy;
            correlation_id = correlation_id,
            stream_id = UInt32(5001),
            client_id = UInt32(7),
            role = DriverRole.PRODUCER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        @test sent

        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok
        attach = poller.last_attach
        @test attach !== nothing
        @test attach.code == DriverResponseCode.OK

        header_path = parse_shm_uri(String(view(attach.header_region_uri))).path
        pool_path = parse_shm_uri(String(view(attach.pools[1].region_uri))).path
        @test ispath(header_path)
        @test ispath(pool_path)

        close_driver_state!(driver_state)
        close(pub)
        close(sub)

        @test !ispath(header_path)
        @test !ispath(pool_path)
    end
end
