@testset "System smoke test" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            producer_cfg = test_producer_config(
                dir;
                aeron_dir = aeron_dir,
                producer_instance_id = "test-producer",
            )
            consumer_cfg = test_consumer_config(dir; aeron_dir = aeron_dir, consumer_id = UInt32(42))
            supervisor_cfg = test_supervisor_config(; aeron_dir = aeron_dir)

            mkpath(dirname(parse_shm_uri(producer_cfg.header_uri).path))
            for pool in producer_cfg.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end

            producer = Producer.init_producer(producer_cfg; client = client)
            consumer = Consumer.init_consumer(consumer_cfg; client = client)
            supervisor = Supervisor.init_supervisor(supervisor_cfg; client = client)
            try
                prod_ctrl = Producer.make_control_assembler(producer)
                prod_qos = Producer.make_qos_assembler(producer)
                cons_ctrl = Consumer.make_control_assembler(consumer)
                got_frame = Ref(false)
                cons_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer) do st, buffer, _
                    header = MessageHeader.Decoder(buffer, 0)
                    if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
                        FrameDescriptor.wrap!(st.desc_decoder, buffer, 0; header = header)
                        result = Consumer.try_read_frame!(st, st.desc_decoder)
                        result && (got_frame[] = true)
                    end
                    nothing
                end)

                sup_ctrl = Supervisor.make_control_assembler(supervisor)
                sup_qos = Aeron.FragmentAssembler(Aeron.FragmentHandler(supervisor) do st, buffer, _
                    header = MessageHeader.Decoder(buffer, 0)
                    template_id = MessageHeader.templateId(header)
                    if template_id == TEMPLATE_QOS_PRODUCER
                        QosProducer.wrap!(st.qos_producer_decoder, buffer, 0; header = header)
                        AeronTensorPool.handle_qos_producer!(st, st.qos_producer_decoder)
                    elseif template_id == TEMPLATE_QOS_CONSUMER
                        QosConsumer.wrap!(st.qos_consumer_decoder, buffer, 0; header = header)
                        AeronTensorPool.handle_qos_consumer!(st, st.qos_consumer_decoder)
                    end
                    nothing
                end)

                payload = UInt8[1, 2, 3, 4]
                shape = Int32[4]
                strides = Int32[1]
                published = false

                ok = wait_for() do
                    Producer.producer_do_work!(producer, prod_ctrl; qos_assembler = prod_qos)
                    Consumer.consumer_do_work!(consumer, cons_desc, cons_ctrl)
                    Supervisor.supervisor_do_work!(supervisor, sup_ctrl, sup_qos)

                    if !published && consumer.mappings.header_mmap !== nothing
                        Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                        published = true
                    end
                    return published && got_frame[]
                end

                @test ok
            finally
                close_producer_state!(producer)
                close_consumer_state!(consumer)
                close_supervisor_state!(supervisor)
            end
        end
    end
end
