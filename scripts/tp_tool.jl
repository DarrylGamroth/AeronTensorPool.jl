using Aeron
using AeronTensorPool

function usage()
    println("Usage:")
    println("  julia --project scripts/tp_tool.jl validate-uri <uri>")
    println("  julia --project scripts/tp_tool.jl read-superblock <uri>")
    println("  julia --project scripts/tp_tool.jl read-header <uri> <index>")
    println("  julia --project scripts/tp_tool.jl send-consumer-config <aeron_dir> <aeron_uri> <control_stream_id> <stream_id> <consumer_id> <use_shm> <mode> <decimation> [payload_fallback_uri]")
    println("  julia --project scripts/tp_tool.jl driver-attach <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> [publish_mode] [expected_layout_version] [max_dims] [require_hugepages] [timeout_ms]")
    println("  julia --project scripts/tp_tool.jl driver-detach <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> <lease_id> [timeout_ms]")
    println("  julia --project scripts/tp_tool.jl driver-keepalive <aeron_dir> <control_channel> <control_stream_id> <client_id> <role> <stream_id> <lease_id>")
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
    v == "latest" && return Mode.LATEST
    v == "decimated" && return Mode.DECIMATED
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

function parse_optional_bool(val::String)
    v = lowercase(val)
    v == "true" && return true
    v == "false" && return false
    v == "unset" && return nothing
    error("invalid optional bool: $val (use true|false|unset)")
end

function with_driver_client(
    aeron_dir::String,
    control_channel::String,
    control_stream::Int32,
    client_id::UInt32,
    role::DriverRole.SbeEnum,
    f::Function,
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
    decoder = TensorSlotHeader256.Decoder(Vector{UInt8})
    wrap_tensor_header!(decoder, buf, offset)
    header = read_tensor_slot_header(decoder)
    println("commit_word=$(header.commit_word)")
    println("frame_id=$(header.frame_id)")
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
    length(ARGS) >= 9 || usage()
    aeron_dir = ARGS[2]
    aeron_uri = ARGS[3]
    control_stream = parse(Int32, ARGS[4])
    stream_id = parse(UInt32, ARGS[5])
    consumer_id = parse(UInt32, ARGS[6])
    use_shm = parse_bool(ARGS[7])
    mode = parse_mode(ARGS[8])
    decimation = parse(UInt16, ARGS[9])
    payload_fallback_uri = length(ARGS) >= 10 ? ARGS[10] : ""

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
    ConsumerConfigMsg.decimation!(enc, decimation)
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
    max_dims = length(ARGS) >= 10 ? parse(UInt8, ARGS[10]) : UInt8(0)
    require_hugepages = length(ARGS) >= 11 ? parse_optional_bool(ARGS[11]) : nothing
    timeout_ms = length(ARGS) >= 12 ? parse(Int, ARGS[12]) : 5000

    with_driver_client(aeron_dir, control_channel, control_stream, client_id, role) do client
        correlation_id = send_attach_request!(
            client;
            stream_id = stream_id,
            expected_layout_version = expected_layout_version,
            max_dims = max_dims,
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
else
    usage()
end
