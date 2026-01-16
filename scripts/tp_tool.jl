using Aeron
using AeronTensorPool
using UnsafeArrays

function usage()
    cmd = "tp_tool"
    println("Usage:")
    println("  tp_tool <command> ...")
    println("  ./bin/tp_tool <command> ...")
    println("  julia --project scripts/tp_tool.jl <command> ...")
    println()
    println("Commands:")
    println("  $(cmd) validate-uri <uri>")
    println("  $(cmd) read-superblock <uri>")
    println("  $(cmd) read-header <uri> <index>")
    println("  $(cmd) send-consumer-config <aeron_dir> <aeron_uri> <control_stream_id> <stream_id> <consumer_id> <use_shm> <mode> [payload_fallback_uri]")
    println("  $(cmd) driver-attach <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> [publish_mode] [expected_layout_version] [require_hugepages_policy] [timeout_ms]")
    println("  $(cmd) driver-detach <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> <lease_id> [timeout_ms]")
    println("  $(cmd) driver-keepalive <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> <lease_id>")
    println("  $(cmd) driver-status <driver_instance_id>")
    println("  $(cmd) driver-list-leases <driver_instance_id>")
    println("  $(cmd) driver-list-streams <driver_instance_id>")
    println("  $(cmd) driver-counters <aeron_dir> [filter]")
    println("  $(cmd) driver-config-validate <config_path>")
    println("  $(cmd) driver-config-dump <config_path>")
    println("  $(cmd) shm-validate <uri> <layout_version> <epoch> <stream_id> <nslots> <slot_bytes> <region_type> <pool_id>")
    println("  $(cmd) shm-summary <uri>")
    println("  $(cmd) announce-listen <aeron_dir> <channel> <stream_id> [duration_s]")
    println("  $(cmd) control-listen <aeron_dir> <channel> <stream_id> [duration_s]")
    println("  $(cmd) metadata-listen <aeron_dir> <channel> <stream_id> [duration_s]")
    println("  $(cmd) metadata-dump <aeron_dir> <channel> <stream_id> [timeout_ms]")
    println("  $(cmd) qos-listen <aeron_dir> <channel> <stream_id> [duration_s]")
    println("  $(cmd) discovery-list <aeron_dir> <request_channel> <request_stream_id> <response_channel> <response_stream_id> [timeout_ms]")
    println("  $(cmd) discovery-query <aeron_dir> <request_channel> <request_stream_id> <response_channel> <response_stream_id> [stream_id] [producer_id] [data_source_id] [data_source_name] [tags_csv] [timeout_ms]")
    println("  $(cmd) bridge-status <aeron_dir> [filter]")
    println("  $(cmd) discover <aeron_dir> <request_channel> <request_stream_id> <response_channel> <response_stream_id> [stream_id] [producer_id] [data_source_id] [data_source_name] [tags_csv] [timeout_ms]")
    println()
    println("Env overrides (when args omitted):")
    println("  TP_AERON_DIR, TP_AERON_URI, TP_CHANNEL, TP_STREAM_ID")
    println("  TP_CONTROL_CHANNEL, TP_CONTROL_STREAM_ID")
    println("  TP_METADATA_CHANNEL, TP_METADATA_STREAM_ID")
    println("  TP_QOS_CHANNEL, TP_QOS_STREAM_ID")
    println("  TP_DISCOVERY_REQUEST_CHANNEL, TP_DISCOVERY_REQUEST_STREAM_ID")
    println("  TP_DISCOVERY_RESPONSE_CHANNEL, TP_DISCOVERY_RESPONSE_STREAM_ID")
    println("  TP_CLIENT_ID, TP_ROLE, TP_STREAM_ID, TP_LEASE_ID")
    println("  TP_SHM_URI")
    exit(1)
end

function env_string(key::String)
    val = get(ENV, key, "")
    return isempty(val) ? nothing : val
end

function env_parse(key::String, parser)
    val = get(ENV, key, "")
    isempty(val) && return nothing
    return parser(val)
end

