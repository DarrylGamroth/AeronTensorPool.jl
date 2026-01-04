#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/example_driver.jl [driver_config]")
end

mutable struct AppDriverAgent
    config_path::String
    ctx::Union{Aeron.Context, Nothing}
    client::Union{Aeron.Client, Nothing}
    driver_agent::Union{DriverAgent, Nothing}
    media_driver::Union{Aeron.MediaDriver.Driver, Nothing}
    ready::Bool
end

Agent.name(::AppDriverAgent) = "app-driver"

function Agent.on_start(agent::AppDriverAgent)
    env = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    config = load_driver_config(agent.config_path; env = env)
    launch_media_driver = get(ENV, "LAUNCH_MEDIA_DRIVER", "false") == "true"
    if launch_media_driver
        md_ctx = Aeron.MediaDriver.Context()
        AeronTensorPool.set_aeron_dir!(md_ctx, config.endpoints.aeron_dir)
        agent.media_driver = Aeron.MediaDriver.launch(md_ctx)
    end
    agent.ctx = Aeron.Context()
    AeronTensorPool.set_aeron_dir!(agent.ctx, config.endpoints.aeron_dir)
    agent.client = Aeron.Client(agent.ctx)
    agent.driver_agent = DriverAgent(config; client = agent.client)
    agent.ready = true
    return nothing
end

function Agent.do_work(agent::AppDriverAgent)
    agent.driver_agent === nothing && return 0
    return Agent.do_work(agent.driver_agent)
end

function Agent.on_close(agent::AppDriverAgent)
    if agent.driver_agent !== nothing
        try
            Agent.on_close(agent.driver_agent)
        catch
        end
    end
    if agent.media_driver !== nothing
        try
            close(agent.media_driver)
        catch
        end
    end
    if agent.client !== nothing
        try
            close(agent.client)
        catch
        end
    end
    if agent.ctx !== nothing
        try
            close(agent.ctx)
        catch
        end
    end
    return nothing
end

function main()
    config_path = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
    runner = nothing
    try
        agent = AppDriverAgent(config_path, nothing, nothing, nothing, nothing, false)
        runner = AgentRunner(BusySpinIdleStrategy(), agent)
        @info "Driver running" config_path
        Agent.start_on_thread(runner)
        wait(runner)
        close(runner)
    catch err
        @error "Driver exited" error = err
        usage()
        rethrow()
    finally
        runner === nothing || close(runner)
    end
    return nothing
end

main()
