@testset "Allocation checks: producer/consumer loop" begin
    with_driver_and_client() do driver, client
        mktempdir() do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            producer_cfg = test_producer_config(
                dir;
                aeron_dir = aeron_dir,
                producer_instance_id = "alloc-producer",
                descriptor_stream_id = Int32(1110),
                control_stream_id = Int32(1111),
                qos_stream_id = Int32(1112),
                metadata_stream_id = Int32(1113),
            )
            consumer_cfg = test_consumer_config(
                dir;
                aeron_dir = aeron_dir,
                consumer_id = UInt32(42),
                descriptor_stream_id = Int32(1110),
                control_stream_id = Int32(1111),
                qos_stream_id = Int32(1112),
            )

            mkpath(dirname(parse_shm_uri(producer_cfg.header_uri).path))
            for pool in producer_cfg.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end

            producer = Producer.init_producer(producer_cfg; client = client)
            consumer = Consumer.init_consumer(consumer_cfg; client = client)

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]

            payload_entries = [
                (;
                    pool_id = pool.pool_id,
                    nslots = pool.nslots,
                    stride_bytes = pool.stride_bytes,
                    uri = pool.uri,
                ) for pool in producer_cfg.payload_pools
            ]
            announce = build_shm_pool_announce(
                stream_id = producer_cfg.stream_id,
                producer_id = producer_cfg.producer_id,
                epoch = UInt64(1),
                layout_version = producer_cfg.layout_version,
                nslots = producer_cfg.nslots,
                header_uri = producer_cfg.header_uri,
                payload_entries = payload_entries,
            )
            @test Consumer.map_from_announce!(consumer, announce.dec)
            @test consumer.mappings.header_mmap !== nothing

            desc_buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_DESCRIPTOR_LEN)
            desc_enc = AeronTensorPool.FrameDescriptor.Encoder(Vector{UInt8})
            AeronTensorPool.FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)
            desc_dec = AeronTensorPool.FrameDescriptor.Decoder(Vector{UInt8})

            try
                GC.gc()
                @test @allocated(Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))) == 0

                alloc_bytes = @allocated(begin
                    for i in 1:200
                        Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                        AeronTensorPool.FrameDescriptor.streamId!(desc_enc, producer_cfg.stream_id)
                        AeronTensorPool.FrameDescriptor.epoch!(desc_enc, UInt64(1))
                        AeronTensorPool.FrameDescriptor.seq!(desc_enc, UInt64(i - 1))
                        AeronTensorPool.FrameDescriptor.timestampNs!(desc_enc, UInt64(0))
                        AeronTensorPool.FrameDescriptor.metaVersion!(desc_enc, UInt32(0))
                        AeronTensorPool.FrameDescriptor.traceId!(desc_enc, UInt64(0))
                        header = AeronTensorPool.MessageHeader.Decoder(desc_buf, 0)
                        AeronTensorPool.FrameDescriptor.wrap!(desc_dec, desc_buf, 0; header = header)
                        Consumer.try_read_frame!(consumer, desc_dec)
                    end
                end)
                @test alloc_bytes == 0
            finally
                close_producer_state!(producer)
                close_consumer_state!(consumer)
            end
        end
    end
end
