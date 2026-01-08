using Test

@testset "Driver reuse_existing_shm preserves existing data" begin
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
        policies = DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), true, true, false, true, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(2),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(64))],
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
        stream_state, status = AeronTensorPool.Driver.get_or_create_stream!(
            driver_state,
            UInt32(5001),
            DriverPublishMode.EXISTING_OR_CREATE,
        )
        @test stream_state !== nothing
        @test status == :ok
        stream_state.epoch = UInt64(42)

        header_uri, pool_uris = AeronTensorPool.canonical_shm_paths(
            base_dir,
            "stream-5001",
            endpoints.instance_id,
            stream_state.epoch,
            [UInt16(1)],
        )
        header_path = parse_shm_uri(header_uri).path
        pool_path = parse_shm_uri(pool_uris[UInt16(1)]).path

        header_size = SUPERBLOCK_SIZE + Int(profile.header_nslots) * Int(profile.header_slot_bytes)
        pool_size = SUPERBLOCK_SIZE + Int(profile.header_nslots) * Int(profile.payload_pools[1].stride_bytes)

        mkpath(dirname(header_path))
        open(header_path, "w") do io
            write(io, fill(UInt8(0xAB), header_size))
        end
        open(pool_path, "w") do io
            write(io, fill(UInt8(0xAB), pool_size))
        end

        AeronTensorPool.Driver.provision_stream_epoch!(driver_state, stream_state)

        header_mmap = mmap_shm_existing(header_uri, header_size)
        pool_mmap = mmap_shm_existing(pool_uris[UInt16(1)], pool_size)
        header_bytes = view(header_mmap, SUPERBLOCK_SIZE + 1:SUPERBLOCK_SIZE + 8)
        pool_bytes = view(pool_mmap, SUPERBLOCK_SIZE + 1:SUPERBLOCK_SIZE + 8)
        @test all(==(0xAB), header_bytes)
        @test all(==(0xAB), pool_bytes)

        close_driver_state!(driver_state)
    end
end
