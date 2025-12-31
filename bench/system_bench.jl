using Aeron
using AeronTensorPool

function override_shm_paths(config::ProducerConfig, dir::String)
    header_uri = "shm:file?path=$(joinpath(dir, "tp_header"))"
    pools = PayloadPoolConfig[]
    for pool in config.payload_pools
        uri = "shm:file?path=$(joinpath(dir, "tp_pool_$(pool.pool_id)"))"
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
        config.shm_base_dir,
        config.shm_namespace,
        config.producer_instance_id,
        header_uri,
        pools,
        config.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
    )
end

function run_system_bench(config_path::AbstractString, duration_s::Float64; payload_bytes::Int = 1024)
    Aeron.MediaDriver.launch_embedded() do driver
        GC.@preserve driver mktempdir() do dir
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
            sup_ctrl = make_control_assembler(supervisor)
            sup_qos = make_qos_assembler(supervisor)

            consumed = Ref(0)
            cons_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer) do st, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR
                    FrameDescriptor.wrap!(st.desc_decoder, buffer, 0; header = header)
                    result = try_read_frame!(st, st.desc_decoder)
                    result === nothing || (consumed[] += 1)
                end
                nothing
            end)

            payload_bytes > 0 || error("payload_bytes must be > 0")
            payload = fill(UInt8(1), payload_bytes)
            shape = Int32[payload_bytes]
            strides = Int32[1]
            published = 0
            start = time()

            while time() - start < duration_s
                producer_do_work!(producer, prod_ctrl)
                consumer_do_work!(consumer, cons_desc, cons_ctrl)
                supervisor_do_work!(supervisor, sup_ctrl, sup_qos)

                if consumer.header_mmap !== nothing
                    publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                    published += 1
                end
                yield()
            end

            elapsed = time() - start
            println("Published: $(published) frames in $(round(elapsed, digits=3))s")
            println("Consumed:  $(consumed[]) frames in $(round(elapsed, digits=3))s")
            println("Publish rate: $(round(published / elapsed, digits=1)) fps")
            println("Consume rate: $(round(consumed[] / elapsed, digits=1)) fps")
            return nothing
        end
    end
end
