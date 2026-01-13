using Aeron
using AeronTensorPool
using Agent
using Clocks
using Base.Threads: Atomic, atomic_add!

function ensure_shm_dir(uri::AbstractString)
    parsed = AeronTensorPool.parse_shm_uri(uri)
    mkpath(dirname(parsed.path))
    return nothing
end

function close_producer!(producer)
    close(producer.runtime.pub_descriptor)
    close(producer.runtime.control.pub_control)
    close(producer.runtime.pub_qos)
    close(producer.runtime.pub_metadata)
    close(producer.runtime.control.sub_control)
    return nothing
end

function close_consumer!(consumer)
    close(consumer.runtime.control.pub_control)
    close(consumer.runtime.pub_qos)
    close(consumer.runtime.sub_descriptor)
    close(consumer.runtime.control.sub_control)
    close(consumer.runtime.sub_qos)
    return nothing
end

function close_supervisor!(supervisor)
    close(supervisor.runtime.control.pub_control)
    close(supervisor.runtime.control.sub_control)
    close(supervisor.runtime.sub_qos)
    return nothing
end

function close_bridge_sender!(sender)
    close(sender.pub_payload)
    close(sender.pub_control)
    close(sender.sub_control)
    if sender.pub_metadata !== nothing
        close(sender.pub_metadata)
    end
    if sender.sub_metadata !== nothing
        close(sender.sub_metadata)
    end
    return nothing
end

function close_bridge_receiver!(receiver)
    close(receiver.sub_payload)
    close(receiver.sub_control)
    if receiver.sub_metadata !== nothing
        close(receiver.sub_metadata)
    end
    if receiver.pub_metadata_local !== nothing
        close(receiver.pub_metadata_local)
    end
    if receiver.pub_control_local !== nothing
        close(receiver.pub_control_local)
    end
    return nothing
end

struct ProducerWork
    state::ProducerState
    control_assembler::Aeron.FragmentAssembler
    qos_assembler::Aeron.FragmentAssembler
end

Agent.name(::ProducerWork) = "producer-work"

function Agent.do_work(agent::ProducerWork)
    return Producer.producer_do_work!(agent.state, agent.control_assembler, agent.qos_assembler)
end

Agent.on_close(::ProducerWork) = nothing

function make_counting_callbacks(counter::Base.RefValue{Int})
    return ConsumerCallbacks(; on_frame! = (_, _) -> (counter[] += 1))
end

function make_atomic_callbacks(counter::Atomic{Int})
    return ConsumerCallbacks(; on_frame! = (_, _) -> atomic_add!(counter, 1))
end

