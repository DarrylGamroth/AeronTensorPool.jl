#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging
include(joinpath(@__DIR__, "script_errors.jl"))

mutable struct AppRateLimitedConsumerAgent
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

Agent.name(::AppRateLimitedConsumerAgent) = "app-rate-limited-consumer"

struct AppConsumerOnFrame
    app_ref::Base.RefValue{AppRateLimitedConsumerAgent}
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

function Agent.on_start(agent::AppRateLimitedConsumerAgent)
    agent.ready = true
    return nothing
end

function Agent.do_work(agent::AppRateLimitedConsumerAgent)
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
    println(
        "Usage: julia --project scripts/example_rate_limited_consumer.jl [driver_config] [count] [max_rate_hz]",
    )
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function check_pattern(payload::AbstractVector{UInt8}, expected::UInt8)
    isempty(payload) && return false
    @inbounds return payload[1] == expected
end

function apply_per_consumer_channels!(
    cfg::ConsumerConfig,
    channel::String,
    descriptor_stream_id::UInt32,
    control_stream_id::UInt32,
    max_rate_hz::UInt16,
)
    cfg.max_rate_hz = max_rate_hz
    cfg.mode = Mode.RATE_LIMITED
    cfg.requested_descriptor_channel = channel
    cfg.requested_descriptor_stream_id = descriptor_stream_id
    cfg.requested_control_channel = channel
    cfg.requested_control_stream_id = control_stream_id
    return nothing
end

function per_consumer_stream_id(base::UInt32, consumer_id::UInt32)
    return base + consumer_id
end

function run_consumer(
    driver_cfg_path::String,
    count::Int,
    max_rate_hz::UInt16,
)
    driver_cfg = from_toml(DriverConfig, driver_cfg_path; env = true)
    stream_id = first_stream_id(driver_cfg)

    consumer_id = UInt32(parse(Int, get(ENV, "TP_CONSUMER_ID", "2")))
    consumer_cfg = default_consumer_config(; stream_id = stream_id, consumer_id = consumer_id)

    per_consumer_channel = get(ENV, "TP_PER_CONSUMER_CHANNEL", "aeron:ipc")
    base_descriptor_id = UInt32(parse(Int, get(ENV, "TP_PER_CONSUMER_DESCRIPTOR_BASE", "21000")))
    base_control_id = UInt32(parse(Int, get(ENV, "TP_PER_CONSUMER_CONTROL_BASE", "22000")))
    descriptor_stream_id = per_consumer_stream_id(base_descriptor_id, consumer_cfg.consumer_id)
    control_stream_id = per_consumer_stream_id(base_control_id, consumer_cfg.consumer_id)
    apply_per_consumer_channels!(
        consumer_cfg,
        per_consumer_channel,
        descriptor_stream_id,
        control_stream_id,
        max_rate_hz,
    )
    @info "Per-consumer streams requested" channel = per_consumer_channel max_rate_hz = max_rate_hz

    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing

    ctx = TensorPoolContext(driver_cfg.endpoints)
    tp_client = connect(ctx)
    try
        app_ref = Ref{AppRateLimitedConsumerAgent}()
        callbacks = ConsumerCallbacks(; on_frame! = AppConsumerOnFrame(app_ref))
        handle = try
            attach(tp_client, consumer_cfg; discover = false, callbacks = callbacks)
        catch err
            report_script_error(err)
            rethrow()
        end
        app_agent = AppRateLimitedConsumerAgent(
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
        composite = CompositeAgent(AeronTensorPool.handle_agent(handle), app_agent)
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

    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "config/driver_integration_example.toml"
    count = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 0
    max_rate_hz = length(ARGS) >= 3 ? UInt16(parse(Int, ARGS[3])) : UInt16(30)

    run_consumer(driver_cfg, count, max_rate_hz)
    return nothing
end

main()
