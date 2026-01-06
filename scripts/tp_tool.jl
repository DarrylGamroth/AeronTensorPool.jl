using Aeron
using AeronTensorPool

function usage()
    println("Usage:")
    println("  julia --project scripts/tp_tool.jl validate-uri <uri>")
    println("  julia --project scripts/tp_tool.jl read-superblock <uri>")
    println("  julia --project scripts/tp_tool.jl read-header <uri> <index>")
    println("  julia --project scripts/tp_tool.jl send-consumer-config <aeron_dir> <aeron_uri> <control_stream_id> <stream_id> <consumer_id> <use_shm> <mode> [payload_fallback_uri]")
    println("  julia --project scripts/tp_tool.jl driver-attach <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> [publish_mode] [expected_layout_version] [require_hugepages_policy] [timeout_ms]")
    println("  julia --project scripts/tp_tool.jl driver-detach <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> <lease_id> [timeout_ms]")
    println("  julia --project scripts/tp_tool.jl driver-keepalive <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> <lease_id>")
    println("  julia --project scripts/tp_tool.jl driver-status <driver_instance_id>")
    println("  julia --project scripts/tp_tool.jl driver-list-leases <driver_instance_id>")
    println("  julia --project scripts/tp_tool.jl driver-list-streams <driver_instance_id>")
    println("  julia --project scripts/tp_tool.jl driver-counters <aeron_dir> [filter]")
    println("  julia --project scripts/tp_tool.jl driver-config-validate <config_path>")
    println("  julia --project scripts/tp_tool.jl driver-config-dump <config_path>")
    println("  julia --project scripts/tp_tool.jl shm-validate <uri> <layout_version> <epoch> <stream_id> <nslots> <slot_bytes> <region_type> <pool_id>")
    println("  julia --project scripts/tp_tool.jl shm-summary <uri>")
    println("  julia --project scripts/tp_tool.jl announce-listen <aeron_dir> <channel> <stream_id> [duration_s]")
    println("  julia --project scripts/tp_tool.jl discovery-query <aeron_dir> <request_channel> <request_stream_id> <response_channel> <response_stream_id> [stream_id] [producer_id] [data_source_id] [data_source_name] [tags_csv] [timeout_ms]")
    println("  julia --project scripts/tp_tool.jl bridge-status <aeron_dir> [filter]")
    println("  julia --project scripts/tp_tool.jl discover <aeron_dir> <request_channel> <request_stream_id> <response_channel> <response_stream_id> [stream_id] [producer_id] [data_source_id] [data_source_name] [tags_csv] [timeout_ms]")
    exit(1)
end

function parse_bool(val::String)
    val == "true" && return true
    val == "false" && return false
    error("invalid bool: $val")
end

function parse_mode(val::String)
    v = lowercase(val)
    v == "stream" && return Mode.STREAM
    v == "rate_limited" && return Mode.RATE_LIMITED
    error("invalid mode: $val")
end

function parse_role(val::String)
    v = lowercase(val)
    v == "producer" && return DriverRole.PRODUCER
    v == "consumer" && return DriverRole.CONSUMER
    error("invalid role: $val")
end

function parse_publish_mode(val::String)
    v = lowercase(val)
    v == "require_existing" && return DriverPublishMode.REQUIRE_EXISTING
    v == "allow_create" && return DriverPublishMode.ALLOW_CREATE
    error("invalid publish_mode: $val")
end

function parse_hugepages_policy(val::String)
    v = lowercase(val)
    v == "hugepages" && return DriverHugepagesPolicy.HUGEPAGES
    v == "standard" && return DriverHugepagesPolicy.STANDARD
    v == "unspecified" && return DriverHugepagesPolicy.UNSPECIFIED
    v == "true" && return DriverHugepagesPolicy.HUGEPAGES
    v == "false" && return DriverHugepagesPolicy.STANDARD
    v == "unset" && return DriverHugepagesPolicy.UNSPECIFIED
    error("invalid hugepages policy: $val (use hugepages|standard|unspecified|true|false|unset)")
end

