#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

mutable struct AppConsumerAgent
    driver_cfg::DriverConfig
    consumer_cfg::ConsumerSettings
    stream_id::UInt32
    max_count::Int
    client::Aeron.Client
    driver_client::Union{DriverClientState, Nothing}
    consumer_agent::Union{ConsumerAgent, Nothing}
    last_frame::UInt64
    seen::Int
    last_frames_ok::UInt64
    last_drops_late::UInt64
    last_drops_header_invalid::UInt64
    last_log_ns::UInt64
    ready::Bool
    validate_limit::Int
    validated::Int
end

Agent.name(::AppConsumerAgent) = "app-consumer"

struct AppConsumerOnFrame
    app::AppConsumerAgent
end

function (hook::AppConsumerOnFrame)(state::ConsumerState, frame::ConsumerFrameView)
    frame_id = frame.header.frame_id
    expected = UInt8(frame_id % UInt64(256))
    payload = payload_view(frame.payload)
    if hook.app.validated < hook.app.validate_limit
        hook.app.validated += 1
        if !check_pattern(payload, expected)
            actual = isempty(payload) ? UInt8(0) : @inbounds payload[1]
            @warn "payload mismatch" frame_id expected actual
        end
    end
    hook.app.seen += 1
    hook.app.last_frame = frame_id
    if hook.app.seen % 100 == 0
        println("frame=$(frame_id) ok")
    end
    return nothing
end

function Agent.on_start(agent::AppConsumerAgent)
    control = agent.driver_cfg.endpoints
    retry_timeout_ns = UInt64(5_000_000_000)

    agent.driver_client = init_driver_client(
        agent.client,
        control.control_channel,
        control.control_stream_id,
        UInt32(21),
        DriverRole.CONSUMER;
        attach_purge_interval_ns = retry_timeout_ns * 3,
    )
    @info "Consumer control client ready" control_channel = control.control_channel control_stream_id =
        control.control_stream_id
    wait_for_control_connection(agent.driver_client, UInt64(5_000_000_000))

    attach_id = Int64(0)
    attach = nothing
    last_send_ns = UInt64(0)
    while attach === nothing
        now_ns = UInt64(time_ns())
        if attach_id == 0
            attach_id = send_attach_request!(agent.driver_client; stream_id = agent.stream_id)
            attach_id != 0 && @info("Consumer attach sent", correlation_id = attach_id)
            attach_id != 0 && (last_send_ns = now_ns)
        elseif now_ns - last_send_ns > retry_timeout_ns
            @info "Consumer attach retry timeout" correlation_id = attach_id
            attach_id = Int64(0)
        end
        attach_id == 0 && (yield(); continue)
        attach = poll_attach!(agent.driver_client, attach_id, now_ns)
        if attach !== nothing && attach.code != DriverResponseCode.OK
            @warn "Consumer attach rejected" code = attach.code message = attach.error_message
            attach = nothing
            attach_id = Int64(0)
        end
        yield()
    end
    @info "Consumer attach received" code = attach.code lease_id = attach.lease_id stream_id = attach.stream_id

    consumer_state =
        init_consumer_from_attach(agent.consumer_cfg, attach; driver_client = agent.driver_client, client = agent.client)
    hooks = ConsumerHooks(AppConsumerOnFrame(agent))
    desc_asm = make_descriptor_assembler(consumer_state; hooks = hooks)
    ctrl_asm = make_control_assembler(consumer_state)
    counters =
        ConsumerCounters(consumer_state.runtime.control.client, Int(consumer_state.config.consumer_id), "Consumer")
    agent.consumer_agent = ConsumerAgent(consumer_state, desc_asm, ctrl_asm, counters)
    @info "Consumer data plane" aeron_uri = consumer_state.config.aeron_uri descriptor_stream_id =
        consumer_state.config.descriptor_stream_id
    agent.last_frame = UInt64(0)
    agent.seen = 0
    agent.last_frames_ok = UInt64(0)
    agent.last_drops_late = UInt64(0)
    agent.last_drops_header_invalid = UInt64(0)
    agent.last_log_ns = UInt64(0)
    agent.ready = true
    @info "Consumer ready"
    return nothing
end

function Agent.do_work(agent::AppConsumerAgent)
    agent.consumer_agent === nothing && return 0
    work_count = Agent.do_work(agent.consumer_agent)
    metrics = agent.consumer_agent.state.metrics
    if metrics.frames_ok != agent.last_frames_ok
        header = agent.consumer_agent.state.runtime.frame_view.header
        @info "Consumer frames_ok updated" frames_ok = metrics.frames_ok header_frame_id = header.frame_id
        agent.last_frames_ok = metrics.frames_ok
    end
    now_ns = UInt64(time_ns())
    if now_ns - agent.last_log_ns > 1_000_000_000
        @info "Consumer frame state" last_frame = agent.last_frame seen = agent.seen
        desc_connected = Aeron.is_connected(agent.consumer_agent.state.runtime.sub_descriptor)
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
    return work_count
end

function Agent.on_close(agent::AppConsumerAgent)
    agent.consumer_agent === nothing || Agent.on_close(agent.consumer_agent)
    if agent.driver_client !== nothing
        try
            close(agent.driver_client.pub)
            close(agent.driver_client.sub)
        catch
        end
    end
    return nothing
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
    env["TP_STREAM_ID"] = string(stream_id)
    consumer_cfg = load_consumer_config(consumer_cfg_path; env = env)

    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing

    Aeron.Context() do context
        AeronTensorPool.set_aeron_dir!(context, driver_cfg.endpoints.aeron_dir)
        Aeron.Client(context) do client
            agent = AppConsumerAgent(
                driver_cfg,
                consumer_cfg,
                stream_id,
                count,
                client,
                nothing,
                nothing,
                UInt64(0),
                0,
                UInt64(0),
                UInt64(0),
                UInt64(0),
                UInt64(0),
                false,
                10,
                0,
            )
            runner = AgentRunner(BackoffIdleStrategy(), agent)
            if isnothing(core_id)
                Agent.start_on_thread(runner)
            else
                Agent.start_on_thread(runner, core_id)
            end
            try
                while !agent.ready
                    yield()
                end
                if count > 0
                    while agent.seen < count
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
            @info "Consumer done" agent.seen
        end
    end
    return nothing
end

function wait_for_control_connection(state::DriverClientState, timeout_ns::UInt64)
    deadline = UInt64(time_ns()) + timeout_ns
    while UInt64(time_ns()) < deadline
        pub_ok = Aeron.is_connected(state.pub)
        sub_ok = Aeron.is_connected(state.sub)
        if pub_ok && sub_ok
            return nothing
        end
        @info "Consumer waiting for control connection" pub_connected = pub_ok sub_connected = sub_ok
        yield()
    end
    error("driver control channel not connected")
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
