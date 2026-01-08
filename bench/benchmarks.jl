using BenchmarkTools
using UnsafeArrays
using Aeron
using AeronTensorPool

function bench_write_header()
    buffer = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
    tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
    wrap_slot_header!(slot_enc, buffer, 0)
    dims = Int32[4, 4]
    strides = Int32[4, 1]
    return @benchmark write_slot_header!(
        $slot_enc,
        $tensor_enc,
        UInt64(2),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(2),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        $dims,
        $strides,
    )
end

function bench_read_header()
    buffer = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
    tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
    wrap_slot_header!(slot_enc, buffer, 0)
    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(2),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(2),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        Int32[4, 4],
        Int32[4, 1],
    )
    slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
    tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
    wrap_slot_header!(slot_dec, buffer, 0)
    return @benchmark AeronTensorPool.try_read_slot_header($slot_dec, $tensor_dec)
end

function bench_descriptor_encode()
    buffer = Vector{UInt8}(undef, 512)
    encoder = FrameDescriptor.Encoder(Vector{UInt8})
    return @benchmark begin
        FrameDescriptor.wrap_and_apply_header!($encoder, $buffer, 0)
        FrameDescriptor.streamId!($encoder, UInt32(1))
        FrameDescriptor.epoch!($encoder, UInt64(1))
        FrameDescriptor.seq!($encoder, UInt64(42))
        FrameDescriptor.headerIndex!($encoder, UInt32(0))
        FrameDescriptor.timestampNs!($encoder, UInt64(123))
        FrameDescriptor.metaVersion!($encoder, UInt32(0))
    end
end

function bench_try_claim_descriptor()
    Aeron.MediaDriver.launch_embedded() do driver
        Aeron.Context() do context
            Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
            Aeron.Client(context) do client
                pub = Aeron.add_publication(client, "aeron:ipc", 18000)
                sub = Aeron.add_subscription(client, "aeron:ipc", 18000)
                deadline = time_ns() + Int64(1e9)
                while time_ns() < deadline && !Aeron.is_connected(pub)
                    yield()
                end
                Aeron.is_connected(pub) || error("publication not connected")
                claim = Aeron.BufferClaim()
                encoder = FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                return @benchmark begin
                    with_claimed_buffer!($pub, $claim, AeronTensorPool.FRAME_DESCRIPTOR_LEN) do buf
                        header = MessageHeader.Encoder(buf, 0)
                        MessageHeader.blockLength!(header, FrameDescriptor.sbe_block_length(FrameDescriptor.Decoder))
                        MessageHeader.templateId!(header, FrameDescriptor.sbe_template_id(FrameDescriptor.Decoder))
                        MessageHeader.schemaId!(header, FrameDescriptor.sbe_schema_id(FrameDescriptor.Decoder))
                        MessageHeader.version!(header, FrameDescriptor.sbe_schema_version(FrameDescriptor.Decoder))
                        FrameDescriptor.wrap!($encoder, buf, AeronTensorPool.MESSAGE_HEADER_LEN)
                        FrameDescriptor.streamId!($encoder, UInt32(1))
                        FrameDescriptor.epoch!($encoder, UInt64(1))
                        FrameDescriptor.seq!($encoder, UInt64(1))
                        FrameDescriptor.headerIndex!($encoder, UInt32(0))
                        FrameDescriptor.timestampNs!($encoder, UInt64(123))
                        FrameDescriptor.metaVersion!($encoder, UInt32(0))
                    end
                end
            end
        end
    end
end

function run_benchmarks()
    println("Benchmark: write_slot_header!")
    show(bench_write_header())
    println()
    println("Benchmark: read_slot_header")
    show(bench_read_header())
    println()
    println("Benchmark: encode FrameDescriptor")
    show(bench_descriptor_encode())
    println()
    println("Benchmark: try_claim FrameDescriptor")
    show(bench_try_claim_descriptor())
    println()
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_benchmarks()
end
