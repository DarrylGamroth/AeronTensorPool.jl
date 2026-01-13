using Test
using AeronTensorPool

const Merge = AeronTensorPool.ShmTensorpoolMerge

@testset "JoinBarrier latest value readiness" begin
    config = JoinBarrierConfig(UInt32(9), LATEST_VALUE, false, false)
    state = JoinBarrierState(config)
    rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
        SequenceMergeRule(UInt32(2), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    map = SequenceMergeMap(UInt32(9), UInt64(1), nothing, rules)
    @test apply_sequence_merge_map!(state, map)

    result = join_barrier_ready!(state, UInt64(0), UInt64(0))
    @test !result.ready
    @test result.missing_count == 2

    update_observed_seq!(state, UInt32(1), UInt64(1), UInt64(0))
    result = join_barrier_ready!(state, UInt64(0), UInt64(0))
    @test !result.ready
    @test result.missing_count == 1
    @test result.missing_inputs[1] == UInt32(2)

    update_observed_seq!(state, UInt32(2), UInt64(1), UInt64(0))
    result = join_barrier_ready!(state, UInt64(0), UInt64(0))
    @test result.ready
end