function arg_or_env(args::Vector{String}, idx::Int, envkey::String, parser = identity)
    if length(args) >= idx
        return parser(args[idx])
    end
    val = env_parse(envkey, parser)
    val === nothing && usage()
    return val
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
    Aeron.Context() do ctx
        Aeron.aeron_dir!(ctx, aeron_dir)
        Aeron.Client(ctx) do client
            state = init_driver_client(client, control_channel, control_stream, client_id, role)
            try
                return f(state)
            finally
                try
                    close(state.pub)
                    close(state.sub)
                catch
                end
            end
        end
    end
end

function with_aeron_client(f::Function, aeron_dir::String)
    Aeron.Context() do ctx
        Aeron.aeron_dir!(ctx, aeron_dir)
        Aeron.Client(ctx) do client
            return f(client)
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
    Aeron.Context() do ctx
        Aeron.aeron_dir!(ctx, aeron_dir)
        Aeron.Client(ctx) do client
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
                catch
                end
            end
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

function wait_for_metadata_entry(
    cache::MetadataCache,
    stream_id::UInt32;
    timeout_ms::Int = 5000,
)
    deadline = time_ns() + Int64(timeout_ms) * 1_000_000
    while time_ns() < deadline
        poll_metadata!(cache)
        entry = metadata_entry(cache, stream_id)
        if entry !== nothing
            return entry
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
    now_ns = UInt64(time_ns())
    for lease in leases
        expires_in_ns = lease.expiry_ns > now_ns ? lease.expiry_ns - now_ns : UInt64(0)
        println(
            "lease_id=$(lease.lease_id) stream_id=$(lease.stream_id) client_id=$(lease.client_id) role=$(lease.role) expiry_ns=$(lease.expiry_ns) expires_in_ns=$(expires_in_ns) state=$(lease.lifecycle)",
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
        uri = arg_or_env(args, 2, "TP_SHM_URI", identity)
        println(validate_uri(uri))
    elseif cmd == "read-superblock"
        uri = arg_or_env(args, 2, "TP_SHM_URI", identity)
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
        uri = arg_or_env(args, 2, "TP_SHM_URI", identity)
        index = parse(Int, args[3])
        index >= 0 || error("index must be >= 0")
        size = SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * (index + 1)
        buf = mmap_shm(uri, size)
        offset = header_slot_offset(index)
        slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
        tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
        wrap_slot_header!(slot_dec, buf, offset)
        header = try_read_slot_header(slot_dec, tensor_dec)
        header === nothing && error("invalid slot header")
        println("seq_commit=$(header.seq_commit)")
        println("seq=$(seqlock_sequence(header.seq_commit))")
        println("timestamp_ns=$(header.timestamp_ns)")
        println("meta_version=$(header.meta_version)")
        println("values_len_bytes=$(header.values_len_bytes)")
        println("payload_slot=$(header.payload_slot)")
        println("payload_offset=$(header.payload_offset)")
        println("pool_id=$(header.pool_id)")
        println("dtype=$(header.tensor.dtype)")
        println("major_order=$(header.tensor.major_order)")
        println("ndims=$(header.tensor.ndims)")
    elseif cmd == "shm-validate"
        length(args) >= 9 || usage()
        uri = arg_or_env(args, 2, "TP_SHM_URI", identity)
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
        uri = arg_or_env(args, 2, "TP_SHM_URI", identity)
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
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        aeron_uri = arg_or_env(args, 3, "TP_AERON_URI", identity)
        control_stream = arg_or_env(args, 4, "TP_CONTROL_STREAM_ID", val -> parse(Int32, val))
        stream_id = arg_or_env(args, 5, "TP_STREAM_ID", val -> parse(UInt32, val))
        consumer_id = arg_or_env(args, 6, "TP_CLIENT_ID", val -> parse(UInt32, val))
        use_shm = arg_or_env(args, 7, "TP_USE_SHM", parse_bool)
        mode = arg_or_env(args, 8, "TP_MODE", parse_mode)
        payload_fallback_uri = length(args) >= 9 ? args[9] : get(ENV, "TP_PAYLOAD_FALLBACK_URI", "")

        with_aeron_client(aeron_dir) do client
            pub = Aeron.add_publication(client, aeron_uri, control_stream)
            try
                claim = Aeron.BufferClaim()
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
                msg_len = sbe_message_length(enc)
                sent = with_claimed_buffer!(pub, claim, msg_len) do dst
                    copyto!(dst, 1, buf, 1, msg_len)
                end
                sent || error("consumer config claim failed")
            finally
                close(pub)
            end
        end
    elseif cmd == "driver-attach"
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        control_channel = arg_or_env(args, 3, "TP_CONTROL_CHANNEL", identity)
        control_stream = arg_or_env(args, 4, "TP_CONTROL_STREAM_ID", val -> parse(Int32, val))
        client_id = arg_or_env(args, 5, "TP_CLIENT_ID", val -> parse(UInt32, val))
        role = arg_or_env(args, 6, "TP_ROLE", parse_role)
        stream_id = arg_or_env(args, 7, "TP_STREAM_ID", val -> parse(UInt32, val))
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
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        control_channel = arg_or_env(args, 3, "TP_CONTROL_CHANNEL", identity)
        control_stream = arg_or_env(args, 4, "TP_CONTROL_STREAM_ID", val -> parse(Int32, val))
        client_id = arg_or_env(args, 5, "TP_CLIENT_ID", val -> parse(UInt32, val))
        role = arg_or_env(args, 6, "TP_ROLE", parse_role)
        stream_id = arg_or_env(args, 7, "TP_STREAM_ID", val -> parse(UInt32, val))
        lease_id = arg_or_env(args, 8, "TP_LEASE_ID", val -> parse(UInt64, val))
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
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        control_channel = arg_or_env(args, 3, "TP_CONTROL_CHANNEL", identity)
        control_stream = arg_or_env(args, 4, "TP_CONTROL_STREAM_ID", val -> parse(Int32, val))
        client_id = arg_or_env(args, 5, "TP_CLIENT_ID", val -> parse(UInt32, val))
        role = arg_or_env(args, 6, "TP_ROLE", parse_role)
        stream_id = arg_or_env(args, 7, "TP_STREAM_ID", val -> parse(UInt32, val))
        lease_id = arg_or_env(args, 8, "TP_LEASE_ID", val -> parse(UInt64, val))

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
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
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
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        channel = arg_or_env(args, 3, "TP_CHANNEL", identity)
        stream_id = arg_or_env(args, 4, "TP_STREAM_ID", val -> parse(Int32, val))
        duration_s = length(args) >= 5 ? parse(Float64, args[5]) : 5.0
        with_aeron_client(aeron_dir) do client
            sub = Aeron.add_subscription(client, channel, stream_id)
            handler = Aeron.FragmentHandler((_, buffer, _) -> begin
            header = DriverMessageHeader.Decoder(buffer, 0)
            template_id = DriverMessageHeader.templateId(header)
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
                println("FrameProgress stream_id=$(FrameProgress.streamId(dec)) seq=$(FrameProgress.seq(dec)) state=$(FrameProgress.state(dec)) bytes=$(FrameProgress.payloadBytesFilled(dec))")
            end
            nothing
            end)
            assembler = Aeron.FragmentAssembler(handler)
            deadline = time_ns() + Int64(round(duration_s * 1e9))
            try
                while time_ns() < deadline
                    Aeron.poll(sub, assembler, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                    yield()
                end
            finally
                close(sub)
            end
        end
    elseif cmd == "control-listen"
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        channel = arg_or_env(args, 3, "TP_CONTROL_CHANNEL", identity)
        stream_id = arg_or_env(args, 4, "TP_CONTROL_STREAM_ID", val -> parse(Int32, val))
        duration_s = length(args) >= 5 ? parse(Float64, args[5]) : 5.0
        with_aeron_client(aeron_dir) do client
            sub = Aeron.add_subscription(client, channel, stream_id)
            handler = Aeron.FragmentHandler((_, buffer, _) -> begin
            header = DriverMessageHeader.Decoder(buffer, 0)
            template_id = DriverMessageHeader.templateId(header)
            if template_id == ShmAttachRequest.sbe_template_id(ShmAttachRequest.Decoder)
                dec = ShmAttachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmAttachRequest.wrap!(dec, buffer, 0; header = header)
                println(
                    "ShmAttachRequest client_id=$(ShmAttachRequest.clientId(dec)) role=$(ShmAttachRequest.role(dec)) stream_id=$(ShmAttachRequest.streamId(dec)) publish_mode=$(ShmAttachRequest.publishMode(dec))",
                )
            elseif template_id == ShmAttachResponse.sbe_template_id(ShmAttachResponse.Decoder)
                dec = ShmAttachResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmAttachResponse.wrap!(dec, buffer, 0; header = header)
                println(
                    "ShmAttachResponse corr=$(ShmAttachResponse.correlationId(dec)) code=$(ShmAttachResponse.code(dec)) lease_id=$(ShmAttachResponse.leaseId(dec)) stream_id=$(ShmAttachResponse.streamId(dec)) epoch=$(ShmAttachResponse.epoch(dec))",
                )
            elseif template_id == ShmDetachRequest.sbe_template_id(ShmDetachRequest.Decoder)
                dec = ShmDetachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmDetachRequest.wrap!(dec, buffer, 0; header = header)
                println(
                    "ShmDetachRequest client_id=$(ShmDetachRequest.clientId(dec)) lease_id=$(ShmDetachRequest.leaseId(dec)) stream_id=$(ShmDetachRequest.streamId(dec))",
                )
            elseif template_id == ShmDetachResponse.sbe_template_id(ShmDetachResponse.Decoder)
                dec = ShmDetachResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmDetachResponse.wrap!(dec, buffer, 0; header = header)
                println(
                    "ShmDetachResponse corr=$(ShmDetachResponse.correlationId(dec)) code=$(ShmDetachResponse.code(dec))",
                )
            elseif template_id == ShmLeaseKeepalive.sbe_template_id(ShmLeaseKeepalive.Decoder)
                dec = ShmLeaseKeepalive.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmLeaseKeepalive.wrap!(dec, buffer, 0; header = header)
                println(
                    "ShmLeaseKeepalive lease_id=$(ShmLeaseKeepalive.leaseId(dec)) stream_id=$(ShmLeaseKeepalive.streamId(dec)) client_id=$(ShmLeaseKeepalive.clientId(dec))",
                )
            elseif template_id == ShmLeaseRevoked.sbe_template_id(ShmLeaseRevoked.Decoder)
                dec = ShmLeaseRevoked.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmLeaseRevoked.wrap!(dec, buffer, 0; header = header)
                println(
                    "ShmLeaseRevoked lease_id=$(ShmLeaseRevoked.leaseId(dec)) stream_id=$(ShmLeaseRevoked.streamId(dec)) client_id=$(ShmLeaseRevoked.clientId(dec)) reason=$(ShmLeaseRevoked.reason(dec))",
                )
            elseif template_id == ShmDriverShutdown.sbe_template_id(ShmDriverShutdown.Decoder)
                dec = ShmDriverShutdown.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmDriverShutdown.wrap!(dec, buffer, 0; header = header)
                println(
                    "ShmDriverShutdown reason=$(ShmDriverShutdown.reason(dec)) message=$(String(ShmDriverShutdown.errorMessage(dec)))",
                )
            elseif template_id == ShmDriverShutdownRequest.sbe_template_id(ShmDriverShutdownRequest.Decoder)
                dec = ShmDriverShutdownRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                ShmDriverShutdownRequest.wrap!(dec, buffer, 0; header = header)
                println("ShmDriverShutdownRequest")
            end
            nothing
            end)
            assembler = Aeron.FragmentAssembler(handler)
            deadline = time_ns() + Int64(round(duration_s * 1e9))
            try
                while time_ns() < deadline
                    Aeron.poll(sub, assembler, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT)
                    yield()
                end
            finally
                close(sub)
            end
        end
    elseif cmd == "metadata-listen"
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        channel = arg_or_env(args, 3, "TP_METADATA_CHANNEL", identity)
        stream_id = arg_or_env(args, 4, "TP_METADATA_STREAM_ID", val -> parse(Int32, val))
        duration_s = length(args) >= 5 ? parse(Float64, args[5]) : 5.0
        with_aeron_client(aeron_dir) do client
            cache = MetadataCache(channel, stream_id; client = client)
            deadline = time_ns() + Int64(round(duration_s * 1e9))
            seen = Dict{UInt32, UInt32}()
            try
                while time_ns() < deadline
                    poll_metadata!(cache)
                    for (sid, entry) in cache.entries
                        last = get(seen, sid, UInt32(0))
                        if entry.meta_version != last
                            println("stream_id=$(sid) meta_version=$(entry.meta_version) name=$(entry.name)")
                            seen[sid] = entry.meta_version
                        end
                    end
                    yield()
                end
            finally
                close(cache)
            end
        end
    elseif cmd == "metadata-dump"
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        channel = arg_or_env(args, 3, "TP_METADATA_CHANNEL", identity)
        stream_id = arg_or_env(args, 4, "TP_METADATA_STREAM_ID", val -> parse(UInt32, val))
        timeout_ms = length(args) >= 5 ? parse(Int, args[5]) : 5000
        with_aeron_client(aeron_dir) do client
            cache = MetadataCache(channel, Int32(stream_id); client = client)
            try
                entry = wait_for_metadata_entry(cache, stream_id; timeout_ms = timeout_ms)
                if entry === nothing
                    println("timeout")
                else
                    println("stream_id=$(entry.stream_id) meta_version=$(entry.meta_version) name=$(entry.name)")
                    println("summary=$(entry.summary)")
                    for attr in entry.attributes
                        println("attr=$(attr.key) mime=$(attr.mime) value=$(String(attr.value))")
                    end
                end
            finally
                close(cache)
            end
        end
    elseif cmd == "qos-listen"
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        channel = arg_or_env(args, 3, "TP_QOS_CHANNEL", identity)
        stream_id = arg_or_env(args, 4, "TP_QOS_STREAM_ID", val -> parse(Int32, val))
        duration_s = length(args) >= 5 ? parse(Float64, args[5]) : 5.0
        with_aeron_client(aeron_dir) do client
            monitor = QosMonitor(channel, stream_id; client = client)
            deadline = time_ns() + Int64(round(duration_s * 1e9))
            try
                while time_ns() < deadline
                    poll_qos!(monitor)
                    for snap in values(monitor.producers)
                        println("producer=$(snap.producer_id) stream=$(snap.stream_id) seq=$(snap.current_seq)")
                    end
                    for snap in values(monitor.consumers)
                        println("consumer=$(snap.consumer_id) stream=$(snap.stream_id) last_seq=$(snap.last_seq_seen)")
                    end
                    yield()
                end
            finally
                close(monitor)
            end
        end
    elseif cmd == "discovery-list"
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        request_channel = arg_or_env(args, 3, "TP_DISCOVERY_REQUEST_CHANNEL", identity)
        request_stream_id = arg_or_env(args, 4, "TP_DISCOVERY_REQUEST_STREAM_ID", val -> parse(Int32, val))
        response_channel = arg_or_env(args, 5, "TP_DISCOVERY_RESPONSE_CHANNEL", identity)
        response_stream_id = arg_or_env(args, 6, "TP_DISCOVERY_RESPONSE_STREAM_ID", val -> parse(UInt32, val))
        timeout_ms = length(args) >= 7 ? parse(Int, args[7]) : 5000
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
            request_id = discover_streams!(client, entries)
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
    elseif cmd == "discover" || cmd == "discovery-query"
        aeron_dir = arg_or_env(args, 2, "TP_AERON_DIR", identity)
        request_channel = arg_or_env(args, 3, "TP_DISCOVERY_REQUEST_CHANNEL", identity)
        request_stream_id = arg_or_env(args, 4, "TP_DISCOVERY_REQUEST_STREAM_ID", val -> parse(Int32, val))
        response_channel = arg_or_env(args, 5, "TP_DISCOVERY_RESPONSE_CHANNEL", identity)
        response_stream_id = arg_or_env(args, 6, "TP_DISCOVERY_RESPONSE_STREAM_ID", val -> parse(UInt32, val))
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
