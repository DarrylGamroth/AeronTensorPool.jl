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
    alloc_probe_iters = 0
    fixed_iters = 0
    alloc_breakdown = false
    noop_loop = false
    do_yield = true
    poll_timers = true
    do_publish = true
    poll_subs = true
    run_system = false
    run_bridge = false
    run_bridge_runners = false
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--system"
            run_system = true
        elseif arg == "--bridge"
            run_bridge = true
        elseif arg == "--bridge-runners"
            run_bridge_runners = true
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
        elseif arg == "--alloc-probe-iters" && i < length(args)
            i += 1
            alloc_probe_iters = parse(Int, args[i])
        elseif arg == "--fixed-iters" && i < length(args)
            i += 1
            fixed_iters = parse(Int, args[i])
        elseif arg == "--alloc-breakdown"
            alloc_breakdown = true
        elseif arg == "--noop-loop"
            noop_loop = true
        elseif arg == "--no-yield"
            do_yield = false
        elseif arg == "--no-poll-timers"
            poll_timers = false
        elseif arg == "--no-publish"
            do_publish = false
        elseif arg == "--no-poll-subs"
            poll_subs = false
        end
        i += 1
    end
    return run_system,
    run_bridge,
    run_bridge_runners,
    config,
    duration_s,
    payload_bytes,
    payload_bytes_list,
    warmup_s,
    alloc_sample,
    alloc_probe_iters,
    fixed_iters,
    alloc_breakdown,
    noop_loop,
    do_yield,
    poll_timers,
    do_publish,
    poll_subs
end

run_system,
run_bridge,
run_bridge_runners,
config,
duration_s,
payload_bytes,
payload_bytes_list,
warmup_s,
alloc_sample,
alloc_probe_iters,
fixed_iters,
alloc_breakdown,
noop_loop,
do_yield,
poll_timers,
do_publish,
poll_subs = parse_args(ARGS)

run_benchmarks()

if run_system || run_bridge || run_bridge_runners
    include(joinpath(@__DIR__, "..", "bench", "system_bench.jl"))
end
if run_system
    run_system_bench(
        config,
        duration_s;
        payload_bytes = payload_bytes,
        payload_bytes_list = payload_bytes_list,
        warmup_s = warmup_s,
        alloc_sample = alloc_sample,
        alloc_probe_iters = alloc_probe_iters,
        fixed_iters = fixed_iters,
        alloc_breakdown = alloc_breakdown,
        noop_loop = noop_loop,
        do_yield = do_yield,
        poll_timers = poll_timers,
        do_publish = do_publish,
        poll_subs = poll_subs,
    )
end
if run_bridge
    run_bridge_bench(
        config,
        duration_s;
        payload_bytes = payload_bytes,
        payload_bytes_list = payload_bytes_list,
        warmup_s = warmup_s,
        alloc_sample = alloc_sample,
        alloc_probe_iters = alloc_probe_iters,
        fixed_iters = fixed_iters,
        alloc_breakdown = alloc_breakdown,
        noop_loop = noop_loop,
        do_yield = do_yield,
        poll_timers = poll_timers,
        do_publish = do_publish,
        poll_subs = poll_subs,
    )
end
if run_bridge_runners
    run_bridge_bench_runners(
        config,
        duration_s;
        payload_bytes = payload_bytes,
        payload_bytes_list = payload_bytes_list,
        warmup_s = warmup_s,
        alloc_sample = alloc_sample,
        alloc_probe_iters = alloc_probe_iters,
        fixed_iters = fixed_iters,
        alloc_breakdown = alloc_breakdown,
        noop_loop = noop_loop,
        do_yield = do_yield,
        poll_timers = poll_timers,
        do_publish = do_publish,
        poll_subs = poll_subs,
    )
end
