#!/usr/bin/env julia
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/example_invoker.jl [driver_config] [consumer_config]")
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function run_invoker(driver_cfg_path::String, consumer_cfg_path::String)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)

    env = Dict(ENV)
    env["TP_STREAM_ID"] = string(stream_id)
    consumer_cfg = load_consumer_config(consumer_cfg_path; env = env)
    consumer_cfg.aeron_uri = driver_cfg.endpoints.control_channel
    consumer_cfg.control_stream_id = driver_cfg.endpoints.control_stream_id
    consumer_cfg.qos_stream_id = driver_cfg.endpoints.qos_stream_id

    ctx = TensorPoolContext(driver_cfg.endpoints; use_invoker = true)
    client = connect(ctx)
    try
        handle = attach_consumer(client, consumer_cfg; discover = false)
        deadline = time_ns() + 2_000_000_000
        while time_ns() < deadline
            AeronTensorPool.do_work(client)
            AeronTensorPool.do_work(handle)
            yield()
        end
        close(handle)
    finally
        close(client)
    end
    return nothing
end

function main()
    Base.exit_on_sigint(false)
    if length(ARGS) > 2
        usage()
        exit(1)
    end
    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "config/driver_integration_example.toml"
    consumer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
    run_invoker(driver_cfg, consumer_cfg)
    return nothing
end

main()
