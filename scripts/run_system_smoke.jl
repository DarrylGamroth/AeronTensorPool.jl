#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/run_system_smoke.jl [config_path] [timeout_s]")
end

config_path = length(ARGS) >= 1 ? ARGS[1] : "config/driver_integration_example.toml"
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
        config.stream_id,
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
        config.mlock_shm,
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
        config.progress_major_delta_units,
        config.hello_interval_ns,
        config.qos_interval_ns,
        config.announce_freshness_ns,
        config.requested_descriptor_channel,
        config.requested_descriptor_stream_id,
        config.requested_control_channel,
        config.requested_control_stream_id,
        config.mlock_shm,
    )
end

function first_stream_profile(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    stream = first(values(cfg.streams))
    profile = cfg.profiles[stream.profile]
    return stream, profile
end

Aeron.MediaDriver.launch_embedded() do driver
    GC.@preserve driver mktempdir() do dir
        env = Dict(ENV)
        env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
        driver_cfg = load_driver_config(config_path; env = env)
        stream, profile = first_stream_profile(driver_cfg)
        pools = [
            PayloadPoolConfig(pool.pool_id, "", pool.stride_bytes, profile.header_nslots) for pool in profile.payload_pools
        ]
        control_stream_id = driver_cfg.endpoints.control_stream_id
        qos_stream_id = driver_cfg.endpoints.qos_stream_id
        producer_cfg = default_producer_config(
            ;
            aeron_dir = env["AERON_DIR"],
            stream_id = stream.stream_id,
            nslots = profile.header_nslots,
            payload_pools = pools,
            shm_base_dir = dir,
            producer_instance_id = "smoke-producer",
            control_stream_id = control_stream_id,
            qos_stream_id = qos_stream_id,
        )
        producer_cfg = apply_canonical_layout(producer_cfg, dir)
        consumer_cfg = default_consumer_config(
            ;
            aeron_dir = env["AERON_DIR"],
            stream_id = stream.stream_id,
            shm_base_dir = dir,
            control_stream_id = control_stream_id,
            qos_stream_id = qos_stream_id,
        )
        consumer_cfg = apply_canonical_layout(consumer_cfg, dir)
        supervisor_cfg = SupervisorConfig(
            env["AERON_DIR"],
            "aeron:ipc",
            control_stream_id,
            qos_stream_id,
            stream.stream_id,
            UInt64(5_000_000_000),
            UInt64(1_000_000_000),
        )

        mkpath(dirname(parse_shm_uri(producer_cfg.header_uri).path))
        for pool in producer_cfg.payload_pools
            mkpath(dirname(parse_shm_uri(pool.uri).path))
        end

        Aeron.Context() do context
            Aeron.aeron_dir!(context, env["AERON_DIR"])
            Aeron.Client(context) do client
                producer = Producer.init_producer(producer_cfg; client = client)
                consumer = Consumer.init_consumer(consumer_cfg; client = client)
                supervisor = Supervisor.init_supervisor(supervisor_cfg; client = client)

                prod_ctrl = Producer.make_control_assembler(producer)
                cons_ctrl = Consumer.make_control_assembler(consumer)
                got_frame = Ref(false)
                cons_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer) do st, buffer, _
                    header = MessageHeader.Decoder(buffer, 0)
                    if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR
                        FrameDescriptor.wrap!(st.runtime.desc_decoder, buffer, 0; header = header)
                        result = Consumer.try_read_frame!(st, st.runtime.desc_decoder)
                        result === nothing || (got_frame[] = true)
                    end
                    nothing
                end)
                sup_ctrl = Supervisor.make_control_assembler(supervisor)
                sup_qos = Supervisor.make_qos_assembler(supervisor)

                payload = UInt8[1, 2, 3, 4]
                shape = Int32[4]
                strides = Int32[1]
                published = false
                start = time()

                while time() - start < timeout_s
                    Producer.producer_do_work!(producer, prod_ctrl)
                    Consumer.consumer_do_work!(consumer, cons_desc, cons_ctrl)
                    Supervisor.supervisor_do_work!(supervisor, sup_ctrl, sup_qos)

                    if !published && consumer.mappings.header_mmap !== nothing
                        Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
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
    end
end
