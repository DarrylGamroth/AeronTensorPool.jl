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

            announce_buf = Vector{UInt8}(undef, 1024)
            announce_enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(announce_enc, announce_buf, 0)
            AeronTensorPool.ShmPoolAnnounce.streamId!(announce_enc, producer_cfg.stream_id)
            AeronTensorPool.ShmPoolAnnounce.producerId!(announce_enc, producer_cfg.producer_id)
            AeronTensorPool.ShmPoolAnnounce.epoch!(announce_enc, UInt64(1))
            AeronTensorPool.ShmPoolAnnounce.announceTimestampNs!(announce_enc, UInt64(time_ns()))
            AeronTensorPool.ShmPoolAnnounce.announceClockDomain!(announce_enc, AeronTensorPool.ClockDomain.MONOTONIC)
            AeronTensorPool.ShmPoolAnnounce.layoutVersion!(announce_enc, producer_cfg.layout_version)
            AeronTensorPool.ShmPoolAnnounce.headerNslots!(announce_enc, producer_cfg.nslots)
            AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(announce_enc, UInt16(HEADER_SLOT_BYTES))
            pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(announce_enc, length(producer_cfg.payload_pools))
            for pool in producer_cfg.payload_pools
                entry = AeronTensorPool.ShmPoolAnnounce.PayloadPools.next!(pools)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolNslots!(entry, pool.nslots)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.regionUri!(entry, pool.uri)
            end
            AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(announce_enc, producer_cfg.header_uri)

            announce_dec = AeronTensorPool.ShmPoolAnnounce.Decoder(Vector{UInt8})
            header = AeronTensorPool.MessageHeader.Decoder(announce_buf, 0)
            AeronTensorPool.ShmPoolAnnounce.wrap!(announce_dec, announce_buf, 0; header = header)
            @test Consumer.map_from_announce!(consumer, announce_dec)
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