function apply_canonical_layout(
    config::ProducerConfig,
    base_dir::String;
    namespace::String = "tensorpool",
    producer_instance_id::String = "bench-producer",
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
    ensure_shm_dir(header_uri)
    for pool in resolved_pools
        ensure_shm_dir(pool.uri)
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

function override_producer_streams(
    config::ProducerConfig;
    stream_id::UInt32,
    descriptor_stream_id::Int32,
    control_stream_id::Int32,
    qos_stream_id::Int32,
    metadata_stream_id::Int32,
    producer_id::UInt32,
    producer_instance_id::String,
)
    return ProducerConfig(
        config.aeron_dir,
        config.aeron_uri,
        descriptor_stream_id,
        control_stream_id,
        qos_stream_id,
        metadata_stream_id,
        stream_id,
        producer_id,
        config.layout_version,
        config.nslots,
        config.shm_base_dir,
        config.shm_namespace,
        producer_instance_id,
        config.header_uri,
        config.payload_pools,
        config.max_dims,
        config.announce_interval_ns,
        config.qos_interval_ns,
        config.progress_interval_ns,
        config.progress_bytes_delta,
        config.mlock_shm,
    )
end

function override_consumer_streams(
    config::ConsumerConfig;
    stream_id::UInt32,
    descriptor_stream_id::Int32,
    control_stream_id::Int32,
    qos_stream_id::Int32,
    consumer_id::UInt32,
)
    return ConsumerConfig(
        config.aeron_dir,
        config.aeron_uri,
        descriptor_stream_id,
        control_stream_id,
        qos_stream_id,
        stream_id,
        consumer_id,
        config.expected_layout_version,
        config.max_dims,
        config.mode,
        config.max_outstanding_seq_gap,
        config.use_shm,
        config.supports_shm,
        config.supports_progress,
        config.max_rate_hz,
        config.payload_fallback_uri,
        config.shm_base_dir,
        config.allowed_base_dirs,
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

function stream_profile_from_driver(config::DriverConfig)
    isempty(config.streams) && error("driver config has no streams")
    stream = first(values(config.streams))
    profile = config.profiles[stream.profile]
    return stream, profile
end

function producer_config_from_driver(
    stream::DriverStreamConfig,
    profile::DriverProfileConfig,
    base_dir::String,
    aeron_dir::String;
    producer_instance_id::String = "bench-producer",
    control_stream_id::Int32 = Int32(1000),
    qos_stream_id::Int32 = Int32(1200),
)
    pools = [
        PayloadPoolConfig(pool.pool_id, "", pool.stride_bytes, profile.header_nslots) for pool in profile.payload_pools
    ]
    cfg = default_producer_config(;
        aeron_dir = aeron_dir,
        stream_id = stream.stream_id,
        nslots = profile.header_nslots,
        payload_pools = pools,
        shm_base_dir = base_dir,
        producer_instance_id = producer_instance_id,
        control_stream_id = control_stream_id,
        qos_stream_id = qos_stream_id,
    )
    return apply_canonical_layout(cfg, base_dir; producer_instance_id = producer_instance_id)
end

function consumer_config_from_driver(
    stream::DriverStreamConfig,
    base_dir::String,
    aeron_dir::String;
    control_stream_id::Int32 = Int32(1000),
    qos_stream_id::Int32 = Int32(1200),
)
    cfg = default_consumer_config(;
        aeron_dir = aeron_dir,
        stream_id = stream.stream_id,
        shm_base_dir = base_dir,
        control_stream_id = control_stream_id,
        qos_stream_id = qos_stream_id,
    )
    return apply_canonical_layout(cfg, base_dir)
end

function supervisor_config_from_driver(
    stream::DriverStreamConfig,
    aeron_dir::String,
    control_stream_id::Int32,
    qos_stream_id::Int32,
)
    return SupervisorConfig(
        aeron_dir,
        "aeron:ipc",
        control_stream_id,
        qos_stream_id,
        stream.stream_id,
        UInt64(5_000_000_000),
        UInt64(1_000_000_000),
    )
end

function run_system_bench(
    config_path::AbstractString,
    duration_s::Float64;
    payload_bytes::Int = 1024,
    payload_bytes_list::Vector{Int} = Int[],
    warmup_s::Float64 = 0.2,
    alloc_sample::Bool = false,
    alloc_probe_iters::Int = 0,
    fixed_iters::Int = 0,
    alloc_breakdown::Bool = false,
    noop_loop::Bool = false,
    do_yield::Bool = true,
    poll_timers::Bool = true,
    do_publish::Bool = true,
    poll_subs::Bool = true,
)
    Aeron.MediaDriver.launch_embedded() do driver
        GC.@preserve driver begin
            Aeron.Context() do context
                Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
                Aeron.Client(context) do client
                    env = Dict(ENV)
                    env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
                    driver_cfg = load_driver_config(config_path; env = env)
                    stream, profile = stream_profile_from_driver(driver_cfg)
                    control_stream_id = driver_cfg.endpoints.control_stream_id
                    qos_stream_id = driver_cfg.endpoints.qos_stream_id
                    sizes = isempty(payload_bytes_list) ? [payload_bytes] : payload_bytes_list
                    for bytes in sizes
                        bytes > 0 || error("payload_bytes must be > 0")
                        mktempdir() do dir
                            producer_cfg = producer_config_from_driver(
                                stream,
                                profile,
                                dir,
                                env["AERON_DIR"];
                                control_stream_id = control_stream_id,
                                qos_stream_id = qos_stream_id,
                            )
                            consumer_cfg = consumer_config_from_driver(
                                stream,
                                dir,
                                env["AERON_DIR"];
                                control_stream_id = control_stream_id,
                                qos_stream_id = qos_stream_id,
                            )
                            supervisor_cfg = supervisor_config_from_driver(
                                stream,
                                env["AERON_DIR"],
                                control_stream_id,
                                qos_stream_id,
                            )

                            published = 0
                            consumed = Ref(0)
                            consumer_callbacks = make_counting_callbacks(consumed)

                            producer_agent = ProducerAgent(producer_cfg; client = client)
                            consumer_agent = ConsumerAgent(consumer_cfg; client = client, callbacks = consumer_callbacks)
                            supervisor_agent = SupervisorAgent(supervisor_cfg; client = client)
                            system_agent = CompositeAgent(producer_agent, consumer_agent, supervisor_agent)
                            system_invoker = AgentInvoker(system_agent)
                            Agent.start(system_invoker)

                            producer = producer_agent.state
                            consumer = consumer_agent.state
                            supervisor = supervisor_agent.state

                    payload = fill(UInt8(1), bytes)
                    shape = Int32[bytes]
                    strides = Int32[1]
                    if warmup_s > 0
                        warmup_start = time_ns()
                        warmup_limit = warmup_start + Int64(round(warmup_s * 1e9))
                        while time_ns() < warmup_limit
                            Agent.invoke(system_invoker)
                            if consumer.mappings.header_mmap !== nothing
                                Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                            yield()
                        end
                        consumed[] = 0
                        published = 0
                    end

                    if alloc_sample
                        wait_start = time_ns()
                        wait_limit = wait_start + Int64(2e9)
                        while consumer.mappings.header_mmap === nothing && time_ns() < wait_limit
                            Agent.invoke(system_invoker)
                            yield()
                        end
                        for _ in 1:32
                            Agent.invoke(system_invoker)
                            if consumer.mappings.header_mmap !== nothing
                                Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                            yield()
                        end
                        sample_before = Base.gc_num().allocd
                        Agent.invoke(system_invoker)
                        if consumer.mappings.header_mmap !== nothing
                            Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                        end
                        sample_after = Base.gc_num().allocd
                        println("Sample alloc per-iteration: $(sample_after - sample_before) bytes")
                    end

                    if alloc_breakdown
                        wait_start = time_ns()
                        wait_limit = wait_start + Int64(2e9)
                        while consumer.mappings.header_mmap === nothing && time_ns() < wait_limit
                            Agent.invoke(system_invoker)
                            yield()
                        end
                        for _ in 1:32
                            Agent.invoke(system_invoker)
                            if consumer.mappings.header_mmap !== nothing
                                Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                            yield()
                        end
                        function measure_allocd(f::Function, label::String)
                            before = Base.gc_num().allocd
                            f()
                            after = Base.gc_num().allocd
                            println("Alloc breakdown $(label): $(after - before) bytes")
                        end
                        measure_allocd("GC.gc") do
                            GC.gc()
                        end
                        measure_allocd("producer_do_work") do
                            Agent.invoke(system_invoker)
                        end
                        measure_allocd("composite_do_work") do
                            Agent.do_work(system_agent)
                        end
                        measure_allocd("producer_do_work_raw") do
                            Producer.producer_do_work!(
                                producer,
                                producer_agent.control_assembler,
                                producer_agent.qos_assembler,
                            )
                        end
                        measure_allocd("producer_do_work_agent") do
                            Agent.do_work(producer_agent)
                        end
                        measure_allocd("producer_counter_updates") do
                            Aeron.increment!(producer_agent.counters.base.total_duty_cycles)
                            work_done = 0
                            if work_done > 0
                                Aeron.add!(
                                    producer_agent.counters.base.total_work_done,
                                    Int64(work_done),
                                )
                            end
                            producer_agent.counters.frames_published[] = Int64(producer_agent.state.seq)
                            producer_agent.counters.announces[] =
                                Int64(producer_agent.state.metrics.announce_count)
                            producer_agent.counters.qos_published[] =
                                Int64(producer_agent.state.metrics.qos_count)
                        end
                        measure_allocd("consumer_do_work") do
                            Agent.invoke(system_invoker)
                        end
                        measure_allocd("consumer_do_work_raw") do
                            Consumer.consumer_do_work!(
                                consumer,
                                consumer_agent.descriptor_assembler,
                                consumer_agent.control_assembler,
                            )
                        end
                        measure_allocd("consumer_do_work_agent") do
                            Agent.do_work(consumer_agent)
                        end
                        if consumer.mappings.header_mmap !== nothing
                            Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            measure_allocd("consumer_do_work (with frame)") do
                                Agent.invoke(system_invoker)
                            end
                        end
                        measure_allocd("supervisor_do_work") do
                            Agent.invoke(system_invoker)
                        end
                        measure_allocd("supervisor_do_work_raw") do
                            Supervisor.supervisor_do_work!(
                                supervisor,
                                supervisor_agent.control_assembler,
                                supervisor_agent.qos_assembler,
                            )
                        end
                        measure_allocd("supervisor_do_work_agent") do
                            Agent.do_work(supervisor_agent)
                        end
                        measure_allocd("publish_frame") do
                            if consumer.mappings.header_mmap !== nothing
                                Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                        end
                        measure_allocd("producer_poll_timers") do
                            Clocks.fetch!(producer.clock)
                            now_ns = UInt64(Clocks.time_nanos(producer.clock)) + producer.config.announce_interval_ns
                            Producer.poll_timers!(producer, now_ns)
                        end
                        measure_allocd("consumer_poll_timers") do
                            Clocks.fetch!(consumer.clock)
                            now_ns = UInt64(Clocks.time_nanos(consumer.clock)) + consumer.config.hello_interval_ns
                            Consumer.poll_timers!(consumer, now_ns)
                        end
                        measure_allocd("emit_consumer_hello") do
                            Consumer.emit_consumer_hello!(consumer)
                        end
                        measure_allocd("emit_consumer_qos") do
                            Consumer.emit_qos!(consumer)
                        end
                        measure_allocd("supervisor_poll_timers") do
                            Clocks.fetch!(supervisor.clock)
                            now_ns = UInt64(Clocks.time_nanos(supervisor.clock)) + supervisor.config.liveness_check_interval_ns
                            Supervisor.poll_timers!(supervisor, now_ns)
                        end
                        measure_allocd("yield") do
                            yield()
                        end
                        if fixed_iters > 0
                            empty_before = Base.gc_num().allocd
                            for _ in 1:fixed_iters
                                yield()
                            end
                            empty_after = Base.gc_num().allocd
                            println("Alloc breakdown empty loop ($(fixed_iters) iters): $(empty_after - empty_before) bytes")
                        end
                    end

                    if alloc_probe_iters > 0
                        GC.gc()
                        probe_start = Base.gc_num().allocd
                        for _ in 1:alloc_probe_iters
                            Agent.invoke(system_invoker)
                            if consumer.mappings.header_mmap !== nothing
                                Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                            yield()
                        end
                        probe_end = Base.gc_num().allocd
                        println("Alloc delta (probe $(alloc_probe_iters) iters): $(probe_end - probe_start) bytes")
                    end

                    if alloc_sample || alloc_probe_iters > 0
                        consumed[] = 0
                        published = 0
                    end

                    GC.gc()
                    gc_num_overhead = Base.gc_num().allocd
                    gc_num_overhead = Base.gc_num().allocd - gc_num_overhead
                    time_overhead = Base.gc_num().allocd
                    _ = time_ns()
                    time_overhead = Base.gc_num().allocd - time_overhead
                    start_num = Base.gc_num()
                    start_live = Base.gc_live_bytes()
                    start = time_ns()
                    iter_count = 0
                    if fixed_iters > 0
                        while iter_count < fixed_iters
                            if !noop_loop
                                Agent.invoke(system_invoker)

                                if do_publish && consumer.mappings.header_mmap !== nothing
                                    Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                                    published += 1
                                end
                            end
                            iter_count += 1
                            do_yield && yield()
                        end
                    else
                        end_limit = start + Int64(round(duration_s * 1e9))
                        while time_ns() < end_limit
                            if !noop_loop
                                Agent.invoke(system_invoker)

                                if do_publish && consumer.mappings.header_mmap !== nothing
                                    Producer.offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                                    published += 1
                                end
                            end
                            do_yield && yield()
                        end
                    end

                    elapsed = (time_ns() - start) / 1e9
                    mid_num = Base.gc_num()
                    mid_live = Base.gc_live_bytes()
                    GC.gc()
                    end_num = Base.gc_num()
                    end_live = Base.gc_live_bytes()
                    allocd_loop_raw = mid_num.allocd - start_num.allocd
                    allocd_loop = max(Int64(0), allocd_loop_raw - gc_num_overhead - time_overhead)
                    live_loop = mid_live - start_live
                    allocd_total_raw = end_num.allocd - start_num.allocd
                    allocd_total = max(Int64(0), allocd_total_raw - (2 * gc_num_overhead + time_overhead))
                    live_total = end_live - start_live
                    publish_rate = published / elapsed
                    consume_rate = consumed[] / elapsed
                    bytes_per_frame = Float64(bytes)
                    publish_mib_s = (publish_rate * bytes_per_frame) / (1024.0 * 1024.0)
                    consume_mib_s = (consume_rate * bytes_per_frame) / (1024.0 * 1024.0)
                    println("System benchmark: payload_bytes=$(bytes)")
                    println("Published: $(published) frames in $(round(elapsed, digits=3))s")
                    println("Consumed:  $(consumed[]) frames in $(round(elapsed, digits=3))s")
                    println("Publish rate: $(round(publish_rate, digits=1)) fps")
                    println("Consume rate: $(round(consume_rate, digits=1)) fps")
                    println("Publish bandwidth: $(round(publish_mib_s, digits=1)) MiB/s")
                    println("Consume bandwidth: $(round(consume_mib_s, digits=1)) MiB/s")
                    println("GC allocd overhead per sample: $(gc_num_overhead) bytes")
                    println("GC allocd overhead per time_ns(): $(time_overhead) bytes")
                    println("GC allocd delta (loop):  $(allocd_loop) bytes")
                    println("GC live delta (loop):   $(live_loop) bytes")
                    println("GC allocd delta (total): $(allocd_total) bytes")
                    println("GC live delta (total):  $(live_total) bytes")
                    println()

                            close(system_invoker)
                        end
                    end
                end
            end
            return nothing
        end
    end
end

function run_bridge_bench_runners(
    config_path::AbstractString,
    duration_s::Float64;
    payload_bytes::Int = 1024,
    payload_bytes_list::Vector{Int} = Int[],
    warmup_s::Float64 = 0.2,
    alloc_sample::Bool = false,
    alloc_probe_iters::Int = 0,
    fixed_iters::Int = 0,
    alloc_breakdown::Bool = false,
    noop_loop::Bool = false,
    do_yield::Bool = true,
    poll_timers::Bool = true,
    do_publish::Bool = true,
    poll_subs::Bool = true,
)
    if Threads.nthreads() < 2
        println("Bridge runners benchmark requires JULIA_NUM_THREADS >= 2")
        return nothing
    end
    Aeron.MediaDriver.launch_embedded() do driver
        GC.@preserve driver begin
            Aeron.Context() do context
                Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
                Aeron.Client(context) do client
                    env = Dict(ENV)
                    env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
                    driver_cfg = load_driver_config(config_path; env = env)
                    stream, profile = stream_profile_from_driver(driver_cfg)
                    control_stream_id = driver_cfg.endpoints.control_stream_id
                    qos_stream_id = driver_cfg.endpoints.qos_stream_id
                    pools = [
                        PayloadPoolConfig(pool.pool_id, "", pool.stride_bytes, profile.header_nslots)
                        for pool in profile.payload_pools
                    ]
                    base_producer_cfg = default_producer_config(
                        ;
                        aeron_dir = env["AERON_DIR"],
                        stream_id = stream.stream_id,
                        nslots = profile.header_nslots,
                        payload_pools = pools,
                        shm_base_dir = "/dev/shm",
                        producer_instance_id = "bench-src",
                        control_stream_id = control_stream_id,
                        qos_stream_id = qos_stream_id,
                    )
                    base_consumer_cfg = default_consumer_config(
                        ;
                        aeron_dir = env["AERON_DIR"],
                        stream_id = stream.stream_id,
                        shm_base_dir = "/dev/shm",
                        control_stream_id = control_stream_id,
                        qos_stream_id = qos_stream_id,
                    )
                    sizes = isempty(payload_bytes_list) ? [payload_bytes] : payload_bytes_list

                    src_stream_id = base_producer_cfg.stream_id
                    dst_stream_id = src_stream_id + UInt32(1)
                    src_descriptor = base_producer_cfg.descriptor_stream_id
                    src_control = base_producer_cfg.control_stream_id
                    src_qos = base_producer_cfg.qos_stream_id
                    src_meta = base_producer_cfg.metadata_stream_id
                    dst_descriptor = src_descriptor + Int32(1000)
                    dst_control = src_control + Int32(1000)
                    dst_qos = src_qos + Int32(1000)
                    dst_meta = src_meta + Int32(1000)

                    for bytes in sizes
                        bytes > 0 || error("payload_bytes must be > 0")
                        mktempdir() do src_dir
                            mktempdir() do dst_dir
                                src_producer_cfg = override_producer_streams(
                                    base_producer_cfg;
                                    stream_id = src_stream_id,
                                    descriptor_stream_id = src_descriptor,
                                    control_stream_id = src_control,
                                    qos_stream_id = src_qos,
                                    metadata_stream_id = src_meta,
                                    producer_id = base_producer_cfg.producer_id,
                                    producer_instance_id = "bench-src",
                                )
                                dst_producer_cfg = override_producer_streams(
                                    base_producer_cfg;
                                    stream_id = dst_stream_id,
                                    descriptor_stream_id = dst_descriptor,
                                    control_stream_id = dst_control,
                                    qos_stream_id = dst_qos,
                                    metadata_stream_id = dst_meta,
                                    producer_id = base_producer_cfg.producer_id + UInt32(1),
                                    producer_instance_id = "bench-dst",
                                )
                                producer_src_cfg = apply_canonical_layout(
                                    src_producer_cfg,
                                    src_dir;
                                    producer_instance_id = "bench-src",
                                )
                                producer_dst_cfg = apply_canonical_layout(
                                    dst_producer_cfg,
                                    dst_dir;
                                    producer_instance_id = "bench-dst",
                                )
                                producer_src_agent = ProducerAgent(producer_src_cfg; client = client)

                                bridge_consumer_cfg = override_consumer_streams(
                                    base_consumer_cfg;
                                    stream_id = src_stream_id,
                                    descriptor_stream_id = src_descriptor,
                                    control_stream_id = src_control,
                                    qos_stream_id = src_qos,
                                    consumer_id = base_consumer_cfg.consumer_id + UInt32(2),
                                )
                                consumer_dst_cfg = override_consumer_streams(
                                    base_consumer_cfg;
                                    stream_id = dst_stream_id,
                                    descriptor_stream_id = dst_descriptor,
                                    control_stream_id = dst_control,
                                    qos_stream_id = dst_qos,
                                    consumer_id = base_consumer_cfg.consumer_id + UInt32(1),
                                )
                                bridge_consumer_cfg = apply_canonical_layout(bridge_consumer_cfg, src_dir)
                                consumer_dst_cfg = apply_canonical_layout(consumer_dst_cfg, dst_dir)

                                bridge_cfg = BridgeConfig(
                                    "bridge-bench",
                                    Aeron.MediaDriver.aeron_dir(driver),
                                    "aeron:ipc",
                                    Int32(3100),
                                    "aeron:ipc",
                                    Int32(3000),
                                    "",
                                    Int32(0),
                                    Int32(0),
                                    UInt32(1408),
                                    UInt32(1024),
                                    UInt32(0),
                                    UInt32(max(bytes, 1)),
                                    UInt64(250_000_000),
                                    false,
                                    false,
                                    false,
                                )
                                mapping =
                                    BridgeMapping(UInt32(src_stream_id), UInt32(dst_stream_id), "bench", UInt32(0), Int32(0), Int32(0))
                                consumed = Atomic{Int}(0)
                                consumer_callbacks = make_atomic_callbacks(consumed)
                                consumer_dst_agent =
                                    ConsumerAgent(consumer_dst_cfg; client = client, callbacks = consumer_callbacks)
                                bridge_agent = BridgeAgent(
                                    bridge_cfg,
                                    mapping,
                                    bridge_consumer_cfg,
                                    producer_dst_cfg;
                                    client = client,
                                )
                                fetch!(bridge_agent.receiver.producer_state.clock)
                                Producer.emit_announce!(bridge_agent.receiver.producer_state)

                                producer_dst_work = let st = bridge_agent.receiver.producer_state
                                    ProducerWork(
                                        st,
                                        Producer.make_control_assembler(st),
                                        Producer.make_qos_assembler(st),
                                    )
                                end
                                runner_src = AgentRunner(
                                    BackoffIdleStrategy(),
                                    CompositeAgent(producer_src_agent, bridge_agent, producer_dst_work),
                                )
                                runner_dst = AgentRunner(BackoffIdleStrategy(), consumer_dst_agent)
                                Agent.start_on_thread(runner_src)
                                Agent.start_on_thread(runner_dst)

                                payload = fill(UInt8(1), bytes)
                                shape = Int32[bytes]
                                strides = Int32[1]
                                published = 0

                                try
                                    ready_deadline = time_ns() + Int64(2e9)
                                    next_announce = Int64(0)
                                    while time_ns() < ready_deadline
                                        if bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing &&
                                           consumer_dst_agent.state.mappings.header_mmap !== nothing
                                            break
                                        end
                                        now_ns = time_ns()
                                        if now_ns >= next_announce
                                            fetch!(producer_src_agent.state.clock)
                                            Producer.emit_announce!(producer_src_agent.state)
                                            fetch!(bridge_agent.receiver.producer_state.clock)
                                            Producer.emit_announce!(bridge_agent.receiver.producer_state)
                                            next_announce = now_ns + Int64(50_000_000)
                                        end
                                        yield()
                                    end
                                    if bridge_agent.sender.consumer_state.mappings.header_mmap === nothing ||
                                       consumer_dst_agent.state.mappings.header_mmap === nothing
                                        println("Bridge runner benchmark: mappings not ready before start")
                                    end

                                    if warmup_s > 0
                                        warmup_start = time_ns()
                                        warmup_limit = warmup_start + Int64(round(warmup_s * 1e9))
                                        while time_ns() < warmup_limit
                                            if bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing && do_publish
                                                Producer.offer_frame!(
                                                    producer_src_agent.state,
                                                    payload,
                                                    shape,
                                                    strides,
                                                    Dtype.UINT8,
                                                    UInt32(0),
                                                )
                                            end
                                            yield()
                                        end
                                        consumed[] = 0
                                        published = 0
                                    end

                                    if alloc_probe_iters > 0
                                        GC.gc()
                                        probe_start = Base.gc_num().allocd
                                        for _ in 1:alloc_probe_iters
                                            if bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing && do_publish
                                                Producer.offer_frame!(
                                                    producer_src_agent.state,
                                                    payload,
                                                    shape,
                                                    strides,
                                                    Dtype.UINT8,
                                                    UInt32(0),
                                                )
                                            end
                                            yield()
                                        end
                                        probe_end = Base.gc_num().allocd
                                        println("Alloc delta (probe $(alloc_probe_iters) iters): $(probe_end - probe_start) bytes")
                                        consumed[] = 0
                                        published = 0
                                    end

                                    GC.gc()
                                    gc_num_overhead = Base.gc_num().allocd
                                    gc_num_overhead = Base.gc_num().allocd - gc_num_overhead
                                    time_overhead = Base.gc_num().allocd
                                    _ = time_ns()
                                    time_overhead = Base.gc_num().allocd - time_overhead
                                    start_num = Base.gc_num()
                                    start_live = Base.gc_live_bytes()
                                    start = time_ns()
                                    iter_count = 0
                                    if fixed_iters > 0
                                        while iter_count < fixed_iters
                                            if !noop_loop
                                                if do_publish && bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing
                                                    Producer.offer_frame!(
                                                        producer_src_agent.state,
                                                        payload,
                                                        shape,
                                                        strides,
                                                        Dtype.UINT8,
                                                        UInt32(0),
                                                    )
                                                    published += 1
                                                end
                                            end
                                            iter_count += 1
                                            do_yield && yield()
                                        end
                                    else
                                        end_limit = start + Int64(round(duration_s * 1e9))
                                        while time_ns() < end_limit
                                            if !noop_loop
                                                if do_publish && bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing
                                                    Producer.offer_frame!(
                                                        producer_src_agent.state,
                                                        payload,
                                                        shape,
                                                        strides,
                                                        Dtype.UINT8,
                                                        UInt32(0),
                                                    )
                                                    published += 1
                                                end
                                            end
                                            do_yield && yield()
                                        end
                                    end

                                    elapsed = (time_ns() - start) / 1e9
                                    mid_num = Base.gc_num()
                                    mid_live = Base.gc_live_bytes()
                                    GC.gc()
                                    end_num = Base.gc_num()
                                    end_live = Base.gc_live_bytes()
                                    allocd_loop_raw = mid_num.allocd - start_num.allocd
                                    allocd_loop = max(Int64(0), allocd_loop_raw - gc_num_overhead - time_overhead)
                                    live_loop = mid_live - start_live
                                    allocd_total_raw = end_num.allocd - start_num.allocd
                                    allocd_total = max(Int64(0), allocd_total_raw - (2 * gc_num_overhead + time_overhead))
                                    live_total = end_live - start_live
                                    publish_rate = published / elapsed
                                    consume_rate = consumed[] / elapsed
                                    bytes_per_frame = Float64(bytes)
                                    publish_mib_s = (publish_rate * bytes_per_frame) / (1024.0 * 1024.0)
                                    consume_mib_s = (consume_rate * bytes_per_frame) / (1024.0 * 1024.0)
                                    println("Bridge benchmark (runners): payload_bytes=$(bytes)")
                                    println("Published: $(published) frames in $(round(elapsed, digits=3))s")
                                    println("Consumed:  $(consumed[]) frames in $(round(elapsed, digits=3))s")
                                    println("Publish rate: $(round(publish_rate, digits=1)) fps")
                                    println("Consume rate: $(round(consume_rate, digits=1)) fps")
                                    println("Publish bandwidth: $(round(publish_mib_s, digits=1)) MiB/s")
                                    println("Consume bandwidth: $(round(consume_mib_s, digits=1)) MiB/s")
                                    println("GC allocd overhead per sample: $(gc_num_overhead) bytes")
                                    println("GC allocd overhead per time_ns(): $(time_overhead) bytes")
                                    println("GC allocd delta (loop):  $(allocd_loop) bytes")
                                    println("GC live delta (loop):   $(live_loop) bytes")
                                    println("GC allocd delta (total): $(allocd_total) bytes")
                                    println("GC live delta (total):  $(live_total) bytes")
                                    println()
                                finally
                                    close(runner_dst)
                                    close(runner_src)
                                    wait(runner_dst)
                                    wait(runner_src)
                                end
                            end
                        end
                    end
                end
            end
            return nothing
        end
    end
end

function run_bridge_bench(
    config_path::AbstractString,
    duration_s::Float64;
    payload_bytes::Int = 1024,
    payload_bytes_list::Vector{Int} = Int[],
    warmup_s::Float64 = 0.2,
    alloc_sample::Bool = false,
    alloc_probe_iters::Int = 0,
    fixed_iters::Int = 0,
    alloc_breakdown::Bool = false,
    noop_loop::Bool = false,
    do_yield::Bool = true,
    poll_timers::Bool = true,
    do_publish::Bool = true,
    poll_subs::Bool = true,
)
    Aeron.MediaDriver.launch_embedded() do driver
        GC.@preserve driver begin
            Aeron.Context() do context
                Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
                Aeron.Client(context) do client
                    env = Dict(ENV)
                    env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
                    driver_cfg = load_driver_config(config_path; env = env)
                    stream, profile = stream_profile_from_driver(driver_cfg)
                    control_stream_id = driver_cfg.endpoints.control_stream_id
                    qos_stream_id = driver_cfg.endpoints.qos_stream_id
                    pools = [
                        PayloadPoolConfig(pool.pool_id, "", pool.stride_bytes, profile.header_nslots)
                        for pool in profile.payload_pools
                    ]
                    base_producer_cfg = default_producer_config(
                        ;
                        aeron_dir = env["AERON_DIR"],
                        stream_id = stream.stream_id,
                        nslots = profile.header_nslots,
                        payload_pools = pools,
                        shm_base_dir = "/dev/shm",
                        producer_instance_id = "bench-src",
                        control_stream_id = control_stream_id,
                        qos_stream_id = qos_stream_id,
                    )
                    base_consumer_cfg = default_consumer_config(
                        ;
                        aeron_dir = env["AERON_DIR"],
                        stream_id = stream.stream_id,
                        shm_base_dir = "/dev/shm",
                        control_stream_id = control_stream_id,
                        qos_stream_id = qos_stream_id,
                    )
                    sizes = isempty(payload_bytes_list) ? [payload_bytes] : payload_bytes_list

                    src_stream_id = base_producer_cfg.stream_id
                    dst_stream_id = src_stream_id + UInt32(1)
                    src_descriptor = base_producer_cfg.descriptor_stream_id
                    src_control = base_producer_cfg.control_stream_id
                    src_qos = base_producer_cfg.qos_stream_id
                    src_meta = base_producer_cfg.metadata_stream_id
                    dst_descriptor = src_descriptor + Int32(1000)
                    dst_control = src_control + Int32(1000)
                    dst_qos = src_qos + Int32(1000)
                    dst_meta = src_meta + Int32(1000)

                    for bytes in sizes
                        bytes > 0 || error("payload_bytes must be > 0")
                        mktempdir() do src_dir
                            mktempdir() do dst_dir
                                src_producer_cfg = override_producer_streams(
                                    base_producer_cfg;
                                    stream_id = src_stream_id,
                                    descriptor_stream_id = src_descriptor,
                                    control_stream_id = src_control,
                                    qos_stream_id = src_qos,
                                    metadata_stream_id = src_meta,
                                    producer_id = base_producer_cfg.producer_id,
                                    producer_instance_id = "bench-src",
                                )
                                dst_producer_cfg = override_producer_streams(
                                    base_producer_cfg;
                                    stream_id = dst_stream_id,
                                    descriptor_stream_id = dst_descriptor,
                                    control_stream_id = dst_control,
                                    qos_stream_id = dst_qos,
                                    metadata_stream_id = dst_meta,
                                    producer_id = base_producer_cfg.producer_id + UInt32(1),
                                    producer_instance_id = "bench-dst",
                                )
                                producer_src_cfg = apply_canonical_layout(
                                    src_producer_cfg,
                                    src_dir;
                                    producer_instance_id = "bench-src",
                                )
                                producer_dst_cfg = apply_canonical_layout(
                                    dst_producer_cfg,
                                    dst_dir;
                                    producer_instance_id = "bench-dst",
                                )
                                producer_src_agent = ProducerAgent(producer_src_cfg; client = client)

                                bridge_consumer_cfg = override_consumer_streams(
                                    base_consumer_cfg;
                                    stream_id = src_stream_id,
                                    descriptor_stream_id = src_descriptor,
                                    control_stream_id = src_control,
                                    qos_stream_id = src_qos,
                                    consumer_id = base_consumer_cfg.consumer_id + UInt32(2),
                                )
                                consumer_dst_cfg = override_consumer_streams(
                                    base_consumer_cfg;
                                    stream_id = dst_stream_id,
                                    descriptor_stream_id = dst_descriptor,
                                    control_stream_id = dst_control,
                                    qos_stream_id = dst_qos,
                                    consumer_id = base_consumer_cfg.consumer_id + UInt32(1),
                                )
                                bridge_consumer_cfg = apply_canonical_layout(bridge_consumer_cfg, src_dir)
                                consumer_dst_cfg = apply_canonical_layout(consumer_dst_cfg, dst_dir)

                                bridge_cfg = BridgeConfig(
                                    "bridge-bench",
                                    Aeron.MediaDriver.aeron_dir(driver),
                                    "aeron:ipc",
                                    Int32(3100),
                                    "aeron:ipc",
                                    Int32(3000),
                                    "",
                                    Int32(0),
                                    Int32(0),
                                    UInt32(1408),
                                    UInt32(1024),
                                    UInt32(0),
                                    UInt32(max(bytes, 1)),
                                    UInt64(250_000_000),
                                    false,
                                    false,
                                    false,
                                )
                                mapping =
                                    BridgeMapping(UInt32(src_stream_id), UInt32(dst_stream_id), "bench", UInt32(0), Int32(0), Int32(0))
                                consumed = Ref(0)
                                consumer_callbacks = let consumed = consumed
                                    ConsumerCallbacks(; on_frame! = (_, _) -> (consumed[] += 1))
                                end
                                consumer_dst_agent =
                                    ConsumerAgent(consumer_dst_cfg; client = client, callbacks = consumer_callbacks)
                                bridge_agent = BridgeAgent(
                                    bridge_cfg,
                                    mapping,
                                    bridge_consumer_cfg,
                                    producer_dst_cfg;
                                    client = client,
                                )
                                producer_dst_work = let st = bridge_agent.receiver.producer_state
                                    ProducerWork(
                                        st,
                                        Producer.make_control_assembler(st),
                                        Producer.make_qos_assembler(st),
                                    )
                                end
                                producer_invoker = AgentInvoker(producer_src_agent)
                                bridge_invoker = AgentInvoker(bridge_agent)
                                consumer_invoker = AgentInvoker(consumer_dst_agent)
                                producer_dst_invoker = AgentInvoker(producer_dst_work)
                                Agent.start(producer_invoker)
                                Agent.start(bridge_invoker)
                                Agent.start(consumer_invoker)
                                Agent.start(producer_dst_invoker)

                                payload = fill(UInt8(1), bytes)
                                shape = Int32[bytes]
                                strides = Int32[1]
                                published = 0

                                wait_start = time_ns()
                                wait_limit = wait_start + Int64(2e9)
                                while (bridge_agent.sender.consumer_state.mappings.header_mmap === nothing ||
                                       consumer_dst_agent.state.mappings.header_mmap === nothing) &&
                                      time_ns() < wait_limit
                                    Agent.invoke(producer_invoker)
                                    Agent.invoke(bridge_invoker)
                                    Agent.invoke(consumer_invoker)
                                    Agent.invoke(producer_dst_invoker)
                                    yield()
                                end

                                if warmup_s > 0
                                    warmup_start = time_ns()
                                    warmup_limit = warmup_start + Int64(round(warmup_s * 1e9))
                                    while time_ns() < warmup_limit
                                        Agent.invoke(producer_invoker)
                                        Agent.invoke(bridge_invoker)
                                        Agent.invoke(consumer_invoker)
                                        Agent.invoke(producer_dst_invoker)
                                        if bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing && do_publish
                                            Producer.offer_frame!(
                                                producer_src_agent.state,
                                                payload,
                                                shape,
                                                strides,
                                                Dtype.UINT8,
                                                UInt32(0),
                                            )
                                        end
                                        yield()
                                    end
                                    consumed[] = 0
                                    published = 0
                                end

                                if alloc_probe_iters > 0
                                    GC.gc()
                                    probe_start = Base.gc_num().allocd
                                    for _ in 1:alloc_probe_iters
                                        Agent.invoke(producer_invoker)
                                        Agent.invoke(bridge_invoker)
                                        Agent.invoke(consumer_invoker)
                                        Agent.invoke(producer_dst_invoker)
                                        if bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing && do_publish
                                            Producer.offer_frame!(
                                                producer_src_agent.state,
                                                payload,
                                                shape,
                                                strides,
                                                Dtype.UINT8,
                                                UInt32(0),
                                            )
                                        end
                                        yield()
                                    end
                                    probe_end = Base.gc_num().allocd
                                    println("Alloc delta (probe $(alloc_probe_iters) iters): $(probe_end - probe_start) bytes")
                                    consumed[] = 0
                                    published = 0
                                end

                                GC.gc()
                                gc_num_overhead = Base.gc_num().allocd
                                gc_num_overhead = Base.gc_num().allocd - gc_num_overhead
                                time_overhead = Base.gc_num().allocd
                                _ = time_ns()
                                time_overhead = Base.gc_num().allocd - time_overhead
                                start_num = Base.gc_num()
                                start_live = Base.gc_live_bytes()
                                start = time_ns()
                                iter_count = 0
                                if fixed_iters > 0
                                    while iter_count < fixed_iters
                                        if !noop_loop
                                            Agent.invoke(producer_invoker)
                                            Agent.invoke(bridge_invoker)
                                            Agent.invoke(consumer_invoker)
                                            Agent.invoke(producer_dst_invoker)
                                            if do_publish && bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing
                                                Producer.offer_frame!(
                                                    producer_src_agent.state,
                                                    payload,
                                                    shape,
                                                    strides,
                                                    Dtype.UINT8,
                                                    UInt32(0),
                                                )
                                                published += 1
                                            end
                                        end
                                        iter_count += 1
                                        do_yield && yield()
                                    end
                                else
                                    end_limit = start + Int64(round(duration_s * 1e9))
                                    while time_ns() < end_limit
                                        if !noop_loop
                                            Agent.invoke(producer_invoker)
                                            Agent.invoke(bridge_invoker)
                                            Agent.invoke(consumer_invoker)
                                            Agent.invoke(producer_dst_invoker)
                                            if do_publish && bridge_agent.sender.consumer_state.mappings.header_mmap !== nothing
                                                Producer.offer_frame!(
                                                    producer_src_agent.state,
                                                    payload,
                                                    shape,
                                                    strides,
                                                    Dtype.UINT8,
                                                    UInt32(0),
                                                )
                                                published += 1
                                            end
                                        end
                                        do_yield && yield()
                                    end
                                end

                                elapsed = (time_ns() - start) / 1e9
                                mid_num = Base.gc_num()
                                mid_live = Base.gc_live_bytes()
                                GC.gc()
                                end_num = Base.gc_num()
                                end_live = Base.gc_live_bytes()
                                allocd_loop_raw = mid_num.allocd - start_num.allocd
                                allocd_loop = max(Int64(0), allocd_loop_raw - gc_num_overhead - time_overhead)
                                live_loop = mid_live - start_live
                                allocd_total_raw = end_num.allocd - start_num.allocd
                                allocd_total = max(Int64(0), allocd_total_raw - (2 * gc_num_overhead + time_overhead))
                                live_total = end_live - start_live
                                publish_rate = published / elapsed
                                consume_rate = consumed[] / elapsed
                                bytes_per_frame = Float64(bytes)
                                publish_mib_s = (publish_rate * bytes_per_frame) / (1024.0 * 1024.0)
                                consume_mib_s = (consume_rate * bytes_per_frame) / (1024.0 * 1024.0)
                                println("Bridge benchmark: payload_bytes=$(bytes)")
                                println("Published: $(published) frames in $(round(elapsed, digits=3))s")
                                println("Consumed:  $(consumed[]) frames in $(round(elapsed, digits=3))s")
                                println("Publish rate: $(round(publish_rate, digits=1)) fps")
                                println("Consume rate: $(round(consume_rate, digits=1)) fps")
                                println("Publish bandwidth: $(round(publish_mib_s, digits=1)) MiB/s")
                                println("Consume bandwidth: $(round(consume_mib_s, digits=1)) MiB/s")
                                println("GC allocd overhead per sample: $(gc_num_overhead) bytes")
                                println("GC allocd overhead per time_ns(): $(time_overhead) bytes")
                                println("GC allocd delta (loop):  $(allocd_loop) bytes")
                                println("GC live delta (loop):   $(live_loop) bytes")
                                println("GC allocd delta (total): $(allocd_total) bytes")
                                println("GC live delta (total):  $(live_total) bytes")
                                println()

                                close(bridge_invoker)
                                close(consumer_invoker)
                                close(producer_invoker)
                                close(producer_dst_invoker)
                            end
                        end
                    end
                end
            end
            return nothing
        end
    end
end
