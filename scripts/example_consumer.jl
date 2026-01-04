#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool

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
    driver_cfg = load_driver_config(driver_cfg_path)
    stream_id = first_stream_id(driver_cfg)
    control = driver_cfg.endpoints

    env = Dict(ENV)
    env["AERON_DIR"] = control.aeron_dir
    env["TP_STREAM_ID"] = string(stream_id)
    cons_cfg = load_consumer_config(consumer_cfg_path; env = env)

    Aeron.Context() do ctx
        AeronTensorPool.set_aeron_dir!(ctx, control.aeron_dir)
        Aeron.Client(ctx) do client
            driver_client = init_driver_client(
                client,
                control.control_channel,
                control.control_stream_id,
                UInt32(21),
                DriverRole.CONSUMER,
            )

            attach_id = send_attach_request!(driver_client; stream_id = stream_id)
            attach_id == 0 && error("attach send failed")

            attach = nothing
            while attach === nothing
                attach = poll_attach!(driver_client, attach_id, UInt64(time_ns()))
                yield()
            end

            consumer = init_consumer_from_attach(cons_cfg, attach; driver_client = driver_client, client = client)
            desc_asm = make_descriptor_assembler(consumer)
            ctrl_asm = make_control_assembler(consumer)
            counters = ConsumerCounters(consumer.runtime.control.client, Int(consumer.config.consumer_id), "Consumer")
            agent = ConsumerAgent(consumer, desc_asm, ctrl_asm, counters)
            runner = AgentRunner(BusySpinIdleStrategy(), agent)

            last_frame = UInt64(0)
            seen = 0
            Agent.start_on_thread(runner)
            while count <= 0 || seen < count
                header = agent.state.runtime.frame_view.header
                if header.frame_id != 0 && header.frame_id != last_frame
                    last_frame = header.frame_id
                    expected = UInt8(header.frame_id % UInt64(256))
                    payload = payload_view(agent.state.runtime.frame_view.payload)
                    ok = check_pattern(payload, expected)
                    ok || error("payload mismatch at frame $(header.frame_id)")
                    seen += 1
                    println("frame=$(header.frame_id) ok")
                end
                yield()
            end
            close(runner)
            @info "Consumer done" seen
        end
    end
end

if length(ARGS) > 3
    usage()
    exit(1)
end

driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "docs/examples/driver_integration_example.toml"
consumer_cfg = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"
count = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0

run_consumer(driver_cfg, consumer_cfg, count)
