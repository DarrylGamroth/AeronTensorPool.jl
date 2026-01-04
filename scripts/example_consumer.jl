#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool

mutable struct AppConsumerAgent
    driver_cfg_path::String
    consumer_cfg_path::String
    max_count::Int
    ctx::Union{Aeron.Context, Nothing}
    client::Union{Aeron.Client, Nothing}
    driver_client::Union{DriverClientState, Nothing}
    consumer::Union{ConsumerState, Nothing}
    desc_asm::Union{Aeron.FragmentAssembler, Nothing}
    ctrl_asm::Union{Aeron.FragmentAssembler, Nothing}
    last_frame::UInt64
    seen::Int
    ready::Bool
end

Agent.name(::AppConsumerAgent) = "app-consumer"

function Agent.on_start(agent::AppConsumerAgent)
    return nothing
end

function Agent.on_start(agent::AppConsumerAgent)
    driver_cfg = load_driver_config(agent.driver_cfg_path)
    stream_id = first_stream_id(driver_cfg)
    control = driver_cfg.endpoints

    env = Dict(ENV)
    env["AERON_DIR"] = control.aeron_dir
    env["TP_STREAM_ID"] = string(stream_id)
    cons_cfg = load_consumer_config(agent.consumer_cfg_path; env = env)

    agent.ctx = Aeron.Context()
    AeronTensorPool.set_aeron_dir!(agent.ctx, control.aeron_dir)
    agent.client = Aeron.Client(agent.ctx)

    agent.driver_client = init_driver_client(
        agent.client,
        control.control_channel,
        control.control_stream_id,
        UInt32(21),
        DriverRole.CONSUMER,
    )

    attach_id = send_attach_request!(agent.driver_client; stream_id = stream_id)
    attach_id == 0 && error("attach send failed")

    attach = nothing
    while attach === nothing
        attach = poll_attach!(agent.driver_client, attach_id, UInt64(time_ns()))
        yield()
    end

    agent.consumer = init_consumer_from_attach(cons_cfg, attach; driver_client = agent.driver_client, client = agent.client)
    agent.desc_asm = make_descriptor_assembler(agent.consumer)
    agent.ctrl_asm = make_control_assembler(agent.consumer)
    agent.last_frame = UInt64(0)
    agent.seen = 0
    agent.ready = true
    return nothing
end

function Agent.do_work(agent::AppConsumerAgent)
    agent.consumer === nothing && return 0
    consumer_do_work!(agent.consumer, agent.desc_asm, agent.ctrl_asm)
    header = agent.consumer.runtime.frame_view.header
    if header.frame_id != 0 && header.frame_id != agent.last_frame
        agent.last_frame = header.frame_id
        expected = UInt8(header.frame_id % UInt64(256))
        payload = payload_view(agent.consumer.runtime.frame_view.payload)
        ok = check_pattern(payload, expected)
        ok || error("payload mismatch at frame $(header.frame_id)")
        agent.seen += 1
        println("frame=$(header.frame_id) ok")
    end
    return 1
end

function Agent.on_close(agent::AppConsumerAgent)
    if agent.consumer !== nothing
        try
            close(agent.consumer.runtime.control.pub_control)
            close(agent.consumer.runtime.pub_qos)
            close(agent.consumer.runtime.sub_descriptor)
            close(agent.consumer.runtime.control.sub_control)
            close(agent.consumer.runtime.sub_qos)
            agent.consumer.runtime.sub_progress === nothing || close(agent.consumer.runtime.sub_progress)
        catch
        end
    end
    if agent.driver_client !== nothing
        try
            close(agent.driver_client.pub)
            close(agent.driver_client.sub)
        catch
        end
    end
    if agent.client !== nothing
        try
            close(agent.client)
        catch
        end
    end
    if agent.ctx !== nothing
        try
            close(agent.ctx)
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
    for b in payload
        b == expected || return false
    end
    return true
end

function run_consumer(driver_cfg_path::String, consumer_cfg_path::String, count::Int)
    agent = AppConsumerAgent(
        driver_cfg_path,
        consumer_cfg_path,
        count,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        UInt64(0),
        0,
        false,
    )
    runner = AgentRunner(BusySpinIdleStrategy(), agent)
    Agent.start_on_thread(runner)
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
    @info "Consumer done" agent.seen
end

if length(ARGS) > 3
    usage()
    exit(1)
end

driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
consumer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
count = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0

run_consumer(driver_cfg, consumer_cfg, count)
