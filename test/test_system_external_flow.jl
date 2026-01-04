using Test

@testset "External process flow" begin
    run_external = get(ENV, "ATP_RUN_EXTERNAL_TESTS", "") == "1"
    run_external || return @test true

    mktempdir() do dir
        driver_cfg = joinpath(dir, "driver.toml")
        producer_cfg = joinpath(dir, "producer.toml")
        consumer_cfg = joinpath(dir, "consumer.toml")

        open(driver_cfg, "w") do io
            write(
                io,
                """
[driver]
instance_id = "driver-test"
aeron_dir = ""
control_channel = "aeron:ipc"
control_stream_id = 15100
announce_channel = "aeron:ipc"
announce_stream_id = 15101
qos_channel = "aeron:ipc"
qos_stream_id = 15102

[shm]
base_dir = "$(dir)"
require_hugepages = false
page_size_bytes = 4096
permissions_mode = "660"

[policies]
allow_dynamic_streams = false
default_profile = "camera"
announce_period_ms = 1000
lease_keepalive_interval_ms = 1000
lease_expiry_grace_intervals = 3

[profiles.camera]
header_nslots = 64
header_slot_bytes = 256
max_dims = 8
payload_pools = [
  { pool_id = 1, stride_bytes = 4096 }
]

[streams.cam1]
stream_id = 1
profile = "camera"
""",
            )
        end

        open(producer_cfg, "w") do io
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
producer_id = 1
layout_version = 1
nslots = 64
shm_base_dir = "$(dir)"
shm_namespace = "tensorpool"
producer_instance_id = "external-producer"
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
nslots = 64
""",
            )
        end

        open(consumer_cfg, "w") do io
            write(
                io,
                """
[consumer]
aeron_dir = ""
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
stream_id = 1
consumer_id = 1
expected_layout_version = 1
max_dims = 8
mode = "STREAM"
decimation = 1
max_outstanding_seq_gap = 0
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
""",
            )
        end

        Aeron.MediaDriver.launch(Aeron.MediaDriver.Context()) do driver
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            env = Dict(ENV)
            env["AERON_DIR"] = aeron_dir
            env["LAUNCH_MEDIA_DRIVER"] = "false"

            julia_exec = Base.julia_cmd().exec
            project = Base.active_project()

            driver_cmd = Cmd(
                vcat(julia_exec, ["--project=$(project)", "scripts/example_driver.jl", driver_cfg]);
                env = env,
            )
            producer_cmd = Cmd(
                vcat(julia_exec, ["--project=$(project)", "scripts/example_producer.jl", driver_cfg, producer_cfg, "5", "256"]);
                env = env,
            )
            consumer_cmd = Cmd(
                vcat(julia_exec, ["--project=$(project)", "scripts/example_consumer.jl", driver_cfg, consumer_cfg, "5"]);
                env = env,
            )

            driver_proc = run(driver_cmd; wait = false)
            sleep(0.5)
            consumer_proc = run(consumer_cmd; wait = false)
            producer_proc = run(producer_cmd; wait = false)

            wait(consumer_proc)
            wait(producer_proc)

            @test success(consumer_proc)
            @test success(producer_proc)

            kill(driver_proc)
            wait(driver_proc)
        end
    end
end
