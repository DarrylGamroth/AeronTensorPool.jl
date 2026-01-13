@testset "Allocation checks" begin
    sb_buf = Vector{UInt8}(undef, SUPERBLOCK_SIZE)
    sb_enc = ShmRegionSuperblock.Encoder(Vector{UInt8})
    wrap_superblock!(sb_enc, sb_buf, 0)
    sb_fields = SuperblockFields(
        MAGIC_TPOLSHM1,
        UInt32(1),
        UInt64(2),
        UInt32(3),
        RegionType.HEADER_RING,
        UInt16(0),
        UInt32(8),
        UInt32(HEADER_SLOT_BYTES),
        UInt32(0),
        UInt64(10),
        UInt64(11),
        UInt64(12),
    )
    write_superblock!(sb_enc, sb_fields)
    @test @allocated(write_superblock!(sb_enc, sb_fields)) == 0

    hdr_buf = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
    tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
    wrap_slot_header!(slot_enc, hdr_buf, 0)
    dims = [Int32(1), Int32(2), Int32(3), Int32(4), Int32(0), Int32(0), Int32(0), Int32(0)]
    strides = [Int32(4), Int32(8), Int32(16), Int32(32), Int32(0), Int32(0), Int32(0), Int32(0)]
    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(2),
        UInt32(3),
        UInt32(64),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(4),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )
    @test @allocated(write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(2),
        UInt32(3),
        UInt32(64),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(4),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )) == 0

    slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
    tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
    wrap_slot_header!(slot_dec, hdr_buf, 0)
    @test @allocated(AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec)) == 0

    desc_buf = Vector{UInt8}(undef, 128)
    desc_enc = FrameDescriptor.Encoder(Vector{UInt8})
    FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)
    FrameDescriptor.streamId!(desc_enc, UInt32(1))
    FrameDescriptor.epoch!(desc_enc, UInt64(2))
    FrameDescriptor.seq!(desc_enc, UInt64(3))
    FrameDescriptor.timestampNs!(desc_enc, UInt64(4))
    FrameDescriptor.metaVersion!(desc_enc, UInt32(1))
    FrameDescriptor.traceId!(desc_enc, UInt64(0))
    @test @allocated(begin
        FrameDescriptor.streamId!(desc_enc, UInt32(1))
        FrameDescriptor.epoch!(desc_enc, UInt64(2))
        FrameDescriptor.seq!(desc_enc, UInt64(3))
        FrameDescriptor.timestampNs!(desc_enc, UInt64(4))
        FrameDescriptor.metaVersion!(desc_enc, UInt32(1))
        FrameDescriptor.traceId!(desc_enc, UInt64(0))
    end) == 0
end
