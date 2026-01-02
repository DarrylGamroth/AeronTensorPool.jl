#!/usr/bin/env julia
using Pkg

Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

include(joinpath(@__DIR__, "..", "bench", "benchmarks.jl"))

function parse_args(args)
    config = "config/defaults.toml"
    duration_s = 5.0
    payload_bytes = 1024
    payload_bytes_list = Int[]
    warmup_s = 0.2
    alloc_sample = false
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
        elseif arg == "--payload-bytes" && i < length(args)
            i += 1
            payload_bytes = parse(Int, args[i])
        elseif arg == "--payload-bytes-list" && i < length(args)
            i += 1
            payload_bytes_list = [parse(Int, entry) for entry in split(args[i], ",") if !isempty(entry)]
        elseif arg == "--warmup" && i < length(args)
            i += 1
            warmup_s = parse(Float64, args[i])
        elseif arg == "--alloc-sample"
            alloc_sample = true
        end
        i += 1
    end
    return run_system, config, duration_s, payload_bytes, payload_bytes_list, warmup_s, alloc_sample
end

run_system, config, duration_s, payload_bytes, payload_bytes_list, warmup_s, alloc_sample = parse_args(ARGS)

run_benchmarks()

if run_system
    include(joinpath(@__DIR__, "..", "bench", "system_bench.jl"))
    run_system_bench(
        config,
        duration_s;
        payload_bytes = payload_bytes,
        payload_bytes_list = payload_bytes_list,
        warmup_s = warmup_s,
        alloc_sample = alloc_sample,
    )
end
