@testset "Driver SHM permissions" begin
    Sys.isunix() || return
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()
        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            15200,
            "aeron:ipc",
            15201,
            "aeron:ipc",
            15202,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "600", [base_dir])
        policies =
            DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), true, true, false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(2),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(64))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(5002), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client.aeron_client)
        stream_state, status = AeronTensorPool.Driver.get_or_create_stream!(
            driver_state,
            UInt32(5002),
            DriverPublishMode.EXISTING_OR_CREATE,
        )
        @test status == :ok
        AeronTensorPool.Driver.provision_stream_epoch!(driver_state, stream_state)

        header_path = parse_shm_uri(stream_state.header_uri).path
        pool_path = parse_shm_uri(stream_state.pool_uris[UInt16(1)]).path
        @test (stat(header_path).mode & 0o777) == 0o600
        @test (stat(pool_path).mode & 0o777) == 0o600

        close_driver_state!(driver_state)
    end
end
