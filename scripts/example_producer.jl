#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool

mutable struct AppProducerAgent
    producer::ProducerState
    control_asm::Aeron.FragmentAssembler
    qos_asm::Aeron.FragmentAssembler
    payload::Vector{UInt8}
    shape::Vector{Int32}
    strides::Vector{Int32}
    sent::Int
    max_count::Int
end

Agent.name(::AppProducerAgent) = "app-producer"

function Agent.on_start(agent::AppProducerAgent)
    return nothing
end

function Agent.do_work(agent::AppProducerAgent)
    if agent.max_count == 0 || agent.sent < agent.max_count
        fill!(agent.payload, UInt8(agent.sent % 256))
        publish_frame!(agent.producer, agent.payload, agent.shape, agent.strides, Dtype.UINT8, UInt32(0))
        agent.sent += 1
    end
    return producer_do_work!(agent.producer, agent.control_asm; qos_assembler = agent.qos_asm)
end

function Agent.on_close(agent::AppProducerAgent)
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
    driver_cfg = load_driver_config(driver_cfg_path)
    stream_id = first_stream_id(driver_cfg)
    control = driver_cfg.endpoints

    env = Dict(ENV)
    env["AERON_DIR"] = control.aeron_dir
    env["TP_STREAM_ID"] = string(stream_id)
    prod_cfg = load_producer_config(producer_cfg_path; env = env)

    Aeron.Context() do ctx
        AeronTensorPool.set_aeron_dir!(ctx, control.aeron_dir)
        Aeron.Client(ctx) do client
            driver_client = init_driver_client(
                client,
                control.control_channel,
                control.control_stream_id,
                UInt32(7),
                DriverRole.PRODUCER,
            )

            attach_id = send_attach_request!(driver_client; stream_id = stream_id)
            attach_id == 0 && error("attach send failed")

            attach = nothing
            while attach === nothing
                attach = poll_attach!(driver_client, attach_id, UInt64(time_ns()))
                yield()
            end

            producer = init_producer_from_attach(prod_cfg, attach; driver_client = driver_client, client = client)
            ctrl_asm = make_control_assembler(producer)
            qos_asm = make_qos_assembler(producer)
            payload = Vector{UInt8}(undef, payload_bytes)
            shape = Int32[payload_bytes]
            strides = Int32[1]
            agent = AppProducerAgent(producer, ctrl_asm, qos_asm, payload, shape, strides, 0, count)
            runner = AgentRunner(BusySpinIdleStrategy(), agent)

            Agent.start_on_thread(runner)
            if count > 0
                while agent.sent < count
                    yield()
                end
            else
                wait(runner)
            end
            close(runner)
            @info "Producer done" agent.sent
        end
    end
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
