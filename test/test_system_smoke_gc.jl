@testset "System smoke GC monitoring" begin
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
producer_instance_id = "test-producer"
header_uri = ""
max_dims = 8
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
max_dims = 8
mode = "STREAM"
decimation = 1
use_shm = true
supports_shm = true
supports_progress = false
max_rate_hz = 0
payload_fallback_uri = ""
shm_base_dir = "$(dir)"
allowed_base_dirs = ["$(dir)"]
require_hugepages = false
progress_interval_us = 250
progress_bytes_delta = 65536
progress_rows_delta = 0
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

            producer = init_producer(system.producer; client = client)
            consumer = init_consumer(system.consumer; client = client)
            supervisor = init_supervisor(system.supervisor; client = client)
                try

            prod_ctrl = make_control_assembler(producer)
            prod_qos = make_qos_assembler(producer)
            cons_ctrl = make_control_assembler(consumer)
            cons_desc = make_descriptor_assembler(consumer)
            sup_ctrl = make_control_assembler(supervisor)
            sup_qos = make_qos_assembler(supervisor)

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]

            GC.gc()
            start_num = Base.gc_num()
            start_live = Base.gc_live_bytes()

            iterations = get(ENV, "TP_GC_MONITOR_ITERS", "2000") |> x -> parse(Int, x)
            for i in 1:iterations
                producer_do_work!(producer, prod_ctrl; qos_assembler = prod_qos)
                consumer_do_work!(consumer, cons_desc, cons_ctrl)
                supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                if consumer.mappings.header_mmap !== nothing
                    offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
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
