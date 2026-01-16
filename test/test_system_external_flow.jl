using Test

@testset "External process flow" begin
    run_external = get(ENV, "ATP_RUN_EXTERNAL_TESTS", "1") == "1"
    run_external || return @test true

    function wait_process(proc::Base.Process, timeout_s::Float64)
        ok = wait_for(() -> !Base.process_running(proc); timeout = timeout_s, sleep_s = 0.05)
        if !ok
            kill(proc)
            wait(proc)
            return false
        end
        wait(proc)
        return true
    end

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
            env = Dict(ENV)
            env["AERON_DIR"] = aeron_dir
            env["LAUNCH_MEDIA_DRIVER"] = "false"

            julia_exec = Base.julia_cmd().exec
            project = Base.active_project()
            driver_script = joinpath(repo_root, "scripts", "run_driver.jl")
            producer_script = joinpath(repo_root, "scripts", "example_producer.jl")
            consumer_script = joinpath(repo_root, "scripts", "example_consumer.jl")

            driver_log = joinpath(dir, "driver.log")
            producer_log = joinpath(dir, "producer.log")
            consumer_log = joinpath(dir, "consumer.log")
            env_driver = Dict(env)
            env_producer = Dict(env)
            env_consumer = Dict(env)
            ready_file = joinpath(dir, "consumer.ready")
            env_producer["TP_EXAMPLE_LOG_EVERY"] = "1"
            env_consumer["TP_EXAMPLE_LOG_EVERY"] = "1"
            env_consumer["TP_FAIL_ON_MISMATCH"] = "1"
            env_consumer["TP_READY_FILE"] = ready_file

            driver_cmd = setenv(
                Cmd(vcat(julia_exec, ["--project=$(project)", driver_script, driver_cfg])),
                env_driver,
            )
            producer_cmd = setenv(
                Cmd(
                    vcat(julia_exec, [
                        "--project=$(project)",
                        producer_script,
                        driver_cfg,
                        "5",
                        "256",
                    ]),
                ),
                env_producer,
            )
            consumer_cmd = setenv(
                Cmd(
                    vcat(julia_exec, [
                        "--project=$(project)",
                        consumer_script,
                        driver_cfg,
                        "5",
                    ]),
                ),
                env_consumer,
            )

            driver_io = open(driver_log, "w")
            producer_io = open(producer_log, "w")
            consumer_io = open(consumer_log, "w")
            driver_proc = run(pipeline(driver_cmd; stdout = driver_io, stderr = driver_io); wait = false)
            sleep(1.0)
            consumer_proc = run(pipeline(consumer_cmd; stdout = consumer_io, stderr = consumer_io); wait = false)
            timeout_s = parse(Float64, get(ENV, "TP_EXAMPLE_TIMEOUT", "30"))
            ready_ok = wait_for(() -> isfile(ready_file); timeout = timeout_s, sleep_s = 0.05)
            if !ready_ok
                kill(consumer_proc)
                wait(consumer_proc)
                kill(driver_proc)
                wait(driver_proc)
                close(consumer_io)
                close(producer_io)
                close(driver_io)
                return @test ready_ok
            end
            producer_proc = run(pipeline(producer_cmd; stdout = producer_io, stderr = producer_io); wait = false)

            consumer_ok = wait_process(consumer_proc, timeout_s)
            producer_ok = wait_process(producer_proc, timeout_s)
            close(consumer_io)
            close(producer_io)

            @test consumer_ok
            @test producer_ok
            @test success(consumer_proc)
            @test success(producer_proc)

            producer_output = read(producer_log, String)
            consumer_output = read(consumer_log, String)
            @test occursin("Producer done", producer_output)
            @test occursin("Producer published frame", producer_output)
            @test occursin("frame=", consumer_output)
            @test occursin("Consumer done", consumer_output)

            kill(driver_proc)
            wait(driver_proc)
            close(driver_io)
        end
    end
end
