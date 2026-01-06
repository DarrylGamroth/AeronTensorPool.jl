@testset "Consumer validation helpers" begin
    @test Consumer.validate_stride(UInt32(4096); require_hugepages = false)
    @test !Consumer.validate_stride(UInt32(5000); require_hugepages = false)
    @test !Consumer.validate_stride(UInt32(4096); require_hugepages = true)

    fields = SuperblockFields(
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
    @test validate_superblock_fields(
        fields;
        expected_layout_version = UInt32(1),
        expected_epoch = UInt64(2),
        expected_stream_id = UInt32(3),
        expected_nslots = UInt32(8),
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    @test !validate_superblock_fields(
        fields;
        expected_layout_version = UInt32(2),
        expected_epoch = UInt64(2),
        expected_stream_id = UInt32(3),
        expected_nslots = UInt32(8),
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )

    @test !validate_superblock_fields(
        fields;
        expected_layout_version = UInt32(1),
        expected_epoch = UInt64(9),
        expected_stream_id = UInt32(3),
        expected_nslots = UInt32(8),
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
end
