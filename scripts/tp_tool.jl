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
    println("  julia --project scripts/tp_tool.jl discover <aeron_dir> <request_channel> <request_stream_id> <response_channel> <response_stream_id> [stream_id] [producer_id] [data_source_id] [data_source_name] [tags_csv] [timeout_ms]")
    exit(1)
end

length(ARGS) >= 2 || usage()
cmd = ARGS[1]

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

if cmd == "validate-uri"
    uri = ARGS[2]
    println(validate_uri(uri))
elseif cmd == "read-superblock"
    uri = ARGS[2]
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
    length(ARGS) >= 3 || usage()
    uri = ARGS[2]
    index = parse(Int, ARGS[3])
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
elseif cmd == "send-consumer-config"
    length(ARGS) >= 8 || usage()
    aeron_dir = ARGS[2]
    aeron_uri = ARGS[3]
    control_stream = parse(Int32, ARGS[4])
    stream_id = parse(UInt32, ARGS[5])
    consumer_id = parse(UInt32, ARGS[6])
    use_shm = parse_bool(ARGS[7])
    mode = parse_mode(ARGS[8])
    payload_fallback_uri = length(ARGS) >= 9 ? ARGS[9] : ""

    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, aeron_dir)
    client = Aeron.Client(ctx)
    pub = Aeron.add_publication(client, aeron_uri, control_stream)

    buf = Vector{UInt8}(undef, 512)
    enc = ConsumerConfigMsg.Encoder(Vector{UInt8})
    ConsumerConfigMsg.wrap_and_apply_header!(enc, buf, 0)
    ConsumerConfigMsg.streamId!(enc, stream_id)
    ConsumerConfigMsg.consumerId!(enc, consumer_id)
    ConsumerConfigMsg.useShm!(enc, use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE)
    ConsumerConfigMsg.mode!(enc, mode)
    ConsumerConfigMsg.payloadFallbackUri!(enc, payload_fallback_uri)

    Aeron.offer(pub, view(buf, 1:sbe_message_length(enc)))
    close(pub)
    close(client)
elseif cmd == "driver-attach"
    length(ARGS) >= 7 || usage()
    aeron_dir = ARGS[2]
    control_channel = ARGS[3]
    control_stream = parse(Int32, ARGS[4])
    client_id = parse(UInt32, ARGS[5])
    role = parse_role(ARGS[6])
    stream_id = parse(UInt32, ARGS[7])
    publish_mode = length(ARGS) >= 8 ? parse_publish_mode(ARGS[8]) : DriverPublishMode.REQUIRE_EXISTING
    expected_layout_version = length(ARGS) >= 9 ? parse(UInt32, ARGS[9]) : UInt32(0)
    require_hugepages = length(ARGS) >= 10 ? parse_hugepages_policy(ARGS[10]) : DriverHugepagesPolicy.UNSPECIFIED
    timeout_ms = length(ARGS) >= 11 ? parse(Int, ARGS[11]) : 5000

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
    length(ARGS) >= 8 || usage()
    aeron_dir = ARGS[2]
    control_channel = ARGS[3]
    control_stream = parse(Int32, ARGS[4])
    client_id = parse(UInt32, ARGS[5])
    role = parse_role(ARGS[6])
    stream_id = parse(UInt32, ARGS[7])
    lease_id = parse(UInt64, ARGS[8])
    timeout_ms = length(ARGS) >= 9 ? parse(Int, ARGS[9]) : 5000

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
    length(ARGS) >= 8 || usage()
    aeron_dir = ARGS[2]
    control_channel = ARGS[3]
    control_stream = parse(Int32, ARGS[4])
    client_id = parse(UInt32, ARGS[5])
    role = parse_role(ARGS[6])
    stream_id = parse(UInt32, ARGS[7])
    lease_id = parse(UInt64, ARGS[8])

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
elseif cmd == "discover"
    length(ARGS) >= 6 || usage()
    aeron_dir = ARGS[2]
    request_channel = ARGS[3]
    request_stream_id = parse(Int32, ARGS[4])
    response_channel = ARGS[5]
    response_stream_id = parse(UInt32, ARGS[6])
    stream_id = length(ARGS) >= 7 ? parse(UInt32, ARGS[7]) : nothing
    producer_id = length(ARGS) >= 8 ? parse(UInt32, ARGS[8]) : nothing
    data_source_id = length(ARGS) >= 9 ? parse(UInt64, ARGS[9]) : nothing
    data_source_name = length(ARGS) >= 10 ? ARGS[10] : ""
    tags_csv = length(ARGS) >= 11 ? ARGS[11] : ""
    timeout_ms = length(ARGS) >= 12 ? parse(Int, ARGS[12]) : 5000
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
else
    usage()
end
