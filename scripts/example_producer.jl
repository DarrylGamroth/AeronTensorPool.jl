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
    pattern::Symbol
    sent::Int
    last_send_ns::UInt64
    send_interval_ns::UInt64
    last_connect_log_ns::UInt64
    ready::Bool
    log_every::Int
end

Agent.name(::AppProducerAgent) = "app-producer"

struct AppProducerOnQos end

(hook::AppProducerOnQos)(::ProducerState, snapshot::QosProducerSnapshot) =
    @info "Producer QoS snapshot" current_seq = snapshot.current_seq

function Agent.on_start(agent::AppProducerAgent)
    agent.ready = true
    @info "AppProducerAgent started"
    return nothing
end

function Agent.do_work(agent::AppProducerAgent)
    now_ns = UInt64(time_ns())
    state = AeronTensorPool.handle_state(agent.handle)
    if !producer_connected(agent.handle)
        if now_ns - agent.last_connect_log_ns > 1_000_000_000
            conn = AeronTensorPool.producer_connections(agent.handle)
            @info "Waiting for producer publications to connect" descriptor_connected = conn.descriptor_connected control_connected =
                conn.control_connected qos_connected = conn.qos_connected
            agent.last_connect_log_ns = now_ns
        end
        return 0
    end
    if now_ns - agent.last_send_ns < agent.send_interval_ns
        return 0
    end
    if agent.max_count == 0 || agent.sent < agent.max_count
        seq = AeronTensorPool.handle_state(agent.handle).seq
        if agent.pattern === :interop
            fill_interop_pattern!(agent.payload, seq)
        else
            fill!(agent.payload, UInt8(seq % UInt64(256)))
        end
        sent = AeronTensorPool.offer_frame!(
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
            if agent.log_every > 0 && (agent.sent % agent.log_every == 0)
                @info "Producer published frame" seq = state.seq - 1
            end
        elseif agent.log_every > 0
            @info "Producer publish skipped" descriptor_connected = true
        end
    end
    return 0
end

function usage()
    println("Usage: julia --project scripts/example_producer.jl [driver_config] [count] [payload_bytes]")
    println("Env: TP_EXAMPLE_VERBOSE=1, TP_EXAMPLE_LOG_EVERY=100, TP_PATTERN=interop")
end

function fill_interop_pattern!(payload::AbstractVector{UInt8}, seq::UInt64)
    len = length(payload)
    if len > 0
        for i in 0:min(len - 1, 7)
            @inbounds payload[i + 1] = UInt8((seq >> (8 * i)) & 0xff)
        end
        inv = ~seq
        for i in 0:min(len - 9, 7)
            @inbounds payload[9 + i] = UInt8((inv >> (8 * i)) & 0xff)
        end
        for i in 16:(len - 1)
            @inbounds payload[i + 1] = UInt8((seq + UInt64(i)) & 0xff)
        end
    end
    return nothing
end

function agent_error_handler(agent, err)
    @error "Agent error" agent = Agent.name(agent) exception = (err, catch_backtrace())
    return nothing
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

function override_producer_config_for_driver(config::ProducerConfig, driver_cfg::DriverConfig)
    return ProducerConfig(
        config.aeron_dir,
        driver_cfg.endpoints.control_channel,
        config.descriptor_stream_id,
        driver_cfg.endpoints.control_stream_id,
        driver_cfg.endpoints.qos_stream_id,
        config.metadata_stream_id,
        config.stream_id,
        config.producer_id,
        config.layout_version,
        config.nslots,
        config.shm_base_dir,
        config.shm_namespace,
        config.producer_instance_id,
        config.header_uri,
        config.payload_pools,
        config.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        config.mlock_shm,
    )
end

function run_producer(driver_cfg_path::String, count::Int, payload_bytes::Int)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)
    stream_id = first_stream_id(driver_cfg)

    env = Dict(ENV)
    env["TP_STREAM_ID"] = string(stream_id)
    producer_id = parse(UInt32, get(ENV, "TP_PRODUCER_ID", "1"))
    producer_cfg = default_producer_config(; stream_id = stream_id, producer_id = producer_id)
    producer_cfg = override_producer_config_for_driver(producer_cfg, driver_cfg)

    effective_payload_bytes = payload_bytes == 0 ? default_payload_bytes(driver_cfg) : payload_bytes
    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing
    verbose = get(ENV, "TP_EXAMPLE_VERBOSE", "0") == "1"
    log_every = parse(Int, get(ENV, "TP_EXAMPLE_LOG_EVERY", verbose ? "100" : "0"))
    pattern = get(ENV, "TP_PATTERN", "") == "interop" ? :interop : :simple

    aeron_dir = get(ENV, "AERON_DIR", driver_cfg.endpoints.aeron_dir)
    ctx = TensorPoolContext(driver_cfg.endpoints; aeron_dir = aeron_dir)
    tp_client = connect(ctx)
    try
        qos_monitor = QosMonitor(producer_cfg; client = tp_client.aeron_client)
        metadata_attrs = MetadataAttribute[
            MetadataAttribute("pattern" => ("text/plain", "counter")),
            MetadataAttribute("payload_bytes" => ("text/plain", effective_payload_bytes)),
        ]
        noop_hello!(_, _) = nothing
        noop_qos!(_, _) = nothing
        noop_frame!(_, _, _) = nothing
        callbacks = ProducerCallbacks(; on_qos_producer! = AppProducerOnQos())
        handle = attach(
            tp_client,
            producer_cfg;
            discover = false,
            callbacks = callbacks,
            qos_monitor = qos_monitor,
        )
        state = AeronTensorPool.handle_state(handle)
        @info "Producer driver lease" lease_id = handle.driver_client.lease_id stream_id =
            handle.driver_client.stream_id
        @info "Producer attach complete" stream_id = state.config.stream_id control_stream_id = state.config.control_stream_id descriptor_stream_id =
            state.config.descriptor_stream_id
        conn = AeronTensorPool.producer_connections(handle)
        @info "Producer Aeron connections" descriptor_connected = conn.descriptor_connected control_connected =
            conn.control_connected qos_connected = conn.qos_connected
        announce_data_source!(
            handle,
            "example-producer";
            summary = "metadata example",
        )
        set_metadata_attributes!(handle; attributes = metadata_attrs)
        meta_version = metadata_version(handle)
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
            pattern,
            0,
            UInt64(0),
            UInt64(10_000_000),
            UInt64(0),
            false,
            log_every,
        )
        composite = CompositeAgent(AeronTensorPool.handle_agent(handle), app_agent)
        runner = AgentRunner(BackoffIdleStrategy(), composite; error_handler = agent_error_handler)
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

    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "config/driver_integration_example.toml"
    count = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 0
    payload_bytes = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0

    run_producer(driver_cfg, count, payload_bytes)
    return nothing
end

main()
