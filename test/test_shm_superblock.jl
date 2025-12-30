@testset "SHM superblock encode/decode" begin
    @test ShmRegionSuperblock.sbe_block_length(ShmRegionSuperblock.Encoder) == UInt16(SUPERBLOCK_SIZE)
    buffer = Vector{UInt8}(undef, SUPERBLOCK_SIZE)
    enc = ShmRegionSuperblock.Encoder(Vector{UInt8})
    wrap_superblock!(enc, buffer, 0)
    fields = SuperblockFields(
        MAGIC_TPOLSHM1,
        UInt32(1),
        UInt64(2),
        UInt32(3),
        RegionType.HEADER_RING,
        UInt16(0),
        UInt32(1024),
        UInt32(HEADER_SLOT_BYTES),
        UInt32(0),
        UInt64(1234),
        UInt64(5678),
        UInt64(9999),
    )
    write_superblock!(enc, fields)

    dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(dec, buffer, 0)
    read_fields = read_superblock(dec)

    @test read_fields.magic == fields.magic
    @test read_fields.layout_version == fields.layout_version
    @test read_fields.epoch == fields.epoch
    @test read_fields.stream_id == fields.stream_id
    @test read_fields.region_type == fields.region_type
    @test read_fields.pool_id == fields.pool_id
    @test read_fields.nslots == fields.nslots
    @test read_fields.slot_bytes == fields.slot_bytes
    @test read_fields.stride_bytes == fields.stride_bytes
    @test read_fields.pid == fields.pid
    @test read_fields.start_timestamp_ns == fields.start_timestamp_ns
    @test read_fields.activity_timestamp_ns == fields.activity_timestamp_ns
end
