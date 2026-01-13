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

@testset "JoinBarrier latest value uses timestamps" begin
    config = JoinBarrierConfig(UInt32(9), LATEST_VALUE, false, true)
    state = JoinBarrierState(config)
    rules = TimestampMergeRule[
        TimestampMergeRule(
            UInt32(1),
            Merge.MergeTimeRuleType.OFFSET_NS,
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            Int64(0),
            nothing,
        ),
    ]
    map = TimestampMergeMap(
        UInt32(9),
        UInt64(1),
        nothing,
        Merge.ClockDomain.MONOTONIC,
        UInt64(0),
        rules,
    )
    @test apply_timestamp_merge_map!(state, map)

    update_observed_seq!(state, UInt32(1), UInt64(5), UInt64(0))
    result = join_barrier_ready!(state, UInt64(0), UInt64(0))
    @test !result.ready

    update_observed_time_epoch!(
        state,
        UInt32(1),
        UInt64(1),
        Merge.TimestampSource.FRAME_DESCRIPTOR,
        UInt64(123),
        UInt64(0),
        Merge.ClockDomain.MONOTONIC,
    )
    result = join_barrier_ready!(state, UInt64(0), UInt64(0))
    @test result.ready
end
