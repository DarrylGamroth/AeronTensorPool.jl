#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/example_driver.jl [driver_config]")
end

config_path = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
runner = nothing

try
    config = load_driver_config(config_path)
    Aeron.Context() do ctx
        AeronTensorPool.set_aeron_dir!(ctx, config.endpoints.aeron_dir)
        Aeron.Client(ctx) do client
            agent = DriverAgent(config; client = client)
            runner = AgentRunner(BusySpinIdleStrategy(), agent)
            @info "Driver running" config_path
            Agent.start_on_thread(runner)
            wait(runner)
            close(runner)
        end
    end
catch err
    @error "Driver exited" error = err
    usage()
    rethrow()
finally
    runner === nothing || close(runner)
end
