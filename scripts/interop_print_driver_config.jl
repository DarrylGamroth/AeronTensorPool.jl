#!/usr/bin/env julia
using AeronTensorPool
using TOML

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function first_payload_stride(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    profile = cfg.profiles[first(values(cfg.streams)).profile]
    isempty(profile.payload_pools) && return UInt32(0)
    return profile.payload_pools[1].stride_bytes
end

function main()
    if length(ARGS) < 1
        println("Usage: julia --project scripts/interop_print_driver_config.jl <driver_config>")
        return 1
    end
    config_path = ARGS[1]
    env = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    if haskey(ENV, "TP_CONTROL_CHANNEL")
        env["DRIVER_CONTROL_CHANNEL"] = ENV["TP_CONTROL_CHANNEL"]
    end
    if haskey(ENV, "TP_CONTROL_STREAM_ID")
        env["DRIVER_CONTROL_STREAM_ID"] = ENV["TP_CONTROL_STREAM_ID"]
    end
    cfg = load_driver_config(config_path; env = env)

    println("aeron_dir=$(cfg.endpoints.aeron_dir)")
    println("control_channel=$(cfg.endpoints.control_channel)")
    println("control_stream_id=$(cfg.endpoints.control_stream_id)")
    println("announce_channel=$(cfg.endpoints.announce_channel)")
    println("announce_stream_id=$(cfg.endpoints.announce_stream_id)")
    println("qos_channel=$(cfg.endpoints.qos_channel)")
    println("qos_stream_id=$(cfg.endpoints.qos_stream_id)")
    println("stream_id=$(first_stream_id(cfg))")
    println("payload_stride_bytes=$(first_payload_stride(cfg))")
    return 0
end

main()
