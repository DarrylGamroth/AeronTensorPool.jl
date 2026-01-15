using Test

@testset "Per-consumer max_rate_hz handling" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            header_uri = "shm:file?path=$(joinpath(dir, "tp_header"))"
            pool_uri = "shm:file?path=$(joinpath(dir, "tp_pool"))"
            cfg = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(1320),
                Int32(1321),
                Int32(1322),
                Int32(1323),
                UInt32(12),
                UInt32(120),
                UInt32(1),
                UInt32(8),
                dir,
                "tensorpool",
                "pc-rate",
                header_uri,
                PayloadPoolConfig[PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )
            state = Producer.init_producer(cfg; client = client)
            try
                buf = Vector{UInt8}(undef, 512)
                enc = ConsumerHello.Encoder(Vector{UInt8})
                ConsumerHello.wrap_and_apply_header!(enc, buf, 0)
                ConsumerHello.streamId!(enc, cfg.stream_id)
                ConsumerHello.consumerId!(enc, UInt32(1))
                ConsumerHello.supportsShm!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerHello.supportsProgress!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.FALSE)
                ConsumerHello.mode!(enc, Mode.STREAM)
                ConsumerHello.maxRateHz!(enc, UInt16(10))
                ConsumerHello.expectedLayoutVersion!(enc, cfg.layout_version)
                ConsumerHello.progressIntervalUs!(enc, typemax(UInt32))
                ConsumerHello.progressBytesDelta!(enc, typemax(UInt32))
                ConsumerHello.progressMajorDeltaUnits!(enc, typemax(UInt32))
                ConsumerHello.descriptorStreamId!(enc, UInt32(0))
                ConsumerHello.controlStreamId!(enc, UInt32(0))
                ConsumerHello.descriptorChannel!(enc, "")
                ConsumerHello.controlChannel!(enc, "")
                dec = ConsumerHello.Decoder(Vector{UInt8})
                header = MessageHeader.Decoder(buf, 0)
                ConsumerHello.wrap!(dec, buf, 0; header = header)
                Producer.handle_consumer_hello!(state, dec)
                @test isempty(state.consumer_streams)

                ConsumerHello.wrap_and_apply_header!(enc, buf, 0)
                ConsumerHello.streamId!(enc, cfg.stream_id)
                ConsumerHello.consumerId!(enc, UInt32(2))
                ConsumerHello.supportsShm!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerHello.supportsProgress!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.FALSE)
                ConsumerHello.mode!(enc, Mode.STREAM)
                ConsumerHello.maxRateHz!(enc, UInt16(5))
                ConsumerHello.expectedLayoutVersion!(enc, cfg.layout_version)
                ConsumerHello.progressIntervalUs!(enc, typemax(UInt32))
                ConsumerHello.progressBytesDelta!(enc, typemax(UInt32))
                ConsumerHello.progressMajorDeltaUnits!(enc, typemax(UInt32))
                ConsumerHello.descriptorStreamId!(enc, UInt32(2300))
                ConsumerHello.controlStreamId!(enc, UInt32(0))
                ConsumerHello.descriptorChannel!(enc, "aeron:ipc")
                ConsumerHello.controlChannel!(enc, "")
                ConsumerHello.wrap!(dec, buf, 0; header = header)
                Producer.handle_consumer_hello!(state, dec)
                entry = state.consumer_streams[UInt32(2)]
                @test entry.max_rate_hz == UInt16(5)
                @test entry.descriptor_timer.interval_ns == UInt64(1_000_000_000) ÷ UInt64(5)

                ConsumerHello.wrap_and_apply_header!(enc, buf, 0)
                ConsumerHello.streamId!(enc, cfg.stream_id)
                ConsumerHello.consumerId!(enc, UInt32(2))
                ConsumerHello.supportsShm!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerHello.supportsProgress!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.FALSE)
                ConsumerHello.mode!(enc, Mode.STREAM)
                ConsumerHello.maxRateHz!(enc, UInt16(0))
                ConsumerHello.expectedLayoutVersion!(enc, cfg.layout_version)
                ConsumerHello.progressIntervalUs!(enc, typemax(UInt32))
                ConsumerHello.progressBytesDelta!(enc, typemax(UInt32))
                ConsumerHello.progressMajorDeltaUnits!(enc, typemax(UInt32))
                ConsumerHello.descriptorStreamId!(enc, UInt32(2300))
                ConsumerHello.controlStreamId!(enc, UInt32(0))
                ConsumerHello.descriptorChannel!(enc, "aeron:ipc")
                ConsumerHello.controlChannel!(enc, "")
                ConsumerHello.wrap!(dec, buf, 0; header = header)
                Producer.handle_consumer_hello!(state, dec)
                entry = state.consumer_streams[UInt32(2)]
                @test entry.max_rate_hz == UInt16(0)
                @test entry.descriptor_timer.interval_ns == UInt64(0)
            finally
                close_producer_state!(state)
            end
        end
    end
end
