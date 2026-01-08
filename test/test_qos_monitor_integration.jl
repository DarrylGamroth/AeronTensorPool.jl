@testset "QoS monitor integration" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            config_path = joinpath(dir, "config.toml")
            open(config_path, "w") do io
                write(
                    io,
                    """
[producer]
aeron_dir = "/dev/shm/aeron-\${USER}"
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
producer_instance_id = "qos-monitor-producer"
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
aeron_dir = "/dev/shm/aeron-\${USER}"
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
aeron_dir = "/dev/shm/aeron-\${USER}"
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

            producer = Producer.init_producer(system.producer; client = client)
            consumer = Consumer.init_consumer(system.consumer; client = client)
            monitor = QosMonitor(system.consumer; client = client)

            try
                Producer.emit_qos!(producer)
                Consumer.emit_qos!(consumer)

                ok = wait_for() do
                    poll!(monitor)
                    prod = producer_qos(monitor, system.producer.producer_id)
                    cons = consumer_qos(monitor, system.consumer.consumer_id)
                    return prod !== nothing && cons !== nothing
                end
                @test ok

                prod = producer_qos(monitor, system.producer.producer_id)
                cons = consumer_qos(monitor, system.consumer.consumer_id)
                @test prod !== nothing
                @test cons !== nothing
                @test prod.stream_id == system.producer.stream_id
                @test cons.stream_id == system.consumer.stream_id
                @test prod.producer_id == system.producer.producer_id
                @test cons.consumer_id == system.consumer.consumer_id
            finally
                close(monitor)
                close_producer_state!(producer)
                close_consumer_state!(consumer)
            end
        end
    end
end
