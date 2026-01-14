using Test
using AeronTensorPool

@testset "Producer progress hint aggregation" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            cfg = test_producer_config(dir; aeron_dir = Aeron.MediaDriver.aeron_dir(driver))
            mkpath(dirname(parse_shm_uri(cfg.header_uri).path))
            for pool in cfg.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end
            state = Producer.init_producer(cfg; client = client)
            try
                buf = Vector{UInt8}(undef, 256)
                enc = ConsumerHello.Encoder(Vector{UInt8})
                ConsumerHello.wrap_and_apply_header!(enc, buf, 0)
                ConsumerHello.streamId!(enc, cfg.stream_id)
                ConsumerHello.consumerId!(enc, UInt32(1))
                ConsumerHello.supportsShm!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerHello.supportsProgress!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerHello.mode!(enc, Mode.STREAM)
                ConsumerHello.maxRateHz!(enc, UInt16(0))
                ConsumerHello.expectedLayoutVersion!(enc, cfg.layout_version)
                ConsumerHello.progressIntervalUs!(enc, typemax(UInt32))
                ConsumerHello.progressBytesDelta!(enc, typemax(UInt32))
                ConsumerHello.progressMajorDeltaUnits!(enc, UInt32(8))
                ConsumerHello.descriptorStreamId!(enc, UInt32(0))
                ConsumerHello.controlStreamId!(enc, UInt32(0))
                ConsumerHello.descriptorChannel!(enc, "")
                ConsumerHello.controlChannel!(enc, "")

                header = MessageHeader.Decoder(buf, 0)
                dec = ConsumerHello.Decoder(Vector{UInt8})
                ConsumerHello.wrap!(dec, buf, 0; header = header)
                Producer.handle_consumer_hello!(state, dec)
                @test state.progress_major_delta_units == UInt64(8)

                ConsumerHello.consumerId!(enc, UInt32(2))
                ConsumerHello.progressMajorDeltaUnits!(enc, UInt32(4))
                ConsumerHello.wrap!(dec, buf, 0; header = header)
                Producer.handle_consumer_hello!(state, dec)
                @test state.progress_major_delta_units == UInt64(4)
            finally
                close_producer_state!(state)
            end

            floor_cfg = ProducerConfig(
                cfg.aeron_dir,
                cfg.aeron_uri,
                cfg.descriptor_stream_id,
                cfg.control_stream_id,
                cfg.qos_stream_id,
                cfg.metadata_stream_id,
                cfg.stream_id,
                cfg.producer_id,
                cfg.layout_version,
                cfg.nslots,
                cfg.shm_base_dir,
                cfg.shm_namespace,
                cfg.producer_instance_id,
                cfg.header_uri,
                cfg.payload_pools,
                cfg.max_dims,
                cfg.announce_interval_ns,
                cfg.qos_interval_ns,
                cfg.progress_interval_ns,
                cfg.progress_bytes_delta,
                UInt32(6),
                cfg.mlock_shm,
            )
            floor_state = Producer.init_producer(floor_cfg; client = client)
            try
                buf = Vector{UInt8}(undef, 256)
                enc = ConsumerHello.Encoder(Vector{UInt8})
                ConsumerHello.wrap_and_apply_header!(enc, buf, 0)
                ConsumerHello.streamId!(enc, floor_cfg.stream_id)
                ConsumerHello.consumerId!(enc, UInt32(3))
                ConsumerHello.supportsShm!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerHello.supportsProgress!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerHello.mode!(enc, Mode.STREAM)
                ConsumerHello.maxRateHz!(enc, UInt16(0))
                ConsumerHello.expectedLayoutVersion!(enc, floor_cfg.layout_version)
                ConsumerHello.progressIntervalUs!(enc, typemax(UInt32))
                ConsumerHello.progressBytesDelta!(enc, typemax(UInt32))
                ConsumerHello.progressMajorDeltaUnits!(enc, UInt32(4))
                ConsumerHello.descriptorStreamId!(enc, UInt32(0))
                ConsumerHello.controlStreamId!(enc, UInt32(0))
                ConsumerHello.descriptorChannel!(enc, "")
                ConsumerHello.controlChannel!(enc, "")

                header = MessageHeader.Decoder(buf, 0)
                dec = ConsumerHello.Decoder(Vector{UInt8})
                ConsumerHello.wrap!(dec, buf, 0; header = header)
                Producer.handle_consumer_hello!(floor_state, dec)
                @test floor_state.progress_major_delta_units == UInt64(6)
            finally
                close_producer_state!(floor_state)
            end
        end
    end
end
