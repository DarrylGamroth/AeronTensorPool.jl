@testset "Producer descriptor publication headless" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            producer_cfg = test_producer_config(dir; aeron_dir = aeron_dir)

            mkpath(dirname(parse_shm_uri(producer_cfg.header_uri).path))
            for pool in producer_cfg.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end

            producer = Producer.init_producer(producer_cfg; client = client)
            try
                @test !Aeron.is_connected(producer.runtime.pub_descriptor)
                payload = UInt8[1, 2, 3, 4]
                shape = Int32[4]
                strides = Int32[1]
                sent = Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                @test sent

                sub = Aeron.add_subscription(client.aeron_client, producer_cfg.aeron_uri, producer_cfg.descriptor_stream_id)
                try
                    ok = wait_for() do
                        Aeron.is_connected(sub)
                    end
                    @test ok
                    handler = Aeron.FragmentHandler() do _, _, _
                        nothing
                    end
                    assembler = Aeron.FragmentAssembler(handler)
                    received = Aeron.poll(sub, assembler, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                    @test received == 0
                finally
                    close(sub)
                end
            finally
                close_producer_state!(producer)
            end
        end
    end
end

@testset "Producer descriptor publication connected" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            producer_cfg = test_producer_config(dir; aeron_dir = aeron_dir)

            mkpath(dirname(parse_shm_uri(producer_cfg.header_uri).path))
            for pool in producer_cfg.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end

            producer = Producer.init_producer(producer_cfg; client = client)
            sub = Aeron.add_subscription(client.aeron_client, producer_cfg.aeron_uri, producer_cfg.descriptor_stream_id)
            try
                ok = wait_for() do
                    Aeron.is_connected(producer.runtime.pub_descriptor) && Aeron.is_connected(sub)
                end
                @test ok

                payload = UInt8[1, 2, 3, 4]
                shape = Int32[4]
                strides = Int32[1]
                sent = Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                @test sent

                got_desc = Ref(false)
                template_frame_descriptor = AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR
                handler = Aeron.FragmentHandler() do _, buffer, _
                    header = MessageHeader.Decoder(buffer, 0)
                    if MessageHeader.templateId(header) == template_frame_descriptor
                        got_desc[] = true
                    end
                    nothing
                end
                assembler = Aeron.FragmentAssembler(handler)
                ok = wait_for() do
                    Aeron.poll(sub, assembler, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT) > 0 && got_desc[]
                end
                @test ok
            finally
                close(sub)
                close_producer_state!(producer)
            end
        end
    end
end
