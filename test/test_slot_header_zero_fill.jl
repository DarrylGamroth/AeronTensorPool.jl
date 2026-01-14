@testset "Slot header dims/strides zero fill" begin
    buffer = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
    tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
    wrap_slot_header!(slot_enc, buffer, 0)

    dims = vcat(Int32(3), Int32(5), fill(Int32(99), MAX_DIMS - 2))
    strides = vcat(Int32(20), Int32(4), fill(Int32(77), MAX_DIMS - 2))

    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(0),
        UInt32(0),
        UInt32(60),
        UInt32(0),
        UInt32(0),
    UInt16(1),
    Dtype.UINT8,
    MajorOrder.ROW,
    UInt8(2),
    AeronTensorPool.ProgressUnit.NONE,
    UInt32(0),
    dims,
    strides,
    )

    slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
    tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
    wrap_slot_header!(slot_dec, buffer, 0)
    header_pos = SlotHeaderMsg.sbe_offset(slot_dec) +
        SlotHeaderMsg.sbe_block_length(SlotHeaderMsg.Decoder) +
        SlotHeaderMsg.headerBytes_header_length
    header = read_slot_header(slot_dec, tensor_dec, buffer, header_pos)

    @test header.tensor.dims[1] == Int32(3)
    @test header.tensor.dims[2] == Int32(5)
    @test all(header.tensor.dims[i] == 0 for i in 3:MAX_DIMS)
    @test header.tensor.strides[1] == Int32(20)
    @test header.tensor.strides[2] == Int32(4)
    @test all(header.tensor.strides[i] == 0 for i in 3:MAX_DIMS)
end
