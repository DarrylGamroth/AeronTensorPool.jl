using Test
using AeronTensorPool
using StringViews

@testset "Discovery filters" begin
    entry = AeronTensorPool.DiscoveryEntry()
    entry.stream_id = UInt32(10)
    entry.producer_id = UInt32(20)
    entry.data_source_id = UInt64(30)
    copyto!(entry.data_source_name, "CameraA")
    entry.tags = [FixedString(DISCOVERY_TAG_MAX_BYTES), FixedString(DISCOVERY_TAG_MAX_BYTES)]
    copyto!(entry.tags[1], "tag1")
    copyto!(entry.tags[2], "tag2")

    @test AeronTensorPool.entry_matches!(
        entry,
        UInt32(10),
        UInt32(20),
        UInt64(30),
        StringView("CameraA"),
        StringView[],
    )
    @test !AeronTensorPool.entry_matches!(
        entry,
        UInt32(11),
        UInt32(20),
        UInt64(30),
        StringView("CameraA"),
        StringView[],
    )
    @test !AeronTensorPool.entry_matches!(
        entry,
        UInt32(10),
        UInt32(21),
        UInt64(30),
        StringView("CameraA"),
        StringView[],
    )
    @test !AeronTensorPool.entry_matches!(
        entry,
        UInt32(10),
        UInt32(20),
        UInt64(31),
        StringView("CameraA"),
        StringView[],
    )
    @test !AeronTensorPool.entry_matches!(
        entry,
        UInt32(10),
        UInt32(20),
        UInt64(30),
        StringView("cameraa"),
        StringView[],
    )
    @test AeronTensorPool.entry_matches!(
        entry,
        UInt32(10),
        UInt32(20),
        UInt64(30),
        StringView("CameraA"),
        [StringView("tag1")],
    )
    @test !AeronTensorPool.entry_matches!(
        entry,
        UInt32(10),
        UInt32(20),
        UInt64(30),
        StringView("CameraA"),
        [StringView("tag3")],
    )
    @test AeronTensorPool.entry_matches!(
        entry,
        UInt32(10),
        UInt32(20),
        UInt64(30),
        StringView("CameraA"),
        [StringView("tag1"), StringView("tag2")],
    )
end
