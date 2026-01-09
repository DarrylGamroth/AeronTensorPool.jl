#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

mutable struct AppConsumerAgent
    handle::ConsumerHandle
    callbacks::ConsumerCallbacks
    qos_monitor::QosMonitor
    metadata_cache::MetadataCache
    stream_id::UInt32
    consumer_id::UInt32
    producer_id::UInt32
    max_count::Int
    last_frame::UInt64
    seen::Int
    last_frames_ok::UInt64
    last_drops_late::UInt64
    last_drops_header_invalid::UInt64
    last_log_ns::UInt64
    last_qos_log_ns::UInt64
    last_meta_version::UInt32
    validate_limit::Int
    validated::Int
    pattern::Symbol
    fail_on_mismatch::Bool
    ready_file::String
    ready::Bool
    log_every::Int
    verbose::Bool
end

Agent.name(::AppConsumerAgent) = "app-consumer"

struct AppConsumerOnFrame
    app_ref::Base.RefValue{AppConsumerAgent}
end

function (hook::AppConsumerOnFrame)(state::ConsumerState, frame::ConsumerFrameView)
    app = hook.app_ref[]
    seq = seqlock_sequence(frame.header.seq_commit)
    payload = Consumer.payload_view(frame.payload)
    if app.validated < app.validate_limit
        app.validated += 1
        if app.pattern === :interop
            if !check_interop_pattern(payload, seq)
                actual = isempty(payload) ? UInt8(0) : @inbounds payload[1]
                app.fail_on_mismatch && error("payload mismatch seq=$(seq) expected=interop actual=$(actual)")
                @warn "payload mismatch" seq expected = "interop" actual
            end
        else
            expected = UInt8(seq % UInt64(256))
            if !check_pattern(payload, expected)
                actual = isempty(payload) ? UInt8(0) : @inbounds payload[1]
                app.fail_on_mismatch && error("payload mismatch seq=$(seq) expected=$(expected) actual=$(actual)")
                @warn "payload mismatch" seq expected actual
            end
        end
    end
    app.seen += 1
    app.last_frame = seq
    if app.log_every > 0 && (app.seen % app.log_every == 0)
        println("frame=$(seq) ok")
    end
    return nothing
end

function Agent.on_start(agent::AppConsumerAgent)
    agent.ready = true
    if !isempty(agent.ready_file)
        open(agent.ready_file, "w") do io
            write(io, "ready\n")
        end
    end
    @info "AppConsumerAgent started"
    return nothing
end

function Agent.do_work(agent::AppConsumerAgent)
    poll_qos!(agent.qos_monitor)
    poll_metadata!(agent.metadata_cache)
    metrics = AeronTensorPool.handle_state(agent.handle).metrics
    if agent.verbose && metrics.frames_ok != agent.last_frames_ok
        header = AeronTensorPool.handle_state(agent.handle).runtime.frame_view.header
        @info "Consumer frames_ok updated" frames_ok = metrics.frames_ok header_seq_commit = header.seq_commit
        agent.last_frames_ok = metrics.frames_ok
    end
    now_ns = UInt64(time_ns())
    if agent.verbose && now_ns - agent.last_log_ns > 1_000_000_000
        @info "Consumer frame state" last_frame = agent.last_frame seen = agent.seen
        desc_connected = Aeron.is_connected(AeronTensorPool.handle_state(agent.handle).runtime.sub_descriptor)
        @info "Consumer descriptor connected" connected = desc_connected
        if metrics.drops_late != agent.last_drops_late ||
           metrics.drops_header_invalid != agent.last_drops_header_invalid
            @info "Consumer metrics" frames_ok = metrics.frames_ok drops_late = metrics.drops_late drops_odd =
                metrics.drops_odd drops_changed = metrics.drops_changed drops_frame_id_mismatch =
                metrics.drops_frame_id_mismatch drops_header_invalid = metrics.drops_header_invalid
                drops_payload_invalid = metrics.drops_payload_invalid
            agent.last_drops_late = metrics.drops_late
            agent.last_drops_header_invalid = metrics.drops_header_invalid
        end
        agent.last_log_ns = now_ns
    end
    if now_ns - agent.last_qos_log_ns > 1_000_000_000
        snapshot = consumer_qos(agent.qos_monitor, agent.consumer_id)
        if snapshot !== nothing
            if agent.verbose
                @info "Consumer QoS snapshot" last_seq_seen = snapshot.last_seq_seen drops_gap = snapshot.drops_gap
            end
            agent.callbacks.on_qos_consumer!(AeronTensorPool.handle_state(agent.handle), snapshot)
        end
        producer_snapshot = producer_qos(agent.qos_monitor, agent.producer_id)
        if producer_snapshot !== nothing
            if agent.verbose
                @info "Producer QoS snapshot" current_seq = producer_snapshot.current_seq
            end
            agent.callbacks.on_qos_producer!(AeronTensorPool.handle_state(agent.handle), producer_snapshot)
        end
        agent.last_qos_log_ns = now_ns
    end
    entry = metadata_entry(agent.metadata_cache, agent.stream_id)
    if entry !== nothing && entry.meta_version != agent.last_meta_version
        if agent.verbose
            @info "Metadata update" meta_version = entry.meta_version name = entry.name
        end
        agent.producer_id = entry.producer_id
        agent.callbacks.on_metadata!(AeronTensorPool.handle_state(agent.handle), entry)
        agent.last_meta_version = entry.meta_version
    end
    return 0
