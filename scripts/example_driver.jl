#!/usr/bin/env julia
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/example_driver.jl [driver_config]")
end

config_path = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"

try
    config = load_driver_config(config_path)
    state = init_driver(config)
    @info "Driver running" config_path
    while true
        work = driver_do_work!(state)
        work == 0 && yield()
    end
catch err
    @error "Driver exited" error = err
    usage()
    rethrow()
end
