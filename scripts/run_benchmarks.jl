#!/usr/bin/env julia
using Pkg

Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

include(joinpath(@__DIR__, "..", "bench", "benchmarks.jl"))

function parse_args(args)
    config = "config/defaults.toml"
    duration_s = 5.0
    run_system = false
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--system"
            run_system = true
        elseif arg == "--config" && i < length(args)
            i += 1
            config = args[i]
        elseif arg == "--duration" && i < length(args)
            i += 1
            duration_s = parse(Float64, args[i])
        end
        i += 1
    end
    return run_system, config, duration_s
end

run_system, config, duration_s = parse_args(ARGS)

run_benchmarks()

if run_system
    include(joinpath(@__DIR__, "..", "bench", "system_bench.jl"))
    run_system_bench(config, duration_s)
end
