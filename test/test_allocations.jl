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
    hdr_enc = TensorSlotHeaderMsg.Encoder(Vector{UInt8})
    wrap_tensor_header!(hdr_enc, hdr_buf, 0)
    dims = [Int32(1), Int32(2), Int32(3), Int32(4), Int32(0), Int32(0), Int32(0), Int32(0)]
    strides = [Int32(4), Int32(8), Int32(16), Int32(32), Int32(0), Int32(0), Int32(0), Int32(0)]
    write_tensor_slot_header!(
        hdr_enc,
        UInt64(2),
        UInt32(3),
        UInt32(64),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(4),
        dims,
        strides,
    )
    @test @allocated(write_tensor_slot_header!(
        hdr_enc,
        UInt64(2),
        UInt32(3),
        UInt32(64),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(4),
        dims,
        strides,
    )) == 0

    hdr_dec = TensorSlotHeaderMsg.Decoder(Vector{UInt8})
    wrap_tensor_header!(hdr_dec, hdr_buf, 0)
    @test @allocated(read_tensor_slot_header(hdr_dec)) == 0

    desc_buf = Vector{UInt8}(undef, 128)
    desc_enc = FrameDescriptor.Encoder(Vector{UInt8})
    FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)
    FrameDescriptor.streamId!(desc_enc, UInt32(1))
    FrameDescriptor.epoch!(desc_enc, UInt64(2))
    FrameDescriptor.seq!(desc_enc, UInt64(3))
    FrameDescriptor.headerIndex!(desc_enc, UInt32(0))
    FrameDescriptor.timestampNs!(desc_enc, UInt64(4))
    FrameDescriptor.metaVersion!(desc_enc, UInt32(1))
    @test @allocated(begin
        FrameDescriptor.streamId!(desc_enc, UInt32(1))
        FrameDescriptor.epoch!(desc_enc, UInt64(2))
        FrameDescriptor.seq!(desc_enc, UInt64(3))
        FrameDescriptor.headerIndex!(desc_enc, UInt32(0))
        FrameDescriptor.timestampNs!(desc_enc, UInt64(4))
        FrameDescriptor.metaVersion!(desc_enc, UInt32(1))
    end) == 0
end
