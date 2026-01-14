@testset "Consumer seq gap resync" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(12042),
            Int32(12041),
            Int32(12043),
            UInt32(88),
            UInt32(61),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(2),
            false,
            true,
            false,
            UInt16(0),
            "",
            "",
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
            @test Consumer.maybe_track_gap!(state, UInt64(1)) == true
            @test state.metrics.drops_gap == 0
            @test state.metrics.last_seq_seen == 1
            @test state.metrics.seen_any == true

            @test Consumer.maybe_track_gap!(state, UInt64(5)) == false
            @test state.metrics.drops_gap == 3
            @test state.metrics.last_seq_seen == 5
            @test state.metrics.seen_any == false

            @test Consumer.maybe_track_gap!(state, UInt64(6)) == true
            @test state.metrics.drops_gap == 3
            @test state.metrics.last_seq_seen == 6
            @test state.metrics.seen_any == true

            state.mappings.header_mmap = UInt8[0x00]
            state.mappings.mapped_epoch = UInt64(1)
            Consumer.set_mapping_phase!(state, AeronTensorPool.MAPPED)
            @test Consumer.maybe_track_gap!(state, UInt64(4)) == false
            @test state.mappings.header_mmap === nothing
            @test state.phase == AeronTensorPool.UNMAPPED
        finally
            close_consumer_state!(state)
        end
    end
end
