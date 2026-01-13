@testset "QoS monitor integration" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            producer_cfg = test_producer_config(
                dir;
                aeron_dir = aeron_dir,
                producer_instance_id = "qos-monitor-producer",
            )
            consumer_cfg = test_consumer_config(dir; aeron_dir = aeron_dir, consumer_id = UInt32(42))

            prepare_canonical_shm_layout(
                producer_cfg.shm_base_dir;
                namespace = producer_cfg.shm_namespace,
                stream_id = producer_cfg.stream_id,
                epoch = 1,
                pool_id = 1,
            )

            producer = Producer.init_producer(producer_cfg; client = client)
            consumer = Consumer.init_consumer(consumer_cfg; client = client)
            monitor = QosMonitor(consumer_cfg; client = client)

            try
                Producer.emit_qos!(producer)
                Consumer.emit_qos!(consumer)

                ok = wait_for() do
                    poll_qos!(monitor)
                    prod = producer_qos(monitor, producer_cfg.producer_id)
                    cons = consumer_qos(monitor, consumer_cfg.consumer_id)
                    return prod !== nothing && cons !== nothing
                end
                @test ok

                prod = producer_qos(monitor, producer_cfg.producer_id)
                cons = consumer_qos(monitor, consumer_cfg.consumer_id)
                @test prod !== nothing
                @test cons !== nothing
                @test prod.stream_id == producer_cfg.stream_id
                @test cons.stream_id == consumer_cfg.stream_id
                @test prod.producer_id == producer_cfg.producer_id
                @test cons.consumer_id == consumer_cfg.consumer_id
            finally
                close(monitor)
                close_producer_state!(producer)
                close_consumer_state!(consumer)
            end
        end
    end
end
