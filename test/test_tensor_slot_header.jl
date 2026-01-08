@testset "Slot header encode/decode" begin
    @test SlotHeaderMsg.sbe_block_length(SlotHeaderMsg.Encoder) == UInt16(60)
    @test AeronTensorPool.TENSOR_HEADER_LEN == 192
    buffer = zeros(UInt8, HEADER_SLOT_BYTES)
    slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
    tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
    wrap_slot_header!(slot_enc, buffer, 0)

    shape = [Int32(4), Int32(5), Int32(6), Int32(7), Int32(0), Int32(0), Int32(0), Int32(0)]
    strides = [Int32(1), Int32(4), Int32(20), Int32(120), Int32(0), Int32(0), Int32(0), Int32(0)]

    write_slot_header!(
        slot_enc,
        tensor_enc;
        timestamp_ns = UInt64(20),
        meta_version = UInt32(2),
        values_len_bytes = UInt32(4096),
        payload_slot = UInt32(3),
        payload_offset = UInt32(0),
        pool_id = UInt16(1),
        dtype = Dtype.UINT8,
        major_order = MajorOrder.ROW,
        ndims = UInt8(4),
        progress_unit = AeronTensorPool.ProgressUnit.NONE,
        progress_stride_bytes = UInt32(0),
        dims = shape,
        strides = strides,
    )

    slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
    tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
    wrap_slot_header!(slot_dec, buffer, 0)
    read_hdr = AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec)
    @test read_hdr !== nothing
    read_hdr = read_hdr::SlotHeader

    @test read_hdr.seq_commit == 0
    @test read_hdr.timestamp_ns == 20
    @test read_hdr.meta_version == 2
    @test read_hdr.values_len_bytes == 4096
    @test read_hdr.payload_slot == 3
    @test read_hdr.payload_offset == 0
    @test read_hdr.pool_id == 1
    @test read_hdr.tensor.dtype == Dtype.UINT8
    @test read_hdr.tensor.major_order == MajorOrder.ROW
    @test read_hdr.tensor.ndims == 4
    @test read_hdr.tensor.progress_unit == AeronTensorPool.ProgressUnit.NONE
    @test read_hdr.tensor.progress_stride_bytes == 0
    @test read_hdr.tensor.dims[1:4] == (Int32(4), Int32(5), Int32(6), Int32(7))
    @test read_hdr.tensor.strides[1:4] == (Int32(1), Int32(4), Int32(20), Int32(120))
end
