using Test
using AeronTensorPool

const Merge = AeronTensorPool.ShmTensorpoolMerge

@testset "JoinBarrier sequence readiness" begin
    config = JoinBarrierConfig(UInt32(10), SEQUENCE, false, false)
    state = JoinBarrierState(config)
    rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
        SequenceMergeRule(UInt32(2), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    map = SequenceMergeMap(UInt32(10), UInt64(1), nothing, rules)
    @test apply_sequence_merge_map!(state, map)

    result = join_barrier_ready!(state, UInt64(5), UInt64(10))
    @test !result.ready
    @test result.missing_count == 2
    @test result.missing_inputs[1] == UInt32(1)
    @test result.missing_inputs[2] == UInt32(2)

    update_observed_seq!(state, UInt32(1), UInt64(5), UInt64(10))
    result = join_barrier_ready!(state, UInt64(5), UInt64(10))
    @test !result.ready
    @test result.missing_count == 1
    @test result.missing_inputs[1] == UInt32(2)

    update_observed_seq!(state, UInt32(2), UInt64(5), UInt64(10))
    result = join_barrier_ready!(state, UInt64(5), UInt64(10))
    @test result.ready
end

@testset "JoinBarrier sequence processed cursor" begin
    config = JoinBarrierConfig(UInt32(10), SEQUENCE, true, false)
    state = JoinBarrierState(config)
    rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    map = SequenceMergeMap(UInt32(10), UInt64(1), nothing, rules)
    @test apply_sequence_merge_map!(state, map)

    update_observed_seq!(state, UInt32(1), UInt64(5), UInt64(10))
    result = join_barrier_ready!(state, UInt64(5), UInt64(10))
    @test !result.ready

    update_processed_seq!(state, UInt32(1), UInt64(5))
    result = join_barrier_ready!(state, UInt64(5), UInt64(10))
    @test result.ready
end

@testset "JoinBarrier sequence epoch resets" begin
    config = JoinBarrierConfig(UInt32(10), SEQUENCE, false, false)
    state = JoinBarrierState(config)
    rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    map = SequenceMergeMap(UInt32(10), UInt64(1), nothing, rules)
    @test apply_sequence_merge_map!(state, map)

    update_observed_seq_epoch!(state, UInt32(1), UInt64(1), UInt64(10), UInt64(10))
    result = join_barrier_ready!(state, UInt64(10), UInt64(10))
    @test result.ready

    update_observed_seq_epoch!(state, UInt32(1), UInt64(2), UInt64(5), UInt64(20))
    result = join_barrier_ready!(state, UInt64(10), UInt64(20))
    @test !result.ready
end

@testset "JoinBarrier sequence output monotonic" begin
    config = JoinBarrierConfig(UInt32(10), SEQUENCE, false, false)
    state = JoinBarrierState(config)
    rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    map = SequenceMergeMap(UInt32(10), UInt64(1), nothing, rules)
    @test apply_sequence_merge_map!(state, map)

    result = join_barrier_ready!(state, UInt64(10), UInt64(0))
    @test !result.output_rejected
    result = join_barrier_ready!(state, UInt64(9), UInt64(0))
    @test result.output_rejected
    @test !result.ready
end
