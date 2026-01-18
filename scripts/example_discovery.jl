#!/usr/bin/env julia
using AeronTensorPool
include(joinpath(@__DIR__, "script_errors.jl"))

function usage()
    println("Usage: julia --project scripts/example_discovery.jl [driver_config]")
    println("Env: TP_DISCOVERY_CHANNEL, TP_DISCOVERY_STREAM_ID, TP_DISCOVERY_RESPONSE_CHANNEL, TP_DISCOVERY_RESPONSE_STREAM_ID")
end

function run_discovery(driver_cfg_path::String)
    driver_cfg = from_toml(DriverConfig, driver_cfg_path; env = true)

    discovery_channel = get(ENV, "TP_DISCOVERY_CHANNEL", "aeron:ipc?term-length=4m")
    discovery_stream_id = parse(Int32, get(ENV, "TP_DISCOVERY_STREAM_ID", "7000"))
    response_channel = get(ENV, "TP_DISCOVERY_RESPONSE_CHANNEL", "")
    response_stream_id = parse(UInt32, get(ENV, "TP_DISCOVERY_RESPONSE_STREAM_ID", "0"))

    ctx = TensorPoolContext(
        driver_cfg.endpoints;
        discovery_channel = discovery_channel,
        discovery_stream_id = discovery_stream_id,
        discovery_response_channel = response_channel,
        discovery_response_stream_id = response_stream_id,
    )
    client = connect(ctx)
    try
        entry = try
            discover_stream!(client)
        catch err
            report_script_error(err)
            rethrow()
        end
        println("discovery: stream_id=$(entry.stream_id) producer_id=$(entry.producer_id) epoch=$(entry.epoch)")
        println("header_uri=$(entry.header_region_uri)")
        println("pools=$(length(entry.pools))")
        for pool in entry.pools
            println("pool_id=$(pool.pool_id) stride_bytes=$(pool.stride_bytes) uri=$(pool.region_uri)")
        end
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
    run_discovery(driver_cfg)
    return nothing
end

main()