function parse_region_type(val::String)
    v = lowercase(val)
    v == "header" && return RegionType.HEADER_RING
    v == "payload" && return RegionType.PAYLOAD_POOL
    error("invalid region_type: $val (use header|payload)")
end

function with_driver_client(
    f::Function,
    aeron_dir::String,
    control_channel::String,
    control_stream::Int32,
    client_id::UInt32,
    role::DriverRole.SbeEnum,
)
    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, aeron_dir)
    client = Aeron.Client(ctx)
    state = init_driver_client(client, control_channel, control_stream, client_id, role)
    try
        return f(state)
    finally
        try
            close(state.pub)
            close(state.sub)
            close(client)
            close(ctx)
        catch
        end
    end
end

function with_aeron_client(f::Function, aeron_dir::String)
    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, aeron_dir)
    client = Aeron.Client(ctx)
    try
        return f(client)
    finally
        try
            close(client)
            close(ctx)
        catch
        end
    end
end

function print_counters(aeron_dir::String; filter::String = "")
    with_aeron_client(aeron_dir) do client
        reader = Aeron.CountersReader(client)
        Aeron.counter_foreach(reader) do value, counter_id, type_id, _, label, _
            label_str = String(label)
            if isempty(filter) || occursin(filter, label_str)
                println("id=$(counter_id) type=$(type_id) value=$(value) label=$(label_str)")
            end
            nothing
        end
    end
end

function with_discovery_client(
    f::Function,
    aeron_dir::String,
    request_channel::String,
    request_stream_id::Int32,
    response_channel::String,
    response_stream_id::UInt32,
    client_id::UInt32,
)
    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, aeron_dir)
    client = Aeron.Client(ctx)
    state = init_discovery_client(
        client,
        request_channel,
        request_stream_id,
        response_channel,
        response_stream_id,
        client_id,
    )
    try
        return f(state)
    finally
        try
            close(state.pub)
            close(state.sub)
            close(client)
            close(ctx)
        catch
        end
    end
end

function wait_for_discovery_response(
    client::DiscoveryClientState,
    request_id::UInt64;
    timeout_ms::Int = 5000,
)
    deadline = time_ns() + Int64(timeout_ms) * 1_000_000
    while time_ns() < deadline
        slot = poll_discovery_response!(client, request_id)
        if slot !== nothing
            return slot
        end
        yield()
    end
    return nothing
end

function print_driver_status(state::DriverState)
    status = driver_status_snapshot(state)
    println("instance_id=$(status.instance_id)")
    println("lifecycle=$(status.lifecycle)")
    println("shutdown_reason=$(status.shutdown_reason)")
    println("shutdown_message=$(status.shutdown_message)")
    println("stream_count=$(status.stream_count)")
    println("lease_count=$(status.lease_count)")
    println("next_stream_id=$(status.next_stream_id)")
    println("next_lease_id=$(status.next_lease_id)")
    if status.stream_id_range !== nothing
        println("stream_id_range=$(status.stream_id_range)")
    end
    if status.descriptor_stream_id_range !== nothing
        println("descriptor_stream_id_range=$(status.descriptor_stream_id_range)")
    end
    if status.control_stream_id_range !== nothing
        println("control_stream_id_range=$(status.control_stream_id_range)")
    end
end

function print_driver_leases(state::DriverState)
    leases = driver_leases_snapshot(state)
    println("leases=$(length(leases))")
    for lease in leases
        println(
            "lease_id=$(lease.lease_id) stream_id=$(lease.stream_id) client_id=$(lease.client_id) role=$(lease.role) expiry_ns=$(lease.expiry_ns) state=$(lease.lifecycle)",
        )
    end
end

