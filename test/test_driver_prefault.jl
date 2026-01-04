using Test

@testset "Driver prefault zeros new regions" begin
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
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicies(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), true, UInt32(2000), "")
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

        header_uri = String(view(attach.header_region_uri))
        header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * 4)
        header_bytes = view(header_mmap, SUPERBLOCK_SIZE + 1:length(header_mmap))
        @test all(==(0x00), header_bytes)

        @test length(attach.pools) == 1
        pool_uri = String(view(attach.pools[1].region_uri))
        pool_mmap = mmap_shm(pool_uri, SUPERBLOCK_SIZE + Int(profile.header_nslots) * Int(profile.payload_pools[1].stride_bytes))
        pool_bytes = view(pool_mmap, SUPERBLOCK_SIZE + 1:length(pool_mmap))
        @test all(==(0x00), pool_bytes)

        close_driver_state!(driver_state)
        close(pub)
        close(sub)
    end
end
