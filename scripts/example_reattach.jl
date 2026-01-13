#!/usr/bin/env julia
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/example_reattach.jl [driver_config]")
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function run_reattach(driver_cfg_path::String)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)

    producer_cfg = default_producer_config(;
        stream_id = stream_id,
        aeron_uri = driver_cfg.endpoints.control_channel,
        control_stream_id = driver_cfg.endpoints.control_stream_id,
        qos_stream_id = driver_cfg.endpoints.qos_stream_id,
    )

    ctx = TensorPoolContext(driver_cfg.endpoints)
    client = connect(ctx)
    try
        handle = attach_producer(client, producer_cfg; discover = false)
        @info "Producer attached" lease_id = handle.driver_client.lease_id
        close(handle)
        handle2 = attach_producer(client, producer_cfg; discover = false)
        @info "Producer reattached" lease_id = handle2.driver_client.lease_id
        close(handle2)
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
    run_reattach(driver_cfg)
    return nothing
end

main()