function print_driver_streams(state::DriverState)
    streams = driver_streams_snapshot(state)
    println("streams=$(length(streams))")
    for stream in streams
        println("stream_id=$(stream.stream_id) profile=$(stream.profile) epoch=$(stream.epoch)")
        println("header_uri=$(stream.header_uri)")
        println("producer_lease_id=$(stream.producer_lease_id)")
        if !isempty(stream.consumer_lease_ids)
            println("consumer_lease_ids=$(join(stream.consumer_lease_ids, ','))")
        end
        if !isempty(stream.pool_uris)
            for (pool_id, uri) in stream.pool_uris
                println("pool_id=$(pool_id) uri=$(uri)")
            end
        end
    end
    assigned = driver_assigned_streams_snapshot(state)
    if !isempty(assigned)
        println("assigned_streams=$(length(assigned))")
        for entry in assigned
            println(
                "consumer_id=$(entry.consumer_id) descriptor_stream_id=$(entry.descriptor_stream_id) control_stream_id=$(entry.control_stream_id)",
            )
        end
    end
end

function find_driver_or_error(instance_id::String)
    state = find_driver_state(instance_id)
    state === nothing && error("driver instance not found in local registry: $instance_id")
    return state
end

function wait_for_response(
    client::DriverClientState,
    correlation_id::Int64;
    timeout_ms::Int = 5000,
)
    deadline = time_ns() + Int64(timeout_ms) * 1_000_000
    while time_ns() < deadline
        driver_client_do_work!(client, UInt64(time_ns()))
        attach = client.poller.last_attach
        if attach !== nothing && attach.correlation_id == correlation_id
            return attach
        end
        detach = client.poller.last_detach
        if detach !== nothing && detach.correlation_id == correlation_id
            return detach
        end
        yield()
    end
    return nothing
end

