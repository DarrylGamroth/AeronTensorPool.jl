#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

Base.exit_on_sigint(false)

function usage()
    println("Usage: julia --project scripts/run_bridge.jl [bridge_config] [driver_config]")
end

function resolve_aeron_dir(bridge_cfg::BridgeConfig)
    if !isempty(bridge_cfg.aeron_dir)
        return bridge_cfg.aeron_dir
    end
    return get(ENV, "AERON_DIR", "")
end

function load_driver_overrides(path::String)
    driver_cfg = load_driver_config(path)
    return (
        control_stream_id = driver_cfg.endpoints.control_stream_id,
        qos_stream_id = driver_cfg.endpoints.qos_stream_id,
        aeron_dir = driver_cfg.endpoints.aeron_dir,
    )
end

function run_agent(bridge_path::String, driver_path::Union{String, Nothing})
    bridge_cfg, mappings = load_bridge_config(bridge_path)
    isempty(mappings) && error("bridge config has no mappings")

    aeron_dir = resolve_aeron_dir(bridge_cfg)
    control_stream_id = Int32(1000)
    qos_stream_id = Int32(1200)
    if driver_path !== nothing
        overrides = load_driver_overrides(driver_path)
        control_stream_id = overrides.control_stream_id
        qos_stream_id = overrides.qos_stream_id
        if isempty(aeron_dir) && !isempty(overrides.aeron_dir)
            aeron_dir = overrides.aeron_dir
        end
    end
    stream_id = mappings[1].source_stream_id == 0 ? UInt32(10000) : mappings[1].source_stream_id
    consumer_cfg = default_consumer_config(
        ;
        aeron_dir = aeron_dir,
        stream_id = stream_id,
        control_stream_id = control_stream_id,
        qos_stream_id = qos_stream_id,
    )
    producer_cfg = default_producer_config(
        ;
        aeron_dir = aeron_dir,
        stream_id = stream_id,
        control_stream_id = control_stream_id,
        qos_stream_id = qos_stream_id,
    )

    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing

    Aeron.Context() do context
        AeronTensorPool.set_aeron_dir!(context, aeron_dir)
        Aeron.Client(context) do client
            @info "Bridge agent init" aeron_dir payload_channel = bridge_cfg.payload_channel payload_stream_id =
                bridge_cfg.payload_stream_id
            agent = BridgeSystemAgent(bridge_cfg, mappings, consumer_cfg, producer_cfg; client = client)
            runner = AgentRunner(BackoffIdleStrategy(), agent)
            if isnothing(core_id)
                Agent.start_on_thread(runner)
            else
                Agent.start_on_thread(runner, core_id)
            end
            try
                wait(runner)
            catch e
                if e isa InterruptException
                    @info "Shutting down..."
                else
                    @error "Bridge error" exception = (e, catch_backtrace())
                end
            finally
                close(runner)
            end
        end
    end
    return nothing
end

function run_bridge_main(args::Vector{String})
    bridge_path = length(args) >= 1 ? args[1] : "config/bridge_config_example.toml"
    driver_path = length(args) >= 2 ? args[2] : nothing
    run_agent(bridge_path, driver_path)
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_bridge_main(ARGS)
end
