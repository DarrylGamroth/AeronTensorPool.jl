using Test
using AeronTensorPool

const Merge = AeronTensorPool.ShmTensorpoolMerge

@testset "JoinBarrier timestamp readiness" begin
    config = JoinBarrierConfig(UInt32(42), TIMESTAMP, false, false)
    state = JoinBarrierState(config)
    rules = TimestampMergeRule[
        TimestampMergeRule(
            UInt32(7),
            Merge.MergeTimeRuleType.OFFSET_NS,
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            Int64(0),
            nothing,
        ),
    ]
    map = TimestampMergeMap(
        UInt32(42),
        UInt64(1),
        UInt64(10),
        Merge.ClockDomain.MONOTONIC,
        UInt64(0),
        rules,
    )
    @test apply_timestamp_merge_map!(state, map)

    result = join_barrier_ready!(state, UInt64(100), UInt64(0))
    @test !result.ready
    @test result.missing_count == 1

    update_observed_time!(
        state,
        UInt32(7),
        Merge.TimestampSource.FRAME_DESCRIPTOR,
        UInt64(100),
        UInt64(5),
        Merge.ClockDomain.MONOTONIC,
    )
    result = join_barrier_ready!(state, UInt64(100), UInt64(5))
    @test result.ready
end

@testset "JoinBarrier timestamp stale input" begin
    config = JoinBarrierConfig(UInt32(42), TIMESTAMP, false, false)
    state = JoinBarrierState(config)
    rules = TimestampMergeRule[
        TimestampMergeRule(
            UInt32(7),
            Merge.MergeTimeRuleType.OFFSET_NS,
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            Int64(0),
            nothing,
        ),
    ]
    map = TimestampMergeMap(
        UInt32(42),
        UInt64(1),
        UInt64(10),
        Merge.ClockDomain.MONOTONIC,
        UInt64(0),
        rules,
    )
    @test apply_timestamp_merge_map!(state, map)

    update_observed_time!(
        state,
        UInt32(7),
        Merge.TimestampSource.FRAME_DESCRIPTOR,
        UInt64(100),
        UInt64(5),
        Merge.ClockDomain.MONOTONIC,
    )
    result = join_barrier_ready!(state, UInt64(200), UInt64(20))
    @test result.stale_count == 1
    @test result.stale_inputs[1] == UInt32(7)
end