function tp_tool_main(args::Vector{String})
    length(args) >= 1 || usage()
    cmd = args[1]

    if cmd == "validate-uri"
        uri = args[2]
        println(validate_uri(uri))
    elseif cmd == "read-superblock"
        uri = args[2]
        buf = mmap_shm(uri, SUPERBLOCK_SIZE)
        decoder = ShmRegionSuperblock.Decoder(Vector{UInt8})
        wrap_superblock!(decoder, buf)
        fields = read_superblock(decoder)
        println("magic=$(fields.magic)")
        println("layout_version=$(fields.layout_version)")
        println("epoch=$(fields.epoch)")
        println("stream_id=$(fields.stream_id)")
        println("region_type=$(fields.region_type)")
        println("pool_id=$(fields.pool_id)")
        println("nslots=$(fields.nslots)")
        println("slot_bytes=$(fields.slot_bytes)")
        println("stride_bytes=$(fields.stride_bytes)")
        println("pid=$(fields.pid)")
        println("start_timestamp_ns=$(fields.start_timestamp_ns)")
        println("activity_timestamp_ns=$(fields.activity_timestamp_ns)")
    elseif cmd == "read-header"
        length(args) >= 3 || usage()
        uri = args[2]
        index = parse(Int, args[3])
        index >= 0 || error("index must be >= 0")
        size = SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * (index + 1)
        buf = mmap_shm(uri, size)
        offset = header_slot_offset(index)
        decoder = TensorSlotHeaderMsg.Decoder(Vector{UInt8})
        wrap_tensor_header!(decoder, buf, offset)
        header = read_tensor_slot_header(decoder)
        println("seq_commit=$(header.seq_commit)")
        println("seq=$(seqlock_sequence(header.seq_commit))")
        println("timestamp_ns=$(header.timestamp_ns)")
        println("meta_version=$(header.meta_version)")
        println("values_len_bytes=$(header.values_len_bytes)")
        println("payload_slot=$(header.payload_slot)")
        println("payload_offset=$(header.payload_offset)")
        println("pool_id=$(header.pool_id)")
        println("dtype=$(header.dtype)")
        println("major_order=$(header.major_order)")
        println("ndims=$(header.ndims)")
    elseif cmd == "shm-validate"
        length(args) >= 9 || usage()
        uri = args[2]
        expected_layout_version = parse(UInt32, args[3])
        expected_epoch = parse(UInt64, args[4])
        expected_stream_id = parse(UInt32, args[5])
        expected_nslots = parse(UInt32, args[6])
        expected_slot_bytes = parse(UInt32, args[7])
        expected_region_type = parse_region_type(args[8])
        expected_pool_id = parse(UInt16, args[9])
        buf = mmap_shm(uri, SUPERBLOCK_SIZE)
        decoder = ShmRegionSuperblock.Decoder(Vector{UInt8})
        wrap_superblock!(decoder, buf)
        fields = read_superblock(decoder)
        ok = validate_superblock_fields(
            fields;
            expected_layout_version = expected_layout_version,
            expected_epoch = expected_epoch,
            expected_stream_id = expected_stream_id,
            expected_nslots = expected_nslots,
            expected_slot_bytes = expected_slot_bytes,
            expected_region_type = expected_region_type,
            expected_pool_id = expected_pool_id,
        )
        println(ok)
    elseif cmd == "shm-summary"
        uri = args[2]
        buf = mmap_shm(uri, SUPERBLOCK_SIZE)
        decoder = ShmRegionSuperblock.Decoder(Vector{UInt8})
        wrap_superblock!(decoder, buf)
        fields = read_superblock(decoder)
        println("magic=$(fields.magic)")
        println("layout_version=$(fields.layout_version)")
        println("epoch=$(fields.epoch)")
        println("stream_id=$(fields.stream_id)")
        println("region_type=$(fields.region_type)")
        println("pool_id=$(fields.pool_id)")
        println("nslots=$(fields.nslots)")
        println("slot_bytes=$(fields.slot_bytes)")
        println("stride_bytes=$(fields.stride_bytes)")
        println("pid=$(fields.pid)")
        println("start_timestamp_ns=$(fields.start_timestamp_ns)")
        println("activity_timestamp_ns=$(fields.activity_timestamp_ns)")
        path = parse_shm_uri(uri)
        if isfile(path)
            println("file_size=$(stat(path).size)")
        end
    elseif cmd == "send-consumer-config"
        length(args) >= 8 || usage()
        aeron_dir = args[2]
        aeron_uri = args[3]
        control_stream = parse(Int32, args[4])
        stream_id = parse(UInt32, args[5])
        consumer_id = parse(UInt32, args[6])
        use_shm = parse_bool(args[7])
        mode = parse_mode(args[8])
        payload_fallback_uri = length(args) >= 9 ? args[9] : ""

        ctx = Aeron.Context()
        Aeron.aeron_dir!(ctx, aeron_dir)
        client = Aeron.Client(ctx)
        pub = Aeron.add_publication(client, aeron_uri, control_stream)

        buf = Vector{UInt8}(undef, 512)
        enc = ConsumerConfigMsg.Encoder(Vector{UInt8})
        ConsumerConfigMsg.wrap_and_apply_header!(enc, buf, 0)
        ConsumerConfigMsg.streamId!(enc, stream_id)
        ConsumerConfigMsg.consumerId!(enc, consumer_id)
        ConsumerConfigMsg.useShm!(
            enc,
            use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerConfigMsg.mode!(enc, mode)
        ConsumerConfigMsg.payloadFallbackUri!(enc, payload_fallback_uri)

        Aeron.offer(pub, view(buf, 1:sbe_message_length(enc)))
        close(pub)
        close(client)
    elseif cmd == "driver-attach"
        length(args) >= 7 || usage()
        aeron_dir = args[2]
        control_channel = args[3]
        control_stream = parse(Int32, args[4])
        client_id = parse(UInt32, args[5])
        role = parse_role(args[6])
        stream_id = parse(UInt32, args[7])
        publish_mode = length(args) >= 8 ? parse_publish_mode(args[8]) : DriverPublishMode.REQUIRE_EXISTING
        expected_layout_version = length(args) >= 9 ? parse(UInt32, args[9]) : UInt32(0)
        require_hugepages = length(args) >= 10 ? parse_hugepages_policy(args[10]) : DriverHugepagesPolicy.UNSPECIFIED
        timeout_ms = length(args) >= 11 ? parse(Int, args[11]) : 5000

        with_driver_client(aeron_dir, control_channel, control_stream, client_id, role) do client
            correlation_id = send_attach_request!(
                client;
                stream_id = stream_id,
                expected_layout_version = expected_layout_version,
                publish_mode = publish_mode,
                require_hugepages = require_hugepages,
            )
            correlation_id == 0 && error("attach send failed")
            resp = wait_for_response(client, correlation_id; timeout_ms = timeout_ms)
            resp === nothing && error("attach response timed out")
            println("correlation_id=$(resp.correlation_id)")
            println("code=$(resp.code)")
            println("stream_id=$(resp.stream_id)")
            println("epoch=$(resp.epoch)")
            println("layout_version=$(resp.layout_version)")
            println("header_nslots=$(resp.header_nslots)")
            println("header_slot_bytes=$(resp.header_slot_bytes)")
            println("max_dims=$(resp.max_dims)")
            println("header_region_uri=$(resp.header_region_uri)")
            println("lease_id=$(resp.lease_id)")
            println("lease_expiry_ns=$(resp.lease_expiry_ns)")
            println("payload_pools=$(length(resp.pools))")
            for pool in resp.pools
                println("pool_id=$(pool.pool_id) stride_bytes=$(pool.stride_bytes) pool_nslots=$(pool.pool_nslots) uri=$(pool.region_uri)")
            end
            println("error_message=$(resp.error_message)")
        end
    elseif cmd == "driver-detach"
        length(args) >= 8 || usage()
        aeron_dir = args[2]
        control_channel = args[3]
        control_stream = parse(Int32, args[4])
        client_id = parse(UInt32, args[5])
        role = parse_role(args[6])
        stream_id = parse(UInt32, args[7])
        lease_id = parse(UInt64, args[8])
        timeout_ms = length(args) >= 9 ? parse(Int, args[9]) : 5000

        with_driver_client(aeron_dir, control_channel, control_stream, client_id, role) do client
            correlation_id = AeronTensorPool.next_correlation_id!(client)
            sent = send_detach!(
                client.detach_proxy;
                correlation_id = correlation_id,
                lease_id = lease_id,
                stream_id = stream_id,
                client_id = client_id,
                role = role,
            )
            sent || error("detach send failed")
            resp = wait_for_response(client, correlation_id; timeout_ms = timeout_ms)
            resp === nothing && error("detach response timed out")
            println("correlation_id=$(resp.correlation_id)")
            println("code=$(resp.code)")
            println("error_message=$(resp.error_message)")
        end
    elseif cmd == "driver-keepalive"
        length(args) >= 8 || usage()
        aeron_dir = args[2]
        control_channel = args[3]
        control_stream = parse(Int32, args[4])
        client_id = parse(UInt32, args[5])
        role = parse_role(args[6])
        stream_id = parse(UInt32, args[7])
        lease_id = parse(UInt64, args[8])

        with_driver_client(aeron_dir, control_channel, control_stream, client_id, role) do client
            sent = send_keepalive!(
                client.keepalive_proxy;
                lease_id = lease_id,
                stream_id = stream_id,
                client_id = client_id,
                role = role,
                client_timestamp_ns = UInt64(time_ns()),
            )
            println(sent)
        end
    elseif cmd == "driver-status"
        length(args) >= 2 || usage()
        instance_id = args[2]
        state = find_driver_or_error(instance_id)
        print_driver_status(state)
    elseif cmd == "driver-list-leases"
        length(args) >= 2 || usage()
        instance_id = args[2]
        state = find_driver_or_error(instance_id)
        print_driver_leases(state)
    elseif cmd == "driver-list-streams"
        length(args) >= 2 || usage()
        instance_id = args[2]
        state = find_driver_or_error(instance_id)
        print_driver_streams(state)
    elseif cmd == "driver-counters"
        length(args) >= 2 || usage()
        aeron_dir = args[2]
        filter = length(args) >= 3 ? args[3] : "Name=Driver"
        print_counters(aeron_dir; filter = filter)
    elseif cmd == "driver-config-validate"
        length(args) >= 2 || usage()
        config_path = args[2]
        _ = load_driver_config(config_path; env = ENV)
        println("ok")
    elseif cmd == "driver-config-dump"
        length(args) >= 2 || usage()
        config_path = args[2]
        cfg = load_driver_config(config_path; env = ENV)
        println("instance_id=$(cfg.endpoints.instance_id)")
        println("aeron_dir=$(cfg.endpoints.aeron_dir)")
        println("control_channel=$(cfg.endpoints.control_channel)")
        println("control_stream_id=$(cfg.endpoints.control_stream_id)")
        println("announce_channel=$(cfg.endpoints.announce_channel)")
        println("announce_stream_id=$(cfg.endpoints.announce_stream_id)")
        println("qos_channel=$(cfg.endpoints.qos_channel)")
        println("qos_stream_id=$(cfg.endpoints.qos_stream_id)")
        println("prefault_shm=$(cfg.policies.prefault_shm)")
        println("default_profile=$(cfg.policies.default_profile)")
        println("allow_dynamic_streams=$(cfg.policies.allow_dynamic_streams)")
        println("announce_period_ms=$(cfg.policies.announce_period_ms)")
        println("lease_keepalive_interval_ms=$(cfg.policies.lease_keepalive_interval_ms)")
        println("lease_expiry_grace_intervals=$(cfg.policies.lease_expiry_grace_intervals)")
        if cfg.stream_id_range !== nothing
            println("stream_id_range=$(cfg.stream_id_range)")
        end
        if cfg.descriptor_stream_id_range !== nothing
            println("descriptor_stream_id_range=$(cfg.descriptor_stream_id_range)")
        end
        if cfg.control_stream_id_range !== nothing
            println("control_stream_id_range=$(cfg.control_stream_id_range)")
        end
        println("profiles=$(length(cfg.profiles))")
        for (name, profile) in cfg.profiles
            println("profile=$(name) header_nslots=$(profile.header_nslots) header_slot_bytes=$(profile.header_slot_bytes) max_dims=$(profile.max_dims)")
            for pool in profile.payload_pools
                println("pool_id=$(pool.pool_id) stride_bytes=$(pool.stride_bytes)")
            end
        end
        println("streams=$(length(cfg.streams))")
        for (name, stream) in cfg.streams
            println("stream=$(name) stream_id=$(stream.stream_id) profile=$(stream.profile)")
        end
    elseif cmd == "announce-listen"
        length(args) >= 4 || usage()
        aeron_dir = args[2]
        channel = args[3]
        stream_id = parse(Int32, args[4])
        duration_s = length(args) >= 5 ? parse(Float64, args[5]) : 5.0
        ctx = Aeron.Context()
        Aeron.aeron_dir!(ctx, aeron_dir)
        client = Aeron.Client(ctx)
        sub = Aeron.add_subscription(client, channel, stream_id)
        handler = Aeron.FragmentHandler((_, buffer, _) -> begin
            header = MessageHeader.Decoder(buffer, 0)
            template_id = MessageHeader.templateId(header)
            if template_id == ShmPoolAnnounce.sbe_template_id(ShmPoolAnnounce.Decoder)
                dec = ShmPoolAnnounce.Decoder(buffer)
                ShmPoolAnnounce.wrap!(dec, buffer, 0; header = header)
                println("ShmPoolAnnounce stream_id=$(ShmPoolAnnounce.streamId(dec)) epoch=$(ShmPoolAnnounce.epoch(dec)) layout=$(ShmPoolAnnounce.layoutVersion(dec))")
            elseif template_id == QosProducer.sbe_template_id(QosProducer.Decoder)
                dec = QosProducer.Decoder(buffer)
                QosProducer.wrap!(dec, buffer, 0; header = header)
                println("QosProducer stream_id=$(QosProducer.streamId(dec)) producer_id=$(QosProducer.producerId(dec)) seq=$(QosProducer.currentSeq(dec))")
            elseif template_id == QosConsumer.sbe_template_id(QosConsumer.Decoder)
                dec = QosConsumer.Decoder(buffer)
                QosConsumer.wrap!(dec, buffer, 0; header = header)
                println("QosConsumer stream_id=$(QosConsumer.streamId(dec)) consumer_id=$(QosConsumer.consumerId(dec)) seq=$(QosConsumer.lastSeqSeen(dec))")
            elseif template_id == FrameProgress.sbe_template_id(FrameProgress.Decoder)
                dec = FrameProgress.Decoder(buffer)
                FrameProgress.wrap!(dec, buffer, 0; header = header)
                println("FrameProgress stream_id=$(FrameProgress.streamId(dec)) frame_id=$(FrameProgress.frameId(dec)) state=$(FrameProgress.state(dec)) bytes=$(FrameProgress.payloadBytesFilled(dec))")
            end
            nothing
        end)
        assembler = Aeron.FragmentAssembler(handler)
        deadline = time_ns() + Int64(round(duration_s * 1e9))
        while time_ns() < deadline
            Aeron.poll(sub, assembler, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
            yield()
        end
        close(sub)
        close(client)
        close(ctx)
    elseif cmd == "discover" || cmd == "discovery-query"
        length(args) >= 6 || usage()
        aeron_dir = args[2]
        request_channel = args[3]
        request_stream_id = parse(Int32, args[4])
        response_channel = args[5]
        response_stream_id = parse(UInt32, args[6])
        stream_id = length(args) >= 7 ? parse(UInt32, args[7]) : nothing
        producer_id = length(args) >= 8 ? parse(UInt32, args[8]) : nothing
        data_source_id = length(args) >= 9 ? parse(UInt64, args[9]) : nothing
        data_source_name = length(args) >= 10 ? args[10] : ""
        tags_csv = length(args) >= 11 ? args[11] : ""
        timeout_ms = length(args) >= 12 ? parse(Int, args[12]) : 5000
        tags = isempty(tags_csv) ? String[] : split(tags_csv, ',')
        client_id = UInt32(getpid())

        with_discovery_client(
            aeron_dir,
            request_channel,
            request_stream_id,
            response_channel,
            response_stream_id,
            client_id,
        ) do client
            entries = Vector{DiscoveryEntry}()
            request_id = discover_streams!(
                client,
                entries;
                stream_id = stream_id,
                producer_id = producer_id,
                data_source_id = data_source_id,
                data_source_name = data_source_name,
                tags = tags,
            )
            request_id == 0 && error("discover send failed")
            slot = wait_for_discovery_response(client, request_id; timeout_ms = timeout_ms)
            slot === nothing && error("discover response timed out")
            println("status=$(slot.status)")
            println("count=$(slot.count)")
            if !isempty(slot.error_message)
                println("error=$(String(view(slot.error_message)))")
            end
            for entry in slot.out_entries
                println("stream_id=$(entry.stream_id) producer_id=$(entry.producer_id) epoch=$(entry.epoch) layout=$(entry.layout_version)")
                println("driver_instance_id=$(String(view(entry.driver_instance_id)))")
                println("driver_control=$(String(view(entry.driver_control_channel))) stream=$(entry.driver_control_stream_id)")
                println("header_uri=$(String(view(entry.header_region_uri))) nslots=$(entry.header_nslots) slot_bytes=$(entry.header_slot_bytes) max_dims=$(entry.max_dims)")
                println("data_source_name=$(String(view(entry.data_source_name))) data_source_id=$(entry.data_source_id)")
                if !isempty(entry.tags)
                    tag_list = join([String(view(tag)) for tag in entry.tags], ",")
                    println("tags=$tag_list")
                end
                if !isempty(entry.pools)
                    for pool in entry.pools
                        println("pool_id=$(pool.pool_id) nslots=$(pool.pool_nslots) stride=$(pool.stride_bytes) uri=$(String(view(pool.region_uri)))")
                    end
                end
            end
        end
    elseif cmd == "bridge-status"
        length(args) >= 2 || usage()
        aeron_dir = args[2]
        filter = length(args) >= 3 ? args[3] : "Name=Bridge"
        print_counters(aeron_dir; filter = filter)
    else
        usage()
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    tp_tool_main(ARGS)
end
