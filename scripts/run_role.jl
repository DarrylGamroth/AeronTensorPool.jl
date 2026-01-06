#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/run_role.jl <producer|consumer|supervisor|driver|bridge> [config_path]")
end

if length(ARGS) < 1
    usage()
    exit(1)
end

role = ARGS[1]
config_path = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"

if role == "producer"
    config = load_producer_config(config_path)
    state = Producer.init_producer(config)
    assembler = Producer.make_control_assembler(state)
    try
        while true
            work = Producer.producer_do_work!(state, assembler)
            work == 0 && yield()
        end
    catch err
        @info "Producer exiting" error = err
    end
elseif role == "consumer"
    config = load_consumer_config(config_path)
    state = Consumer.init_consumer(config)
    desc_asm = Consumer.make_descriptor_assembler(state)
    ctrl_asm = Consumer.make_control_assembler(state)
    try
        while true
            work = Consumer.consumer_do_work!(state, desc_asm, ctrl_asm)
            work == 0 && yield()
        end
    catch err
        @info "Consumer exiting" error = err
    end
elseif role == "supervisor"
    config = load_supervisor_config(config_path)
    state = Supervisor.init_supervisor(config)
    ctrl_asm = Supervisor.make_control_assembler(state)
    qos_asm = Supervisor.make_qos_assembler(state)
    try
        while true
            work = Supervisor.supervisor_do_work!(state, ctrl_asm, qos_asm)
            work == 0 && yield()
        end
    catch err
        @info "Supervisor exiting" error = err
    end
elseif role == "driver"
    config = load_driver_config(config_path)
    state = init_driver(config)
    try
        while true
            work = driver_do_work!(state)
            work == 0 && yield()
        end
    catch err
        @info "Driver exiting" error = err
    end
elseif role == "bridge"
    bridge_cfg = load_bridge_config(config_path)
    if isempty(bridge_cfg.mappings)
        error("Bridge config requires at least one mapping")
    end
    consumer_cfg = load_consumer_config(config_path)
    producer_cfg = load_producer_config(config_path)
    agent = BridgeSystemAgent(bridge_cfg.bridge, bridge_cfg.mappings, consumer_cfg, producer_cfg)
    try
        while true
            work = Agent.do_work(agent)
            work == 0 && yield()
        end
    catch err
        @info "Bridge exiting" error = err
    end
else
    usage()
    exit(1)
end
