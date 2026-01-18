@testset "Timebase clocks" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()
        aeron_uri = AeronTensorPool.DEFAULT_AERON_URI
        driver_cfg = DriverConfig(
            DriverEndpoints(
                "driver-test",
                Aeron.MediaDriver.aeron_dir(media_driver),
                aeron_uri,
                1000,
                aeron_uri,
                1001,
                aeron_uri,
                1200,
            ),
            DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir]),
            DriverPolicyConfig(true, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, false, false, false, UInt32(2000), ""),
            Dict("raw" => DriverProfileConfig("raw", UInt32(8), UInt16(256), UInt8(8), [DriverPoolConfig(UInt16(1), UInt32(1024))])),
            Dict{String, DriverStreamConfig}(),
        )
        driver_state = init_driver(driver_cfg; client = client.aeron_client)
        try
            @test driver_state.clock.clock isa Clocks.MonotonicClock

            prepare_canonical_shm_layout(
                base_dir;
                namespace = "tensorpool",
                stream_id = UInt32(10000),
                epoch = 1,
                pool_id = 1,
            )
            producer_cfg =
                test_producer_config(base_dir; aeron_dir = Aeron.MediaDriver.aeron_dir(media_driver))
            producer_state = Producer.init_producer(producer_cfg; client = client)
            try
                @test producer_state.clock.clock isa Clocks.MonotonicClock
            finally
                close_producer_state!(producer_state)
            end

            consumer_cfg = test_consumer_config(base_dir; aeron_dir = Aeron.MediaDriver.aeron_dir(media_driver))
            consumer_state = Consumer.init_consumer(consumer_cfg; client = client)
            try
                @test consumer_state.clock.clock isa Clocks.MonotonicClock
            finally
                close_consumer_state!(consumer_state)
            end
        finally
            close_driver_state!(driver_state)
        end
    end
end
