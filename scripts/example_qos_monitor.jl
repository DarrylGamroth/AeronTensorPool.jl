#!/usr/bin/env julia
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/example_qos_monitor.jl [driver_config]")
end

function run_qos_monitor(driver_cfg_path::String)
    env_driver = Dict(ENV)
    if haskey(ENV, "AERON_DIR")
        env_driver["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
    end
    driver_cfg = load_driver_config(driver_cfg_path; env = env_driver)

    ctx = TensorPoolContext(driver_cfg.endpoints)
    client = connect(ctx)
    try
        monitor = QosMonitor(driver_cfg.endpoints; client = client.aeron_client)
        producer_id = parse(UInt32, get(ENV, "TP_PRODUCER_ID", "0"))
        consumer_id = parse(UInt32, get(ENV, "TP_CONSUMER_ID", "0"))
        deadline = time_ns() + 5_000_000_000
        while time_ns() < deadline
            AeronTensorPool.do_work(client)
            poll_qos!(monitor)
            if producer_id != 0
                snapshot = producer_qos(monitor, producer_id)
                if snapshot !== nothing
                    println("producer qos: stream=$(snapshot.stream_id) seq=$(snapshot.current_seq)")
                    break
                end
            end
            if consumer_id != 0
                snapshot = consumer_qos(monitor, consumer_id)
                if snapshot !== nothing
                    println("consumer qos: stream=$(snapshot.stream_id) last=$(snapshot.last_seq_seen)")
                    break
                end
            end
            yield()
        end
        close(monitor)
    finally
        close(client)
    end
    return nothing
end

function main()
    Base.exit_on_sigint(false)
    if length(ARGS) > 1
        usage()
        exit(1)
    end
    driver_cfg = length(ARGS) >= 1 ? ARGS[1] : "config/driver_integration_example.toml"
    run_qos_monitor(driver_cfg)
    return nothing
end

main()
