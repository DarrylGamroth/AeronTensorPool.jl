#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

Base.exit_on_sigint(false)

function usage()
    println("Usage: julia --project scripts/run_rate_limiter.jl [rate_limiter_config]")
end

function load_rate_limiter_config_with_env(config_path::String)
    env = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env["RATE_LIMITER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    return load_rate_limiter_config(config_path; env = env)
end

function run_agent(config_path::String)
    config, mappings = load_rate_limiter_config_with_env(config_path)
    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing

    ctx = TensorPoolContext(
        ;
        aeron_dir = config.aeron_dir,
        control_channel = config.control_channel,
        control_stream_id = config.control_stream_id,
    )
    with_runtime(ctx; create_control = false) do runtime
        @info "RateLimiter agent init" aeron_dir = config.aeron_dir descriptor_channel = config.descriptor_channel descriptor_stream_id =
            config.descriptor_stream_id mappings = length(mappings)
        state = init_rate_limiter(config, mappings; client = runtime.aeron_client)
        agent = RateLimiterAgent(state)
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
                @error "RateLimiter error" exception = (e, catch_backtrace())
            end
        finally
            close(runner)
        end
    end
    return nothing
end

function run_rate_limiter_main(args::Vector{String})
    config_path = length(args) >= 1 ? args[1] : "config/rate_limiter_example.toml"
    @info "RateLimiter running" config_path
    run_agent(config_path)
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_rate_limiter_main(ARGS)
end
