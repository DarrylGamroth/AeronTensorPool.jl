#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool

mutable struct AppProducerAgent
    driver_cfg_path::String
    producer_cfg_path::String
    max_count::Int
    payload_bytes::Int
    ctx::Union{Aeron.Context, Nothing}
    client::Union{Aeron.Client, Nothing}
    driver_client::Union{DriverClientState, Nothing}
    producer::Union{ProducerState, Nothing}
    control_asm::Union{Aeron.FragmentAssembler, Nothing}
    qos_asm::Union{Aeron.FragmentAssembler, Nothing}
    payload::Vector{UInt8}
    shape::Vector{Int32}
    strides::Vector{Int32}
    sent::Int
    ready::Bool
end

Agent.name(::AppProducerAgent) = "app-producer"

@inline function default_aeron_dir()
    return "/dev/shm/aeron"
end

function Agent.on_start(agent::AppProducerAgent)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(agent.driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)
    control = driver_cfg.endpoints

    env = Dict(ENV)
    if !isempty(control.aeron_dir)
        env["AERON_DIR"] = control.aeron_dir
    else
        env["AERON_DIR"] = default_aeron_dir()
    end
    env["TP_STREAM_ID"] = string(stream_id)
    prod_cfg = load_producer_config(agent.producer_cfg_path; env = env)

    agent.ctx = Aeron.Context()
    AeronTensorPool.set_aeron_dir!(agent.ctx, control.aeron_dir)
    agent.client = Aeron.Client(agent.ctx)

    agent.driver_client = init_driver_client(
        agent.client,
        control.control_channel,
        control.control_stream_id,
        UInt32(7),
        DriverRole.PRODUCER,
    )

    attach_id = send_attach_request!(agent.driver_client; stream_id = stream_id)
    attach_id == 0 && error("attach send failed")

    attach = nothing
    while attach === nothing
        attach = poll_attach!(agent.driver_client, attach_id, UInt64(time_ns()))
        yield()
    end

    agent.producer = init_producer_from_attach(prod_cfg, attach; driver_client = agent.driver_client, client = agent.client)
    agent.control_asm = make_control_assembler(agent.producer)
    agent.qos_asm = make_qos_assembler(agent.producer)

    agent.payload = Vector{UInt8}(undef, agent.payload_bytes)
    agent.shape = Int32[agent.payload_bytes]
    agent.strides = Int32[1]
    agent.sent = 0
    agent.ready = true
    return nothing
end

function Agent.do_work(agent::AppProducerAgent)
    agent.producer === nothing && return 0
    if agent.max_count == 0 || agent.sent < agent.max_count
        fill!(agent.payload, UInt8(agent.sent % 256))
        publish_frame!(agent.producer, agent.payload, agent.shape, agent.strides, Dtype.UINT8, UInt32(0))
        agent.sent += 1
    end
    return producer_do_work!(agent.producer, agent.control_asm; qos_assembler = agent.qos_asm)
end

function Agent.on_close(agent::AppProducerAgent)
    if agent.producer !== nothing
        try
            close(agent.producer.runtime.pub_descriptor)
            close(agent.producer.runtime.control.pub_control)
            close(agent.producer.runtime.pub_qos)
            close(agent.producer.runtime.pub_metadata)
            close(agent.producer.runtime.control.sub_control)
            close(agent.producer.runtime.sub_qos)
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
    println("Usage: julia --project scripts/example_producer.jl [driver_config] [producer_config] [count] [payload_bytes]")
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function default_payload_bytes(cfg::DriverConfig)
    profile = cfg.profiles[first(values(cfg.streams)).profile]
    isempty(profile.payload_pools) && error("driver profile has no payload pools")
    return Int(profile.payload_pools[1].stride_bytes)
end

function run_producer(driver_cfg_path::String, producer_cfg_path::String, count::Int, payload_bytes::Int)
    agent = AppProducerAgent(
        driver_cfg_path,
        producer_cfg_path,
        count,
        payload_bytes,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        UInt8[],
        Int32[],
        Int32[],
        0,
        false,
    )
    runner = AgentRunner(BusySpinIdleStrategy(), agent)
    Agent.start_on_thread(runner)
    while !agent.ready
        yield()
    end
    if count > 0
        while agent.sent < count
            yield()
        end
        close(runner)
    else
        wait(runner)
    end
    @info "Producer done" agent.sent
end

if length(ARGS) > 4
    usage()
    exit(1)
end

driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
producer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
count = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0
payload_bytes = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : default_payload_bytes(load_driver_config(driver_cfg))

run_producer(driver_cfg, producer_cfg, count, payload_bytes)
