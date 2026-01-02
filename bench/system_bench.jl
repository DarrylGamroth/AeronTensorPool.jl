using Aeron
using AeronTensorPool
using Clocks

function ensure_shm_dir(uri::AbstractString)
    parsed = AeronTensorPool.parse_shm_uri(uri)
    mkpath(dirname(parsed.path))
    return nothing
end

function close_producer!(producer)
    close(producer.runtime.pub_descriptor)
    close(producer.runtime.pub_control)
    close(producer.runtime.pub_qos)
    close(producer.runtime.pub_metadata)
    close(producer.runtime.sub_control)
    close(producer.runtime.client)
    close(producer.runtime.ctx)
    return nothing
end

function close_consumer!(consumer)
    close(consumer.runtime.pub_control)
    close(consumer.runtime.pub_qos)
    close(consumer.runtime.sub_descriptor)
    close(consumer.runtime.sub_control)
    close(consumer.runtime.sub_qos)
    close(consumer.runtime.client)
    close(consumer.runtime.ctx)
    return nothing
end

function close_supervisor!(supervisor)
    close(supervisor.runtime.pub_control)
    close(supervisor.runtime.sub_control)
    close(supervisor.runtime.sub_qos)
    close(supervisor.runtime.client)
    close(supervisor.runtime.ctx)
    return nothing
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
            env = Dict(ENV)
            env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
            system = load_system_config(config_path; env = env)
            sizes = isempty(payload_bytes_list) ? [payload_bytes] : payload_bytes_list
            for bytes in sizes
                bytes > 0 || error("payload_bytes must be > 0")
                mktempdir() do dir
                    producer_cfg = apply_canonical_layout(system.producer, dir)
                    consumer_cfg = apply_canonical_layout(system.consumer, dir)
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
                            FrameDescriptor.wrap!(st.runtime.desc_decoder, buffer, 0; header = header)
                            try_read_frame!(st, st.runtime.desc_decoder) && (consumed[] += 1)
                        end
                        nothing
                    end)

                    payload = fill(UInt8(1), bytes)
                    shape = Int32[bytes]
                    strides = Int32[1]
                    published = 0
                    if warmup_s > 0
                        warmup_start = time()
                        while time() - warmup_start < warmup_s
                            producer_do_work!(producer, prod_ctrl)
                            consumer_do_work!(consumer, cons_desc, cons_ctrl)
                            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                            if consumer.mappings.header_mmap !== nothing
                                publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                            yield()
                        end
                        consumed[] = 0
                        published = 0
                    end

                    if alloc_sample
                        wait_start = time()
                        while consumer.mappings.header_mmap === nothing && (time() - wait_start < 2.0)
                            producer_do_work!(producer, prod_ctrl)
                            consumer_do_work!(consumer, cons_desc, cons_ctrl)
                            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                            yield()
                        end
                        for _ in 1:32
                            producer_do_work!(producer, prod_ctrl)
                            consumer_do_work!(consumer, cons_desc, cons_ctrl)
                            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                            if consumer.mappings.header_mmap !== nothing
                                publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                            yield()
                        end
                        sample_before = Base.gc_num().allocd
                        producer_do_work!(producer, prod_ctrl)
                        consumer_do_work!(consumer, cons_desc, cons_ctrl)
                        supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                        if consumer.mappings.header_mmap !== nothing
                            publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                        end
                        sample_after = Base.gc_num().allocd
                        println("Sample alloc per-iteration: $(sample_after - sample_before) bytes")
                    end

                    if alloc_breakdown
                        wait_start = time()
                        while consumer.mappings.header_mmap === nothing && (time() - wait_start < 2.0)
                            producer_do_work!(producer, prod_ctrl)
                            consumer_do_work!(consumer, cons_desc, cons_ctrl)
                            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                            yield()
                        end
                        for _ in 1:32
                            producer_do_work!(producer, prod_ctrl)
                            consumer_do_work!(consumer, cons_desc, cons_ctrl)
                            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                            if consumer.mappings.header_mmap !== nothing
                                publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
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
                            producer_do_work!(producer, prod_ctrl)
                        end
                        measure_allocd("consumer_do_work") do
                            consumer_do_work!(consumer, cons_desc, cons_ctrl)
                        end
                        if consumer.mappings.header_mmap !== nothing
                            publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            measure_allocd("consumer_do_work (with frame)") do
                                consumer_do_work!(consumer, cons_desc, cons_ctrl)
                            end
                        end
                        measure_allocd("supervisor_do_work") do
                            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                        end
                        measure_allocd("publish_frame") do
                            if consumer.mappings.header_mmap !== nothing
                                publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                            end
                        end
                        measure_allocd("producer_poll_timers") do
                            Clocks.fetch!(producer.clock)
                            now_ns = UInt64(Clocks.time_nanos(producer.clock)) + producer.config.announce_interval_ns
                            poll_timers!(producer, now_ns)
                        end
                        measure_allocd("consumer_poll_timers") do
                            Clocks.fetch!(consumer.clock)
                            now_ns = UInt64(Clocks.time_nanos(consumer.clock)) + consumer.config.hello_interval_ns
                            poll_timers!(consumer, now_ns)
                        end
                        measure_allocd("emit_consumer_hello") do
                            emit_consumer_hello!(consumer)
                        end
                        measure_allocd("emit_consumer_qos") do
                            emit_qos!(consumer)
                        end
                        measure_allocd("supervisor_poll_timers") do
                            Clocks.fetch!(supervisor.clock)
                            now_ns = UInt64(Clocks.time_nanos(supervisor.clock)) + supervisor.config.liveness_check_interval_ns
                            poll_timers!(supervisor, now_ns)
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
                            producer_do_work!(producer, prod_ctrl)
                            consumer_do_work!(consumer, cons_desc, cons_ctrl)
                            supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                            if consumer.mappings.header_mmap !== nothing
                                publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
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
                    _ = time()
                    time_overhead = Base.gc_num().allocd - time_overhead
                    start_num = Base.gc_num()
                    start_live = Base.gc_live_bytes()
                    start = time()
                    iter_count = 0
                    if fixed_iters > 0
                        while iter_count < fixed_iters
                            if !noop_loop
                                if poll_subs
                                    work = 0
                                    work += poll_control!(producer, prod_ctrl)
                                    work += poll_descriptor!(consumer, cons_desc)
                                    work += poll_control!(consumer, cons_ctrl)
                                    work += poll_control!(supervisor, sup_ctrl)
                                    work += poll_qos!(supervisor, sup_qos)
                                end
                                if poll_timers
                                    Clocks.fetch!(producer.clock)
                                    now_ns = UInt64(Clocks.time_nanos(producer.clock))
                                    poll_timers!(producer, now_ns)
                                    Clocks.fetch!(consumer.clock)
                                    now_ns = UInt64(Clocks.time_nanos(consumer.clock))
                                    poll_timers!(consumer, now_ns)
                                    Clocks.fetch!(supervisor.clock)
                                    now_ns = UInt64(Clocks.time_nanos(supervisor.clock))
                                    poll_timers!(supervisor, now_ns)
                                end
                                if !poll_subs && !poll_timers
                                    producer_do_work!(producer, prod_ctrl)
                                    consumer_do_work!(consumer, cons_desc, cons_ctrl)
                                    supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                                end

                                if do_publish && consumer.mappings.header_mmap !== nothing
                                    publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                                    published += 1
                                end
                            end
                            iter_count += 1
                            do_yield && yield()
                        end
                    else
                        while time() - start < duration_s
                            if !noop_loop
                                if poll_subs
                                    work = 0
                                    work += poll_control!(producer, prod_ctrl)
                                    work += poll_descriptor!(consumer, cons_desc)
                                    work += poll_control!(consumer, cons_ctrl)
                                    work += poll_control!(supervisor, sup_ctrl)
                                    work += poll_qos!(supervisor, sup_qos)
                                end
                                if poll_timers
                                    Clocks.fetch!(producer.clock)
                                    now_ns = UInt64(Clocks.time_nanos(producer.clock))
                                    poll_timers!(producer, now_ns)
                                    Clocks.fetch!(consumer.clock)
                                    now_ns = UInt64(Clocks.time_nanos(consumer.clock))
                                    poll_timers!(consumer, now_ns)
                                    Clocks.fetch!(supervisor.clock)
                                    now_ns = UInt64(Clocks.time_nanos(supervisor.clock))
                                    poll_timers!(supervisor, now_ns)
                                end
                                if !poll_subs && !poll_timers
                                    producer_do_work!(producer, prod_ctrl)
                                    consumer_do_work!(consumer, cons_desc, cons_ctrl)
                                    supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
                                end

                                if do_publish && consumer.mappings.header_mmap !== nothing
                                    publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                                    published += 1
                                end
                            end
                            do_yield && yield()
                        end
                    end

                    elapsed = time() - start
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
                    println("System benchmark: payload_bytes=$(bytes)")
                    println("Published: $(published) frames in $(round(elapsed, digits=3))s")
                    println("Consumed:  $(consumed[]) frames in $(round(elapsed, digits=3))s")
                    println("Publish rate: $(round(published / elapsed, digits=1)) fps")
                    println("Consume rate: $(round(consumed[] / elapsed, digits=1)) fps")
                    println("GC allocd overhead per sample: $(gc_num_overhead) bytes")
                    println("GC allocd overhead per time(): $(time_overhead) bytes")
                    println("GC allocd delta (loop):  $(allocd_loop) bytes")
                    println("GC live delta (loop):   $(live_loop) bytes")
                    println("GC allocd delta (total): $(allocd_total) bytes")
                    println("GC live delta (total):  $(live_total) bytes")
                    println()

                    close_supervisor!(supervisor)
                    close_consumer!(consumer)
                    close_producer!(producer)
                end
            end
            return nothing
        end
    end
end
