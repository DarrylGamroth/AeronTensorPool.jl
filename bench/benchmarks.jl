using BenchmarkTools
using UnsafeArrays
using AeronTensorPool

function bench_write_header()
    buffer = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    encoder = TensorSlotHeader256.Encoder(Vector{UInt8})
    wrap_tensor_header!(encoder, buffer, 0)
    dims = Int32[4, 4]
    strides = Int32[4, 1]
    return @benchmark write_tensor_slot_header!(
        $encoder,
        UInt64(1),
        UInt64(2),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(2),
        $dims,
        $strides,
    )
end

function bench_read_header()
    buffer = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    encoder = TensorSlotHeader256.Encoder(Vector{UInt8})
    wrap_tensor_header!(encoder, buffer, 0)
    write_tensor_slot_header!(
        encoder,
        UInt64(1),
        UInt64(2),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(2),
        Int32[4, 4],
        Int32[4, 1],
    )
    decoder = TensorSlotHeader256.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
    wrap_tensor_header!(decoder, buffer, 0)
    return @benchmark read_tensor_slot_header($decoder)
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

function run_benchmarks()
    println("Benchmark: write_tensor_slot_header!")
    show(bench_write_header())
    println()
    println("Benchmark: read_tensor_slot_header")
    show(bench_read_header())
    println()
    println("Benchmark: encode FrameDescriptor")
    show(bench_descriptor_encode())
    println()
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_benchmarks()
end
