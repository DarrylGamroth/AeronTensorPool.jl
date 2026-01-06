#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

Base.exit_on_sigint(false)

function usage()
    println("Usage: julia --project scripts/run_driver.jl [driver_config]")
end

function load_driver_config_with_env(config_path::String)
    env = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    return load_driver_config(config_path; env = env)
end

function run_agent(config_path::String)
    config = load_driver_config_with_env(config_path)
    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing

    Aeron.Context() do context
        AeronTensorPool.set_aeron_dir!(context, config.endpoints.aeron_dir)
        Aeron.Client(context) do client
            @info "Driver agent init" aeron_dir = config.endpoints.aeron_dir control_channel =
                config.endpoints.control_channel control_stream_id = config.endpoints.control_stream_id
            agent = DriverAgent(config; client = client)
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
                    @error "Driver error" exception = (e, catch_backtrace())
                end
            finally
                close(runner)
            end
        end
    end
    return nothing
end

function main()
    config_path = length(ARGS) >= 1 ? ARGS[1] : "config/defaults.toml"
    launch_driver = parse(Bool, get(ENV, "LAUNCH_MEDIA_DRIVER", "false"))

    if launch_driver
        @info "Launching Aeron MediaDriver"
        config = load_driver_config_with_env(config_path)
        md_ctx = Aeron.MediaDriver.Context()
        isempty(config.endpoints.aeron_dir) || Aeron.MediaDriver.aeron_dir!(md_ctx, config.endpoints.aeron_dir)
        Aeron.MediaDriver.launch(md_ctx) do _
            @info "Driver running" config_path
            run_agent(config_path)
        end
    else
        @info "Running with external MediaDriver"
        @info "Driver running" config_path
        run_agent(config_path)
    end
    return 0
end

main()
