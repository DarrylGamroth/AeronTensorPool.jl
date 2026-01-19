using Random
using Test

@testset "Auto-assigned client_id retries on conflict" begin
    with_driver_and_client() do driver, client
        base_dir = mktempdir()

        endpoints = AeronTensorPool.DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        shm = AeronTensorPool.DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = AeronTensorPool.DriverPolicyConfig(
            false,
            "raw",
            UInt32(100),
            UInt32(10_000),
            UInt32(3),
            false,
            false,
            false,
            false,
            UInt32(2000),
            "",
        )
        profile = AeronTensorPool.DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [AeronTensorPool.DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict("cam1" => AeronTensorPool.DriverStreamConfig("cam1", UInt32(10000), "raw"))
        cfg = AeronTensorPool.DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = AeronTensorPool.init_driver(cfg; client = client.aeron_client)

        Random.seed!(1234)
        first = rand(UInt32)
        first == 0 && (first = UInt32(1))
        _ = rand(UInt32) # correlation seed draw
        second = rand(UInt32)
        second == 0 && (second = UInt32(1))
        @test first != second

        lease_id = UInt64(1)
        lease = AeronTensorPool.Driver.DriverLease(
            lease_id,
            UInt32(10000),
            first,
            UInt32(1),
            UInt64(time_ns()) + UInt64(10_000_000_000),
            AeronTensorPool.Driver.LeaseLifecycle(),
            AeronTensorPool.DriverRole.CONSUMER,
        )
        driver_state.leases[lease_id] = lease
        driver_state.next_lease_id = lease_id + UInt64(1)

        Random.seed!(1234)
        consumer_cfg = AeronTensorPool.default_consumer_config(
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver),
            aeron_uri = "aeron:ipc",
            control_stream_id = Int32(1000),
            descriptor_stream_id = Int32(1100),
            qos_stream_id = Int32(1200),
            stream_id = UInt32(10000),
            consumer_id = UInt32(0),
            expected_layout_version = UInt32(1),
            shm_base_dir = base_dir,
        )

        running = Ref(true)
        driver_task = @async begin
            while running[]
                AeronTensorPool.driver_do_work!(driver_state)
                yield()
            end
        end

        handle = nothing
        try
            handle = AeronTensorPool.attach(client, consumer_cfg; discover = false)
            state = AeronTensorPool.handle_state(handle)
            @test state.config.consumer_id == second
            @test state.config.consumer_id != first
        finally
            running[] = false
            wait(driver_task)
            handle === nothing || close(handle)
            close_driver_state!(driver_state)
        end
    end
end
