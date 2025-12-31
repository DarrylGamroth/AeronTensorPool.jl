#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/run_role.jl <producer|consumer|supervisor> [config_path]")
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
    qos_asm = Aeron.FragmentAssembler(Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_QOS_PRODUCER
            QosProducer.wrap!(st.qos_producer_decoder, buffer, 0; header = header)
            AeronTensorPool.handle_qos_producer!(st, st.qos_producer_decoder)
        elseif template_id == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.qos_consumer_decoder, buffer, 0; header = header)
            AeronTensorPool.handle_qos_consumer!(st, st.qos_consumer_decoder)
        end
        nothing
    end)
    try
        while true
            work = supervisor_do_work!(state, ctrl_asm, qos_asm)
            work == 0 && yield()
        end
    catch err
        @info "Supervisor exiting" error = err
    end
else
    usage()
    exit(1)
end
