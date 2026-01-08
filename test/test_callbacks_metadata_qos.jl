@testset "Callbacks: metadata and QoS" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            config_path = joinpath(dir, "config.toml")
            open(config_path, "w") do io
                write(
                    io,
                    """
[producer]
aeron_dir = ""
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
metadata_stream_id = 1300
stream_id = 1
producer_id = 7
layout_version = 1
nslots = 8
shm_base_dir = "$(dir)"
shm_namespace = "tensorpool"
producer_instance_id = "callbacks-producer"
header_uri = ""
announce_interval_ns = 1000000000
qos_interval_ns = 1000000000
progress_interval_ns = 250000
progress_bytes_delta = 65536

[[producer.payload_pools]]
pool_id = 1
uri = ""
stride_bytes = 4096
nslots = 8

[consumer]
aeron_dir = ""
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
stream_id = 1
consumer_id = 42
expected_layout_version = 1
mode = "STREAM"
use_shm = true
supports_shm = true
supports_progress = false
max_rate_hz = 0
payload_fallback_uri = ""
shm_base_dir = "$(dir)"
require_hugepages = false
progress_interval_us = 250
progress_bytes_delta = 65536
progress_major_delta_units = 0
hello_interval_ns = 1000000000
qos_interval_ns = 1000000000

[supervisor]
aeron_dir = ""
aeron_uri = "aeron:ipc"
control_stream_id = 1000
qos_stream_id = 1200
stream_id = 1
liveness_timeout_ns = 5000000000
liveness_check_interval_ns = 1000000000
""",
                )
            end

            env = Dict(ENV)
            env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
            system = load_system_config(config_path; env = env)

            prepare_canonical_shm_layout(
                system.producer.shm_base_dir;
                namespace = system.producer.shm_namespace,
                producer_instance_id = system.producer.producer_instance_id,
                epoch = 1,
                pool_id = 1,
            )

            producer = Producer.init_producer(system.producer; client = client)
            consumer = Consumer.init_consumer(system.consumer; client = client)
            monitor = QosMonitor(system.consumer; client = client)
            cache = MetadataCache(system.producer; client = client)

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

                    entry = metadata_entry(cache, system.producer.stream_id)
                    if entry !== nothing && entry.meta_version != last_meta
                        callbacks.on_metadata!(consumer, entry)
                        last_meta = entry.meta_version
                    end

                    prod = producer_qos(monitor, system.producer.producer_id)
                    if prod !== nothing
                        callbacks.on_qos_producer!(consumer, prod)
                    end

                    cons = consumer_qos(monitor, system.consumer.consumer_id)
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
