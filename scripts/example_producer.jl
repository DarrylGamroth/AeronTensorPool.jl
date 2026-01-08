#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

mutable struct AppProducerAgent
    handle::ProducerHandle
    meta_version::UInt32
    max_count::Int
    payload::Vector{UInt8}
    shape::Vector{Int32}
    strides::Vector{Int32}
    sent::Int
    last_send_ns::UInt64
    send_interval_ns::UInt64
    ready::Bool
end

Agent.name(::AppProducerAgent) = "app-producer"

struct AppProducerOnQos end

(hook::AppProducerOnQos)(::ProducerState, snapshot::QosProducerSnapshot) =
    @info "Producer QoS snapshot" current_seq = snapshot.current_seq

function Agent.on_start(agent::AppProducerAgent)
    agent.ready = true
    return nothing
end

function Agent.do_work(agent::AppProducerAgent)
    now_ns = UInt64(time_ns())
    if now_ns - agent.last_send_ns < agent.send_interval_ns
        return 0
    end
    if agent.max_count == 0 || agent.sent < agent.max_count
        fill!(agent.payload, UInt8(agent.sent % 256))
        sent = Producer.offer_frame!(
            agent.handle,
            agent.payload,
            agent.shape,
            agent.strides,
            Dtype.UINT8,
            agent.meta_version,
        )
        if sent
            agent.sent += 1
            agent.last_send_ns = now_ns
            @info "Producer published frame" seq = AeronTensorPool.handle_state(agent.handle).seq - 1
        else
            connected = Aeron.is_connected(AeronTensorPool.handle_state(agent.handle).runtime.pub_descriptor)
            @info "Producer publish skipped" descriptor_connected = connected
        end
    end
    return 0
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

    ctx = TensorPoolContext(driver_cfg.endpoints)
    tp_client = connect(ctx)
    try
        meta_version = UInt32(1)
        qos_monitor = QosMonitor(producer_cfg; client = tp_client.aeron_client)
        metadata_attrs = MetadataAttribute[
            MetadataAttribute("pattern" => ("text/plain", "counter")),
            MetadataAttribute("payload_bytes" => ("text/plain", effective_payload_bytes)),
        ]
        noop_hello!(_, _) = nothing
        noop_qos!(_, _) = nothing
        noop_frame!(_, _, _) = nothing
        callbacks = ProducerCallbacks(; on_qos_producer! = AppProducerOnQos())
        handle = attach_producer(
            tp_client,
            producer_cfg;
            discover = false,
            callbacks = callbacks,
            qos_monitor = qos_monitor,
        )
        set_metadata!(
            handle,
            meta_version,
            "example-producer";
            summary = "metadata example",
            attributes = metadata_attrs,
        )
        payload = Vector{UInt8}(undef, effective_payload_bytes)
        shape = Int32[effective_payload_bytes]
        strides = Int32[1]
        app_agent = AppProducerAgent(
            handle,
            meta_version,
            count,
            payload,
            shape,
            strides,
            0,
            UInt64(0),
            UInt64(10_000_000),
            false,
        )
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
                while app_agent.sent < count
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
        @info "Producer done" app_agent.sent
        close(handle)
    finally
        close(tp_client)
    end
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
