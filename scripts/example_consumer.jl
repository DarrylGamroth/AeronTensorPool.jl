#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

mutable struct AppConsumerAgent
    handle::ConsumerHandle
    max_count::Int
    last_frame::UInt64
    seen::Int
    last_frames_ok::UInt64
    last_drops_late::UInt64
    last_drops_header_invalid::UInt64
    last_log_ns::UInt64
    validate_limit::Int
    validated::Int
    ready::Bool
end

Agent.name(::AppConsumerAgent) = "app-consumer"

struct AppConsumerOnFrame
    app_ref::Base.RefValue{AppConsumerAgent}
end

function (hook::AppConsumerOnFrame)(state::ConsumerState, frame::ConsumerFrameView)
    app = hook.app_ref[]
    seq = seqlock_sequence(frame.header.seq_commit)
    expected = UInt8(seq % UInt64(256))
    payload = Consumer.payload_view(frame.payload)
    if app.validated < app.validate_limit
        app.validated += 1
        if !check_pattern(payload, expected)
            actual = isempty(payload) ? UInt8(0) : @inbounds payload[1]
            @warn "payload mismatch" seq expected actual
        end
    end
    app.seen += 1
    app.last_frame = seq
    if app.seen % 100 == 0
        println("frame=$(seq) ok")
    end
    return nothing
end

function Agent.on_start(agent::AppConsumerAgent)
    agent.ready = true
    return nothing
end

function Agent.do_work(agent::AppConsumerAgent)
    metrics = AeronTensorPool.handle_state(agent.handle).metrics
    if metrics.frames_ok != agent.last_frames_ok
        header = AeronTensorPool.handle_state(agent.handle).runtime.frame_view.header
        @info "Consumer frames_ok updated" frames_ok = metrics.frames_ok header_seq_commit = header.seq_commit
        agent.last_frames_ok = metrics.frames_ok
    end
    now_ns = UInt64(time_ns())
    if now_ns - agent.last_log_ns > 1_000_000_000
        @info "Consumer frame state" last_frame = agent.last_frame seen = agent.seen
        desc_connected = Aeron.is_connected(AeronTensorPool.handle_state(agent.handle).runtime.sub_descriptor)
        @info "Consumer descriptor connected" connected = desc_connected
        if metrics.drops_late != agent.last_drops_late ||
           metrics.drops_header_invalid != agent.last_drops_header_invalid
            @info "Consumer metrics" frames_ok = metrics.frames_ok drops_late = metrics.drops_late drops_header_invalid =
                metrics.drops_header_invalid
            agent.last_drops_late = metrics.drops_late
            agent.last_drops_header_invalid = metrics.drops_header_invalid
        end
        agent.last_log_ns = now_ns
    end
    return 0
end

function usage()
    println("Usage: julia --project scripts/example_consumer.jl [driver_config] [consumer_config] [count]")
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function check_pattern(payload::AbstractVector{UInt8}, expected::UInt8)
    isempty(payload) && return false
    @inbounds return payload[1] == expected
end

function run_consumer(driver_cfg_path::String, consumer_cfg_path::String, count::Int)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)

    env = Dict(ENV)
    if !haskey(env, "TP_CONSUMER_ID")
        env["TP_CONSUMER_ID"] = "2"
    end
    env["TP_STREAM_ID"] = string(stream_id)
    consumer_cfg = load_consumer_config(consumer_cfg_path; env = env)

    discovery_channel = get(ENV, "TP_DISCOVERY_CHANNEL", "")
    discovery_stream_id = parse(Int32, get(ENV, "TP_DISCOVERY_STREAM_ID", "0"))

    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing

    ctx = TensorPoolContext(
        driver_cfg.endpoints;
        discovery_channel = discovery_channel,
        discovery_stream_id = discovery_stream_id,
    )

    tp_client = connect(ctx)
    try
        app_ref = Ref{AppConsumerAgent}()
        hooks = ConsumerHooks(AppConsumerOnFrame(app_ref))
        handle = attach_consumer(tp_client, consumer_cfg; discover = !isempty(discovery_channel), hooks = hooks)
        app_agent = AppConsumerAgent(
            handle,
            count,
            UInt64(0),
            0,
            UInt64(0),
            UInt64(0),
            UInt64(0),
            UInt64(0),
            10,
            0,
            false,
        )
        app_ref[] = app_agent
        composite = AgentGroup(AeronTensorPool.handle_agent(handle), app_agent)
        runner = AgentRunner(BackoffIdleStrategy(), composite)
        if isnothing(core_id)
            Agent.start_on_thread(runner)
        else
            Agent.start_on_thread(runner, core_id)
        end
        try
            while !app_agent.ready
                yield()
            end
            if count > 0
                while app_agent.seen < count
                    yield()
                end
                close(runner)
            else
                wait(runner)
            end
        catch e
            if e isa InterruptException
                @info "Consumer shutting down..."
            else
                @error "Consumer error" exception = (e, catch_backtrace())
            end
        finally
            close(runner)
        end
        @info "Consumer done" app_agent.seen
        close(handle)
    finally
        close(tp_client)
    end
    return nothing
end

function main()
    Base.exit_on_sigint(false)
    if length(ARGS) > 3
        usage()
        exit(1)
    end

    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
    consumer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
    count = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0

    run_consumer(driver_cfg, consumer_cfg, count)
    return nothing
end

main()
