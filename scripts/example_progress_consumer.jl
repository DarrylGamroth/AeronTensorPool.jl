#!/usr/bin/env julia
using Agent
using AeronTensorPool

mutable struct AppProgressConsumer
    handle::ConsumerHandle
    last_frame_id::UInt64
    last_bytes_filled::UInt64
    ready::Bool
end

Agent.name(::AppProgressConsumer) = "app-progress-consumer"

function Agent.on_start(agent::AppProgressConsumer)
    agent.ready = true
    return nothing
end

function Agent.do_work(agent::AppProgressConsumer)
    state = AeronTensorPool.handle_state(agent.handle)
    msg = state.runtime.progress_decoder
    frame_id = FrameProgress.frameId(msg)
    bytes = FrameProgress.payloadBytesFilled(msg)
    if frame_id != 0 && (frame_id != agent.last_frame_id || bytes != agent.last_bytes_filled)
        println("progress: frame=$(frame_id) bytes=$(bytes) state=$(FrameProgress.state(msg))")
        agent.last_frame_id = frame_id
        agent.last_bytes_filled = bytes
    end
    return 0
end

function usage()
    println("Usage: julia --project scripts/example_progress_consumer.jl [driver_config] [consumer_config]")
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function run_progress_consumer(driver_cfg_path::String, consumer_cfg_path::String)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)

    env = Dict(ENV)
    env["TP_STREAM_ID"] = string(stream_id)
    consumer_cfg = load_consumer_config(consumer_cfg_path; env = env)
    consumer_cfg.aeron_uri = driver_cfg.endpoints.control_channel
    consumer_cfg.control_stream_id = driver_cfg.endpoints.control_stream_id
    consumer_cfg.qos_stream_id = driver_cfg.endpoints.qos_stream_id
    consumer_cfg.supports_progress = true

    ctx = TensorPoolContext(driver_cfg.endpoints)
    client = connect(ctx)
    try
        handle = attach_consumer(client, consumer_cfg; discover = false)
        app = AppProgressConsumer(handle, UInt64(0), UInt64(0), false)
        composite = CompositeAgent(AeronTensorPool.handle_agent(handle), app)
        runner = AgentRunner(BackoffIdleStrategy(), composite)
        Agent.start_on_thread(runner)
        while !app.ready
            yield()
        end
        wait(runner)
    finally
        close(client)
    end
    return nothing
end

function main()
    Base.exit_on_sigint(false)
    if length(ARGS) > 2
        usage()
        exit(1)
    end
    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "config/driver_integration_example.toml"
    consumer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
    run_progress_consumer(driver_cfg, consumer_cfg)
    return nothing
end

main()
