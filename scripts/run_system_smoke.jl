#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/run_system_smoke.jl [config_path] [timeout_s]")
end

config_path = length(ARGS) >= 1 ? ARGS[1] : "config/defaults.toml"
timeout_s = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 5.0

function override_shm_paths(config::ProducerConfig, dir::String)
    header_uri = "shm:file?path=$(joinpath(dir, \"tp_header\"))"
    pools = PayloadPoolConfig[]
    for pool in config.payload_pools
        uri = "shm:file?path=$(joinpath(dir, \"tp_pool_$(pool.pool_id)\"))"
        push!(pools, PayloadPoolConfig(pool.pool_id, uri, pool.stride_bytes, pool.nslots))
    end
    return ProducerConfig(
        config.aeron_dir,
        config.aeron_uri,
        config.descriptor_stream_id,
        config.control_stream_id,
        config.qos_stream_id,
        config.metadata_stream_id,
        config.stream_id,
        config.producer_id,
        config.layout_version,
        config.nslots,
        header_uri,
        pools,
        config.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
    )
end

Aeron.MediaDriver.launch_embedded() do driver
    mktempdir() do dir
        env = Dict(ENV)
        env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
        system = load_system_config(config_path; env = env)
        producer_cfg = override_shm_paths(system.producer, dir)
        consumer_cfg = system.consumer
        supervisor_cfg = system.supervisor

        producer = init_producer(producer_cfg)
        consumer = init_consumer(consumer_cfg)
        supervisor = init_supervisor(supervisor_cfg)

        prod_ctrl = make_control_assembler(producer)
        cons_ctrl = make_control_assembler(consumer)
        got_frame = Ref(false)
        cons_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer) do st, buffer, _
            header = MessageHeader.Decoder(buffer, 0)
            if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
                FrameDescriptor.wrap!(st.desc_decoder, buffer, 0; header = header)
                result = try_read_frame!(st, st.desc_decoder)
                result === nothing || (got_frame[] = true)
            end
            nothing
        end)
        sup_ctrl = make_control_assembler(supervisor)
        sup_qos = make_qos_assembler(supervisor)

        payload = UInt8[1, 2, 3, 4]
        shape = Int32[4]
        strides = Int32[1]
        published = false
        start = time()

        while time() - start < timeout_s
            producer_do_work!(producer, prod_ctrl)
            consumer_do_work!(consumer, cons_desc, cons_ctrl)
            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)

            if !published && consumer.header_mmap !== nothing
                publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                published = true
            end

            if published && got_frame[]
                println("System smoke test completed.")
                return
            end
            yield()
        end
        error("System smoke test timed out.")
    end
end
