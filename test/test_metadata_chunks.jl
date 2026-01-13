@testset "Metadata chunk validation" begin
    offsets = UInt32[0, 1024, 2048]
    lengths = UInt32[512, 512, 512]
    @test AeronTensorPool.validate_metadata_chunks(offsets, lengths)

    @test !AeronTensorPool.validate_metadata_chunks(UInt32[0], UInt32[0])
    @test !AeronTensorPool.validate_metadata_chunks(UInt32[0], UInt32[128 * 1024])
    @test !AeronTensorPool.validate_metadata_chunks(UInt32[1024, 0], UInt32[512, 512])
end
