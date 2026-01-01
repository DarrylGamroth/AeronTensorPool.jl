#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/run_role.jl <producer|consumer|supervisor|driver> [config_path]")
end

if length(ARGS) < 1
    usage()
    exit(1)
end

role = ARGS[1]
config_path = length(ARGS) >= 2 ? ARGS[2] : "config/defaults.toml"

if role == "producer"
    config = load_producer_config(config_path)
    state = init_producer(config)
    assembler = make_control_assembler(state)
    try
        while true
            work = producer_do_work!(state, assembler)
            work == 0 && yield()
        end
    catch err
        @info "Producer exiting" error = err
    end
elseif role == "consumer"
    config = load_consumer_config(config_path)
    state = init_consumer(config)
    desc_asm = make_descriptor_assembler(state)
    ctrl_asm = make_control_assembler(state)
    try
        while true
            work = consumer_do_work!(state, desc_asm, ctrl_asm)
            work == 0 && yield()
        end
    catch err
        @info "Consumer exiting" error = err
    end
elseif role == "supervisor"
    config = load_supervisor_config(config_path)
    state = init_supervisor(config)
    ctrl_asm = make_control_assembler(state)
    qos_asm = make_qos_assembler(state)
    try
        while true
            work = supervisor_do_work!(state, ctrl_asm, qos_asm)
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
else
    usage()
    exit(1)
end
