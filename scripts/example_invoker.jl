#!/usr/bin/env julia
using AeronTensorPool
include(joinpath(@__DIR__, "script_errors.jl"))

function usage()
    println("Usage: julia --project scripts/example_invoker.jl [driver_config]")
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function run_invoker(driver_cfg_path::String)
    driver_cfg = from_toml(DriverConfig, driver_cfg_path; env = true)
    stream_id = first_stream_id(driver_cfg)

    consumer_cfg = default_consumer_config(;
        stream_id = stream_id,
        aeron_uri = driver_cfg.endpoints.control_channel,
        control_stream_id = driver_cfg.endpoints.control_stream_id,
        qos_stream_id = driver_cfg.endpoints.qos_stream_id,
    )

    ctx = TensorPoolContext(driver_cfg.endpoints; use_invoker = true)
    client = connect(ctx)
    try
        handle = try
            attach(client, consumer_cfg; discover = false)
        catch err
            report_script_error(err)
            rethrow()
        end
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
    if length(ARGS) > 1
        usage()
        exit(1)
    end
    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "config/driver_integration_example.toml"
    run_invoker(driver_cfg)
    return nothing
end

main()
