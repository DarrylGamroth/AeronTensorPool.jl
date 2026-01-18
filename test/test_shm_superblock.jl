using Random

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

@testset "Superblock field validation fuzz" begin
    rng = Random.MersenneTwister(0x5e13_6b1f)
    expected = SuperblockFields(
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
    expected_args = (
        expected_layout_version = expected.layout_version,
        expected_epoch = expected.epoch,
        expected_stream_id = expected.stream_id,
        expected_nslots = expected.nslots,
        expected_slot_bytes = expected.slot_bytes,
        expected_region_type = expected.region_type,
        expected_pool_id = expected.pool_id,
    )

    function make_fields(;
        magic = expected.magic,
        layout_version = expected.layout_version,
        epoch = expected.epoch,
        stream_id = expected.stream_id,
        region_type = expected.region_type,
        pool_id = expected.pool_id,
        nslots = expected.nslots,
        slot_bytes = expected.slot_bytes,
        stride_bytes = expected.stride_bytes,
        pid = expected.pid,
        start_timestamp_ns = expected.start_timestamp_ns,
        activity_timestamp_ns = expected.activity_timestamp_ns,
    )
        return SuperblockFields(
            magic,
            layout_version,
            epoch,
            stream_id,
            region_type,
            pool_id,
            nslots,
            slot_bytes,
            stride_bytes,
            pid,
            start_timestamp_ns,
            activity_timestamp_ns,
        )
    end

    for _ in 1:200
        ok_expected = validate_superblock_fields(expected; expected_args...)
        @test ok_expected
        which = rand(rng, 1:8)
        if which == 1
            fields = make_fields(magic = expected.magic + UInt64(1))
        elseif which == 2
            fields = make_fields(layout_version = expected.layout_version + UInt32(1))
        elseif which == 3
            fields = make_fields(epoch = expected.epoch + UInt64(1))
        elseif which == 4
            fields = make_fields(stream_id = expected.stream_id + UInt32(1))
        elseif which == 5
            alt_region = expected.region_type == RegionType.HEADER_RING ? RegionType.PAYLOAD_POOL : RegionType.HEADER_RING
            fields = make_fields(region_type = alt_region)
        elseif which == 6
            fields = make_fields(pool_id = expected.pool_id + UInt16(1))
        elseif which == 7
            fields = make_fields(nslots = expected.nslots + UInt32(1))
        else
            fields = make_fields(slot_bytes = expected.slot_bytes + UInt32(1))
        end
        ok_fields = validate_superblock_fields(fields; expected_args...)
        @test !ok_fields
    end
end
