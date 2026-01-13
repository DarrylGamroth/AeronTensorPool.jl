@testset "System smoke GC monitoring" begin
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
                cons_desc = Consumer.make_descriptor_assembler(consumer)
                sup_ctrl = Supervisor.make_control_assembler(supervisor)
                sup_qos = Supervisor.make_qos_assembler(supervisor)

                payload = UInt8[1, 2, 3, 4]
                shape = Int32[4]
                strides = Int32[1]

                GC.gc()
                start_num = Base.gc_num()
                start_live = Base.gc_live_bytes()

                iterations = get(ENV, "TP_GC_MONITOR_ITERS", "2000") |> x -> parse(Int, x)
                for _ in 1:iterations
                    Producer.producer_do_work!(producer, prod_ctrl; qos_assembler = prod_qos)
                    Consumer.consumer_do_work!(consumer, cons_desc, cons_ctrl)
                    Supervisor.supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                    if consumer.mappings.header_mmap !== nothing
                        Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                    end
                    yield()
                end

                GC.gc()
                end_num = Base.gc_num()
                end_live = Base.gc_live_bytes()

                allocd_delta = end_num.allocd - start_num.allocd
                live_delta = end_live - start_live

                limit = get(ENV, "TP_GC_ALLOC_LIMIT_BYTES", "50000000") |> x -> parse(Int, x)
                live_limit = get(ENV, "TP_GC_LIVE_LIMIT_BYTES", "50000000") |> x -> parse(Int, x)

                @test allocd_delta <= limit
                @test live_delta <= live_limit
            finally
                close_producer_state!(producer)
                close_consumer_state!(consumer)
                close_supervisor_state!(supervisor)
            end
        end
    end
end
