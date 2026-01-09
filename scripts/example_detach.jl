#!/usr/bin/env julia
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/example_detach.jl [driver_config] [producer_config]")
end

function wait_for_detach(client::DriverClientState, correlation_id::Int64; timeout_ms::Int = 5000)
    deadline = time_ns() + Int64(timeout_ms) * 1_000_000
    while time_ns() < deadline
        driver_client_do_work!(client, UInt64(time_ns()))
        resp = client.poller.last_detach
        if resp !== nothing && resp.correlation_id == correlation_id
            return resp
        end
        yield()
    end
    return nothing
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function run_detach(driver_cfg_path::String, producer_cfg_path::String)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)

    env = Dict(ENV)
    env["TP_STREAM_ID"] = string(stream_id)
    producer_cfg = load_producer_config(producer_cfg_path; env = env)
    producer_cfg.control_stream_id = driver_cfg.endpoints.control_stream_id
    producer_cfg.aeron_uri = driver_cfg.endpoints.control_channel

    ctx = TensorPoolContext(driver_cfg.endpoints)
    client = connect(ctx)
    try
        handle = attach_producer(client, producer_cfg; discover = false)
        driver_client = handle.driver_client
        lease_id = driver_client.lease_id
        correlation_id = next_correlation_id!(driver_client)
        sent = send_detach!(
            driver_client.detach_proxy;
            correlation_id = correlation_id,
            lease_id = lease_id,
            stream_id = stream_id,
            client_id = driver_client.client_id,
            role = DriverRole.PRODUCER,
        )
        sent || error("detach send failed")
        resp = wait_for_detach(driver_client, correlation_id)
        resp === nothing && error("detach response timed out")
        println("detach code=$(resp.code) error=$(resp.error_message)")
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
    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
    producer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
    run_detach(driver_cfg, producer_cfg)
    return nothing
end

main()
