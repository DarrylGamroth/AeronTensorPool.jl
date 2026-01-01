#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/run_system_smoke.jl [config_path] [timeout_s]")
end

config_path = length(ARGS) >= 1 ? ARGS[1] : "config/defaults.toml"
timeout_s = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 5.0

function apply_canonical_layout(
    config::ProducerConfig,
    base_dir::String;
    namespace::String = "tensorpool",
    producer_instance_id::String = "smoke-producer",
    epoch::UInt64 = UInt64(1),
)
    pools = [PayloadPoolConfig(pool.pool_id, "", pool.stride_bytes, pool.nslots) for pool in config.payload_pools]
    header_uri, resolved_pools = AeronTensorPool.resolve_producer_paths(
        "",
        pools,
        base_dir,
        namespace,
        producer_instance_id,
        epoch,
    )
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
        base_dir,
        namespace,
        producer_instance_id,
        header_uri,
        resolved_pools,
        config.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
    )
end

function apply_canonical_layout(config::ConsumerConfig, base_dir::String)
    return ConsumerConfig(
        config.aeron_dir,
        config.aeron_uri,
        config.descriptor_stream_id,
        config.control_stream_id,
        config.qos_stream_id,
        config.stream_id,
        config.consumer_id,
        config.expected_layout_version,
        config.max_dims,
        config.mode,
        config.decimation,
        config.max_outstanding_seq_gap,
        config.use_shm,
        config.supports_shm,
        config.supports_progress,
        config.max_rate_hz,
        config.payload_fallback_uri,
        base_dir,
        [base_dir],
        config.require_hugepages,
        config.progress_interval_us,
        config.progress_bytes_delta,
        config.progress_rows_delta,
        config.hello_interval_ns,
        config.qos_interval_ns,
    )
end

Aeron.MediaDriver.launch_embedded() do driver
    GC.@preserve driver mktempdir() do dir
        env = Dict(ENV)
        env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
        system = load_system_config(config_path; env = env)
        producer_cfg = apply_canonical_layout(system.producer, dir)
        consumer_cfg = apply_canonical_layout(system.consumer, dir)
        supervisor_cfg = system.supervisor

        mkpath(dirname(parse_shm_uri(producer_cfg.header_uri).path))
        for pool in producer_cfg.payload_pools
            mkpath(dirname(parse_shm_uri(pool.uri).path))
        end

        producer = init_producer(producer_cfg)
        consumer = init_consumer(consumer_cfg)
        supervisor = init_supervisor(supervisor_cfg)

        prod_ctrl = make_control_assembler(producer)
        cons_ctrl = make_control_assembler(consumer)
        got_frame = Ref(false)
        cons_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer) do st, buffer, _
            header = MessageHeader.Decoder(buffer, 0)
            if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR
                FrameDescriptor.wrap!(st.runtime.desc_decoder, buffer, 0; header = header)
                result = try_read_frame!(st, st.runtime.desc_decoder)
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

            if !published && consumer.mappings.header_mmap !== nothing
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
