using Random

@testset "Metadata chunk validation" begin
    offsets = UInt32[0, 1024, 2048]
    lengths = UInt32[512, 512, 512]
    @test AeronTensorPool.validate_metadata_chunks(offsets, lengths)

    @test !AeronTensorPool.validate_metadata_chunks(UInt32[0], UInt32[0])
    @test !AeronTensorPool.validate_metadata_chunks(UInt32[0], UInt32[128 * 1024])
    @test !AeronTensorPool.validate_metadata_chunks(UInt32[1024, 0], UInt32[512, 512])

    rng = Random.MersenneTwister(0x4d3e_0c51)
    for _ in 1:200
        nchunks = rand(rng, 0:8)
        offsets = UInt32[]
        lengths = UInt32[]
        cursor = UInt32(0)
        for _ in 1:nchunks
            gap = UInt32(rand(rng, 0:256))
            len = UInt32(rand(rng, 1:Int(AeronTensorPool.METADATA_CHUNK_MAX)))
            cursor += gap
            push!(offsets, cursor)
            push!(lengths, len)
            cursor += len
        end
        @test AeronTensorPool.validate_metadata_chunks(offsets, lengths)

        if nchunks > 0
            bad_lengths = copy(lengths)
            bad_lengths[rand(rng, 1:nchunks)] = UInt32(0)
            @test !AeronTensorPool.validate_metadata_chunks(offsets, bad_lengths)

            bad_lengths = copy(lengths)
            bad_lengths[rand(rng, 1:nchunks)] = AeronTensorPool.METADATA_CHUNK_MAX + UInt32(1)
            @test !AeronTensorPool.validate_metadata_chunks(offsets, bad_lengths)
        end

        if nchunks > 1
            bad_offsets = copy(offsets)
            bad_offsets[2] = UInt32(0)
            @test !AeronTensorPool.validate_metadata_chunks(bad_offsets, lengths)
        end
    end
end
