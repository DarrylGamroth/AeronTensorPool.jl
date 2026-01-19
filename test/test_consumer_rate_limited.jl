using Clocks

@testset "Consumer rate-limited mode" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(14012),
            Int32(14011),
            Int32(14013),
            UInt32(91),
            UInt32(62),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.RATE_LIMITED,
            UInt32(256),
            false,
            true,
            false,
            UInt16(1000),
            "",
            "/dev/shm",
            String[],
            false,
            UInt32(250),
            UInt32(65536),
            UInt32(0),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(3_000_000_000),
            "",
            UInt32(0),
            "",
            UInt32(0),
            false,
        )
        state = Consumer.init_consumer(consumer_cfg; client = client)
        try
            now_ns = UInt64(Clocks.time_nanos(state.clock))
            state.metrics.last_rate_ns = now_ns
            @test !Consumer.should_process(state, UInt64(1))
            state.metrics.last_rate_ns = UInt64(0)
            @test Consumer.should_process(state, UInt64(2))
            state.metrics.last_rate_ns = UInt64(1_000_000_000)
            @test !Consumer.should_process(state, UInt64(3), UInt64(1_000_000_500))
            @test Consumer.should_process(state, UInt64(4), UInt64(1_001_000_000))
            null_ts = FrameDescriptor.timestampNs_null_value(FrameDescriptor.Decoder)
            state.metrics.last_rate_ns = UInt64(0)
            @test Consumer.should_process(state, UInt64(5), null_ts)
        finally
            close_consumer_state!(state)
        end
    end
end
