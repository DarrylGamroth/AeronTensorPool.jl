using Random

const Merge = AeronTensorPool.ShmTensorpoolMerge

@testset "JoinBarrier validation fuzz" begin
    rng = Random.MersenneTwister(0x63f2_8a71)

    @test AeronTensorPool.Agents.JoinBarrier.validate_join_barrier_config(
        JoinBarrierConfig(UInt32(1), SEQUENCE, false, false),
    ).out_stream_id == UInt32(1)
    @test_throws ArgumentError AeronTensorPool.Agents.JoinBarrier.validate_join_barrier_config(
        JoinBarrierConfig(UInt32(0), SEQUENCE, false, false),
    )

    for _ in 1:200
        rule_type = rand(rng, (Merge.MergeRuleType.OFFSET, Merge.MergeRuleType.WINDOW))
        offset = rand(rng, Bool) ? Int32(rand(rng, -5:5)) : nothing
        window = rand(rng, Bool) ? UInt32(rand(rng, 0:5)) : nothing
        rule = SequenceMergeRule(UInt32(rand(rng, 1:10)), rule_type, offset, window)
        expected = rule_type == Merge.MergeRuleType.OFFSET ?
            (offset !== nothing && window === nothing) :
            (window !== nothing && window > 0 && offset === nothing)
        @test AeronTensorPool.Agents.JoinBarrier.validate_sequence_rule(rule) == expected
    end

    for _ in 1:200
        rule_type = rand(rng, (Merge.MergeTimeRuleType.OFFSET_NS, Merge.MergeTimeRuleType.WINDOW_NS))
        offset = rand(rng, Bool) ? Int64(rand(rng, -5:5)) : nothing
        window = rand(rng, Bool) ? UInt64(rand(rng, 0:5)) : nothing
        rule = TimestampMergeRule(
            UInt32(rand(rng, 1:10)),
            rule_type,
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            offset,
            window,
        )
        expected = rule_type == Merge.MergeTimeRuleType.OFFSET_NS ?
            (offset !== nothing && window === nothing) :
            (window !== nothing && window > 0 && offset === nothing)
        @test AeronTensorPool.Agents.JoinBarrier.validate_timestamp_rule(rule) == expected
    end
end
