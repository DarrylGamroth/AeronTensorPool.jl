using Test

@testset "External process flow" begin
    run_external = get(ENV, "ATP_RUN_EXTERNAL_TESTS", "0") == "1"
    run_external || return @test true

    mktempdir("/dev/shm") do dir
        repo_root = abspath(joinpath(@__DIR__, ".."))
        driver_cfg = joinpath(dir, "driver.toml")

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
payload_pools = [
  { pool_id = 1, stride_bytes = 4096 }
]

[streams.cam1]
stream_id = 10000
profile = "camera"
""",
            )
        end

        Aeron.MediaDriver.launch_embedded() do driver
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            driver_script = joinpath(repo_root, "scripts", "run_driver.jl")
            producer_script = joinpath(repo_root, "scripts", "example_producer.jl")
            consumer_script = joinpath(repo_root, "scripts", "example_consumer.jl")

            driver_log = joinpath(dir, "driver.log")
            producer_log = joinpath(dir, "producer.log")
            consumer_log = joinpath(dir, "consumer.log")
            env = external_env(aeron_dir)
            env_driver = Dict(env)
            env_producer = Dict(env)
            env_consumer = Dict(env)
            ready_file = joinpath(dir, "consumer.ready")
            env_producer["TP_EXAMPLE_LOG_EVERY"] = "1"
            env_consumer["TP_EXAMPLE_LOG_EVERY"] = "1"
            env_consumer["TP_FAIL_ON_MISMATCH"] = "1"
            env_consumer["TP_READY_FILE"] = ready_file

            driver_proc = start_external_julia(
                [driver_script, driver_cfg];
                env = env_driver,
                log_path = driver_log,
            )
            sleep(1.0)
            consumer_proc = start_external_julia(
                [consumer_script, driver_cfg, "5"];
                env = env_consumer,
                log_path = consumer_log,
            )
            timeout_s = EXTERNAL_TEST_TIMEOUT_SEC
            ready_ok = wait_for(() -> isfile(ready_file); timeout = timeout_s, sleep_s = 0.05)
            if !ready_ok
                stop_external(consumer_proc)
                stop_external(driver_proc)
                close_external(consumer_proc)
                close_external(driver_proc)
                return @test ready_ok
            end
            sleep(0.5)
            producer_proc = start_external_julia(
                [producer_script, driver_cfg, "25", "256"];
                env = env_producer,
                log_path = producer_log,
            )

            consumer_ok = wait_external(consumer_proc, timeout_s)
            producer_ok = wait_external(producer_proc, timeout_s)
            close_external(consumer_proc)
            close_external(producer_proc)

            @test consumer_ok
            @test producer_ok
            @test success(consumer_proc.proc)
            @test success(producer_proc.proc)

            producer_output = read_external(producer_proc)
            consumer_output = read_external(consumer_proc)
            @test occursin("Producer done", producer_output)
            @test occursin("Producer published frame", producer_output)
            @test occursin("frame=", consumer_output)
            @test occursin("Consumer done", consumer_output)

            stop_external(driver_proc)
            close_external(driver_proc)
        end
    end
end
