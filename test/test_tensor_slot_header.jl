@testset "Tensor slot header encode/decode" begin
    @test TensorSlotHeaderMsg.sbe_block_length(TensorSlotHeaderMsg.Encoder) == UInt16(HEADER_SLOT_BYTES)
    buffer = zeros(UInt8, HEADER_SLOT_BYTES)
    enc = TensorSlotHeaderMsg.Encoder(Vector{UInt8})
    wrap_tensor_header!(enc, buffer, 0)

    shape = [Int32(4), Int32(5), Int32(6), Int32(7), Int32(0), Int32(0), Int32(0), Int32(0)]
    strides = [Int32(1), Int32(4), Int32(20), Int32(120), Int32(0), Int32(0), Int32(0), Int32(0)]

    write_tensor_slot_header!(
        enc;
        timestamp_ns = UInt64(20),
        meta_version = UInt32(2),
        values_len_bytes = UInt32(4096),
        payload_slot = UInt32(3),
        payload_offset = UInt32(0),
        pool_id = UInt16(1),
        dtype = Dtype.UINT8,
        major_order = MajorOrder.ROW,
        ndims = UInt8(4),
        dims = shape,
        strides = strides,
    )

    dec = TensorSlotHeaderMsg.Decoder(Vector{UInt8})
    wrap_tensor_header!(dec, buffer, 0)
    read_hdr = read_tensor_slot_header(dec)

    @test read_hdr.seq_commit == 0
    @test read_hdr.timestamp_ns == 20
    @test read_hdr.meta_version == 2
    @test read_hdr.values_len_bytes == 4096
    @test read_hdr.payload_slot == 3
    @test read_hdr.payload_offset == 0
    @test read_hdr.pool_id == 1
    @test read_hdr.dtype == Dtype.UINT8
    @test read_hdr.major_order == MajorOrder.ROW
    @test read_hdr.ndims == 4
    @test read_hdr.dims[1:4] == (Int32(4), Int32(5), Int32(6), Int32(7))
    @test read_hdr.strides[1:4] == (Int32(1), Int32(4), Int32(20), Int32(120))
end
