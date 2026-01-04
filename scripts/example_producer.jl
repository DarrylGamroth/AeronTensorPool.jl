#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

mutable struct AppProducerAgent
    driver_cfg::DriverConfig
    producer_cfg::ProducerConfig
    stream_id::UInt32
    max_count::Int
    payload_bytes::Int
    client::Aeron.Client
    driver_client::Union{DriverClientState, Nothing}
    producer_agent::Union{ProducerAgent, Nothing}
    payload::Vector{UInt8}
    shape::Vector{Int32}
    strides::Vector{Int32}
    sent::Int
    ready::Bool
end

Agent.name(::AppProducerAgent) = "app-producer"

function Agent.on_start(agent::AppProducerAgent)
    control = agent.driver_cfg.endpoints

    agent.driver_client = init_driver_client(
        agent.client,
        control.control_channel,
        control.control_stream_id,
        UInt32(7),
        DriverRole.PRODUCER,
    )
    @info "Producer control client ready" control_channel = control.control_channel control_stream_id =
        control.control_stream_id
    wait_for_control_connection(agent.driver_client, UInt64(5_000_000_000))

    attach_id = Int64(0)
    attach = nothing
    last_send_ns = UInt64(0)
    while attach === nothing
        now_ns = UInt64(time_ns())
        if attach_id == 0 || now_ns - last_send_ns > 1_000_000_000
            attach_id = send_attach_request!(agent.driver_client; stream_id = agent.stream_id)
            attach_id != 0 && @info("Producer attach sent", correlation_id = attach_id)
            attach_id != 0 && (last_send_ns = now_ns)
        end
        attach_id == 0 && (yield(); continue)
        attach = poll_attach!(agent.driver_client, attach_id, now_ns)
        yield()
    end
    @info "Producer attach received" code = attach.code lease_id = attach.lease_id stream_id = attach.stream_id

    producer_state =
        init_producer_from_attach(agent.producer_cfg, attach; driver_client = agent.driver_client, client = agent.client)
    control_asm = make_control_assembler(producer_state)
    qos_asm = make_qos_assembler(producer_state)
    counters =
        ProducerCounters(producer_state.runtime.control.client, Int(producer_state.config.producer_id), "Producer")
    agent.producer_agent = ProducerAgent(producer_state, control_asm, qos_asm, counters)
    @info "Producer data plane" aeron_uri = producer_state.config.aeron_uri descriptor_stream_id =
        producer_state.config.descriptor_stream_id

    agent.payload = Vector{UInt8}(undef, agent.payload_bytes)
    agent.shape = Int32[agent.payload_bytes]
    agent.strides = Int32[1]
    agent.sent = 0
    wait_for_descriptor_connection(agent.producer_agent)
    agent.ready = true
    @info "Producer ready" payload_bytes = agent.payload_bytes
    return nothing
end

function Agent.do_work(agent::AppProducerAgent)
    agent.producer_agent === nothing && return 0
    if agent.max_count == 0 || agent.sent < agent.max_count
        fill!(agent.payload, UInt8(agent.sent % 256))
        sent = offer_frame!(
            agent.producer_agent.state,
            agent.payload,
            agent.shape,
            agent.strides,
            Dtype.UINT8,
            UInt32(0),
        )
        if sent
            agent.sent += 1
            @info "Producer published frame" seq = agent.producer_agent.state.seq - 1
        else
            connected = Aeron.is_connected(agent.producer_agent.state.runtime.pub_descriptor)
            @info "Producer publish skipped" descriptor_connected = connected
        end
    end
    return Agent.do_work(agent.producer_agent)
end

function Agent.on_close(agent::AppProducerAgent)
    agent.producer_agent === nothing || Agent.on_close(agent.producer_agent)
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
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)

    env = Dict(ENV)
    env["TP_STREAM_ID"] = string(stream_id)
    producer_cfg = load_producer_config(producer_cfg_path; env = env)

    effective_payload_bytes = payload_bytes == 0 ? default_payload_bytes(driver_cfg) : payload_bytes
    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing

    Aeron.Context() do context
        AeronTensorPool.set_aeron_dir!(context, driver_cfg.endpoints.aeron_dir)
        Aeron.Client(context) do client
            agent = AppProducerAgent(
                driver_cfg,
                producer_cfg,
                stream_id,
                count,
                effective_payload_bytes,
                client,
                nothing,
                nothing,
                UInt8[],
                Int32[],
                Int32[],
                0,
                false,
            )
            runner = AgentRunner(BusySpinIdleStrategy(), agent)
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
                    while agent.sent < count
                        yield()
                    end
                    close(runner)
                else
                    wait(runner)
                end
            catch e
                if e isa InterruptException
                    @info "Producer shutting down..."
                else
                    @error "Producer error" exception = (e, catch_backtrace())
                end
            finally
                close(runner)
            end
            @info "Producer done" agent.sent
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
        @info "Producer waiting for control connection" pub_connected = pub_ok sub_connected = sub_ok
        yield()
    end
    error("driver control channel not connected")
end

function wait_for_descriptor_connection(agent::ProducerAgent, timeout_ns::UInt64 = UInt64(5_000_000_000))
    deadline = UInt64(time_ns()) + timeout_ns
    while UInt64(time_ns()) < deadline
        if Aeron.is_connected(agent.state.runtime.pub_descriptor)
            return nothing
        end
        @info "Producer waiting for descriptor subscriber"
        yield()
    end
    @warn "Producer descriptor not connected before timeout"
    return nothing
end

function main()
    Base.exit_on_sigint(false)
    if length(ARGS) > 4
        usage()
        exit(1)
    end

    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
    producer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
    count = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0
    payload_bytes = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 0

    run_producer(driver_cfg, producer_cfg, count, payload_bytes)
    return nothing
end

main()