end

function usage()
    println("Usage: julia --project scripts/example_consumer.jl [driver_config] [consumer_config] [count]")
    println("Env: TP_EXAMPLE_VERBOSE=1, TP_EXAMPLE_LOG_EVERY=100, TP_PATTERN=interop, TP_FAIL_ON_MISMATCH=1")
end

function agent_error_handler(agent, err)
    @error "Agent error" agent = Agent.name(agent) exception = (err, catch_backtrace())
    return nothing
end

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function check_pattern(payload::AbstractVector{UInt8}, expected::UInt8)
    isempty(payload) && return false
    @inbounds return payload[1] == expected
end

function check_interop_pattern(payload::AbstractVector{UInt8}, seq::UInt64)
    len = length(payload)
    len == 0 && return false
    for i in 0:min(len - 1, 7)
        @inbounds expected = UInt8((seq >> (8 * i)) & 0xff)
        @inbounds payload[i + 1] == expected || return false
    end
    inv = ~seq
    for i in 0:min(len - 9, 7)
        @inbounds expected = UInt8((inv >> (8 * i)) & 0xff)
        @inbounds payload[9 + i] == expected || return false
    end
    for i in 16:(len - 1)
        @inbounds expected = UInt8((seq + UInt64(i)) & 0xff)
        @inbounds payload[i + 1] == expected || return false
    end
    return true
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
    consumer_cfg.aeron_uri = driver_cfg.endpoints.control_channel
    consumer_cfg.control_stream_id = driver_cfg.endpoints.control_stream_id
    consumer_cfg.qos_stream_id = driver_cfg.endpoints.qos_stream_id

    discovery_channel = get(ENV, "TP_DISCOVERY_CHANNEL", "")
    discovery_stream_id = parse(Int32, get(ENV, "TP_DISCOVERY_STREAM_ID", "0"))
    metadata_channel = get(ENV, "TP_METADATA_CHANNEL", consumer_cfg.aeron_uri)
    metadata_stream_id = parse(Int32, get(ENV, "TP_METADATA_STREAM_ID", "1300"))

    core_id = haskey(ENV, "AGENT_TASK_CORE") ? parse(Int, ENV["AGENT_TASK_CORE"]) : nothing
    verbose = get(ENV, "TP_EXAMPLE_VERBOSE", "0") == "1"
    log_every = parse(Int, get(ENV, "TP_EXAMPLE_LOG_EVERY", verbose ? "100" : "0"))
    pattern = get(ENV, "TP_PATTERN", "") == "interop" ? :interop : :simple
    fail_on_mismatch = get(ENV, "TP_FAIL_ON_MISMATCH", "0") == "1"
    ready_file = get(ENV, "TP_READY_FILE", "")

    aeron_dir = get(ENV, "AERON_DIR", driver_cfg.endpoints.aeron_dir)
    ctx = TensorPoolContext(
        driver_cfg.endpoints;
        aeron_dir = aeron_dir,
        discovery_channel = discovery_channel,
        discovery_stream_id = discovery_stream_id,
    )

    tp_client = connect(ctx)
    try
        app_ref = Ref{AppConsumerAgent}()
        callbacks = ConsumerCallbacks(; on_frame! = AppConsumerOnFrame(app_ref))
        handle = attach_consumer(tp_client, consumer_cfg; discover = !isempty(discovery_channel), callbacks = callbacks)
        state = AeronTensorPool.handle_state(handle)
        @info "Consumer driver lease" lease_id = handle.driver_client.lease_id stream_id =
            handle.driver_client.stream_id
        @info "Consumer attach complete" stream_id = state.config.stream_id control_stream_id = state.config.control_stream_id descriptor_stream_id =
            state.config.descriptor_stream_id
        @info "Consumer Aeron connections" descriptor_connected = Aeron.is_connected(state.runtime.sub_descriptor) control_connected =
            Aeron.is_connected(state.runtime.control.sub_control) qos_connected = Aeron.is_connected(state.runtime.sub_qos)
        qos_monitor = QosMonitor(consumer_cfg; client = tp_client.aeron_client)
        metadata_cache = MetadataCache(metadata_channel, metadata_stream_id; client = tp_client.aeron_client)
        app_agent = AppConsumerAgent(
            handle,
            callbacks,
            qos_monitor,
            metadata_cache,
            consumer_cfg.stream_id,
            consumer_cfg.consumer_id,
            UInt32(0),
            count,
            UInt64(0),
            0,
            UInt64(0),
            UInt64(0),
            UInt64(0),
            UInt64(0),
            UInt64(0),
            UInt32(0),
            10,
            0,
            pattern,
            fail_on_mismatch,
            ready_file,
            false,
            log_every,
            verbose,
        )
        app_ref[] = app_agent
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
        close(metadata_cache)
        close(qos_monitor)
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
