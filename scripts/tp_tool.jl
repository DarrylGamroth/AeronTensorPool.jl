using AeronTensorPool

function usage()
    println("Usage:")
    println("  julia --project scripts/tp_tool.jl validate-uri <uri>")
    println("  julia --project scripts/tp_tool.jl read-superblock <uri>")
    println("  julia --project scripts/tp_tool.jl read-header <uri> <index>")
    exit(1)
end

length(ARGS) >= 2 || usage()
cmd = ARGS[1]

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
else
    usage()
end
