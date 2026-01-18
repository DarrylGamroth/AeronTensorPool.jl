@testset "Callbacks: metadata and QoS" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            producer_cfg = test_producer_config(
                dir;
                aeron_dir = aeron_dir,
                producer_instance_id = "callbacks-producer",
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
            monitor = QosMonitor(consumer_cfg; client = client.aeron_client)
            cache = MetadataCache(producer_cfg; client = client.aeron_client)

            meta_called = Ref(0)
            qos_prod_called = Ref(0)
            qos_cons_called = Ref(0)
            callbacks = ConsumerCallbacks(
                ;
                on_metadata! = (_, _) -> (meta_called[] += 1),
                on_qos_producer! = (_, _) -> (qos_prod_called[] += 1),
                on_qos_consumer! = (_, _) -> (qos_cons_called[] += 1),
            )

            try
                publisher = MetadataPublisher(producer)
                attrs = MetadataAttribute[MetadataAttribute("serial" => ("text/plain", "ABC"))]
                @test emit_metadata_announce!(publisher, UInt32(2), "camera-1"; summary = "cb")
                @test emit_metadata_meta!(publisher, UInt32(2), UInt64(12345), attrs)

                Producer.emit_qos!(producer)
                Consumer.emit_qos!(consumer)

                last_meta = UInt32(0)
                ok = wait_for() do
                    poll_metadata!(cache)
                    poll_qos!(monitor)

                    entry = metadata_entry(cache, producer_cfg.stream_id)
                    if entry !== nothing && entry.meta_version != last_meta
                        callbacks.on_metadata!(consumer, entry)
                        last_meta = entry.meta_version
                    end

                    prod = producer_qos(monitor, producer_cfg.producer_id)
                    if prod !== nothing
                        callbacks.on_qos_producer!(consumer, prod)
                    end

                    cons = consumer_qos(monitor, consumer_cfg.consumer_id)
                    if cons !== nothing
                        callbacks.on_qos_consumer!(consumer, cons)
                    end

                    return meta_called[] > 0 && qos_prod_called[] > 0 && qos_cons_called[] > 0
                end
                @test ok
            finally
                close(cache)
                close(monitor)
                close_producer_state!(producer)
                close_consumer_state!(consumer)
            end
        end
    end
end
