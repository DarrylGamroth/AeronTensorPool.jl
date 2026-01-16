using Random

@testset "SBE var-data bounds fuzz" begin
    rng = Random.MersenneTwister(0x7c5a_93b2)
    buffer = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
    tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
    wrap_slot_header!(slot_enc, buffer, 0)

    dims = fill(Int32(1), MAX_DIMS)
    strides = fill(Int32(0), MAX_DIMS)
    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(1),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(1),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )

    slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
    tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
    wrap_slot_header!(slot_dec, buffer, 0)
    @test AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec) !== nothing

    len_pos = SlotHeaderMsg.sbe_offset(slot_enc) + SlotHeaderMsg.sbe_block_length(SlotHeaderMsg.Decoder)
    max_len = max(0, length(buffer) - (len_pos + 5))
    for _ in 1:200
        len = UInt32(rand(rng, 0:max_len))
        len == AeronTensorPool.TENSOR_HEADER_LEN && (len += UInt32(1))
        SlotHeaderMsg.sbe_position!(
            slot_enc,
            len_pos,
        )
        SlotHeaderMsg.headerBytes_length!(slot_enc, len)
        wrap_slot_header!(slot_dec, buffer, 0)
        @test AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec) === nothing
    end

    unsafe_store!(Ptr{UInt32}(pointer(buffer, len_pos + 1)), UInt32(max_len + 10))
    wrap_slot_header!(slot_dec, buffer, 0)
    @test AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec) === nothing

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
        UInt8(1),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )
    header_pos = SlotHeaderMsg.sbe_position(slot_enc) - AeronTensorPool.TENSOR_HEADER_LEN
    msg_header = MessageHeader.Encoder(buffer, header_pos)

    MessageHeader.templateId!(
        msg_header,
        TensorHeaderMsg.sbe_template_id(TensorHeaderMsg.Decoder) + UInt16(1),
    )
    wrap_slot_header!(slot_dec, buffer, 0)
    @test AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec) === nothing

    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(3),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(1),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )
    msg_header = MessageHeader.Encoder(buffer, header_pos)
    MessageHeader.schemaId!(
        msg_header,
        TensorHeaderMsg.sbe_schema_id(TensorHeaderMsg.Decoder) + UInt16(1),
    )
    wrap_slot_header!(slot_dec, buffer, 0)
    @test AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec) === nothing

    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(4),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(1),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )
    msg_header = MessageHeader.Encoder(buffer, header_pos)
    MessageHeader.blockLength!(
        msg_header,
        TensorHeaderMsg.sbe_block_length(TensorHeaderMsg.Decoder) + UInt16(1),
    )
    wrap_slot_header!(slot_dec, buffer, 0)
    @test AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec) === nothing

    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(5),
        UInt32(0),
        UInt32(16),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(1),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )
    msg_header = MessageHeader.Encoder(buffer, header_pos)
    MessageHeader.version!(
        msg_header,
        TensorHeaderMsg.sbe_schema_version(TensorHeaderMsg.Decoder) + UInt16(1),
    )
    wrap_slot_header!(slot_dec, buffer, 0)
    @test AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec) === nothing
end
