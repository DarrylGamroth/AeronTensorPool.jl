using Test
using AeronTensorPool

const Merge = AeronTensorPool.ShmTensorpoolMerge

@testset "JoinBarrier spec examples" begin
    @testset "Aligned join (Appendix A.3.1)" begin
        config = JoinBarrierConfig(UInt32(9000), SEQUENCE, false, false)
        state = JoinBarrierState(config)
        rules = SequenceMergeRule[
            SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
            SequenceMergeRule(UInt32(2), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
        ]
        map = SequenceMergeMap(UInt32(9000), UInt64(1), nothing, rules)
        @test apply_sequence_merge_map!(state, map)

        update_observed_seq_epoch!(state, UInt32(1), UInt64(1), UInt64(12034), UInt64(0))
        update_observed_seq_epoch!(state, UInt32(2), UInt64(1), UInt64(12034), UInt64(0))
        result = join_barrier_ready!(state, UInt64(12034), UInt64(0))
        @test result.ready
    end

    @testset "Offset compensation (Appendix A.3.2)" begin
        config = JoinBarrierConfig(UInt32(9001), SEQUENCE, false, false)
        state = JoinBarrierState(config)
        rules = SequenceMergeRule[
            SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
            SequenceMergeRule(UInt32(2), Merge.MergeRuleType.OFFSET, Int32(-2), nothing),
        ]
        map = SequenceMergeMap(UInt32(9001), UInt64(1), nothing, rules)
        @test apply_sequence_merge_map!(state, map)

        update_observed_seq_epoch!(state, UInt32(1), UInt64(1), UInt64(12034), UInt64(0))
        update_observed_seq_epoch!(state, UInt32(2), UInt64(1), UInt64(12031), UInt64(0))
        result = join_barrier_ready!(state, UInt64(12034), UInt64(0))
        @test !result.ready

        update_observed_seq_epoch!(state, UInt32(2), UInt64(1), UInt64(12032), UInt64(0))
        result = join_barrier_ready!(state, UInt64(12034), UInt64(0))
        @test result.ready
    end

    @testset "Sliding window (Appendix A.3.3)" begin
        config = JoinBarrierConfig(UInt32(9002), SEQUENCE, false, false)
        state = JoinBarrierState(config)
        rules = SequenceMergeRule[
            SequenceMergeRule(UInt32(1), Merge.MergeRuleType.WINDOW, nothing, UInt32(5)),
        ]
        map = SequenceMergeMap(UInt32(9002), UInt64(1), nothing, rules)
        @test apply_sequence_merge_map!(state, map)

        update_observed_seq_epoch!(state, UInt32(1), UInt64(1), UInt64(9), UInt64(0))
        result = join_barrier_ready!(state, UInt64(10), UInt64(0))
        @test !result.ready

        update_observed_seq_epoch!(state, UInt32(1), UInt64(1), UInt64(10), UInt64(0))
        result = join_barrier_ready!(state, UInt64(10), UInt64(0))
        @test result.ready
    end

    @testset "Timestamp offset join (Appendix A.4.1)" begin
        config = JoinBarrierConfig(UInt32(9003), TIMESTAMP, false, false)
        state = JoinBarrierState(config)
        rules = TimestampMergeRule[
            TimestampMergeRule(
                UInt32(1),
                Merge.MergeTimeRuleType.OFFSET_NS,
                Merge.TimestampSource.FRAME_DESCRIPTOR,
                Int64(0),
                nothing,
            ),
            TimestampMergeRule(
                UInt32(2),
                Merge.MergeTimeRuleType.OFFSET_NS,
                Merge.TimestampSource.FRAME_DESCRIPTOR,
                Int64(-5_000_000),
                nothing,
            ),
        ]
        map = TimestampMergeMap(
            UInt32(9003),
            UInt64(1),
            nothing,
            Merge.ClockDomain.REALTIME_SYNCED,
            UInt64(0),
            rules,
        )
        @test apply_timestamp_merge_map!(state, map)

        out_time = UInt64(1_700_000_000_000_000_000)
        update_observed_time_epoch!(
            state,
            UInt32(1),
            UInt64(1),
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            out_time,
            UInt64(0),
            Merge.ClockDomain.REALTIME_SYNCED,
        )
        update_observed_time_epoch!(
            state,
            UInt32(2),
            UInt64(1),
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            UInt64(1_699_999_999_995_000_000),
            UInt64(0),
            Merge.ClockDomain.REALTIME_SYNCED,
        )
        result = join_barrier_ready!(state, out_time, UInt64(0))
        @test result.ready
    end

    @testset "Input-driven timestamp join (Appendix A.4.2)" begin
        config = JoinBarrierConfig(UInt32(9004), TIMESTAMP, false, false)
        state = JoinBarrierState(config)
        rules = TimestampMergeRule[
            TimestampMergeRule(
                UInt32(1),
                Merge.MergeTimeRuleType.OFFSET_NS,
                Merge.TimestampSource.FRAME_DESCRIPTOR,
                Int64(0),
                nothing,
            ),
            TimestampMergeRule(
                UInt32(2),
                Merge.MergeTimeRuleType.WINDOW_NS,
                Merge.TimestampSource.FRAME_DESCRIPTOR,
                nothing,
                UInt64(10_000_000),
            ),
        ]
        map = TimestampMergeMap(
            UInt32(9004),
            UInt64(1),
            nothing,
            Merge.ClockDomain.MONOTONIC,
            UInt64(0),
            rules,
        )
        @test apply_timestamp_merge_map!(state, map)

        out_time = UInt64(20_000_000)
        update_observed_time_epoch!(
            state,
            UInt32(1),
            UInt64(1),
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            out_time,
            UInt64(0),
            Merge.ClockDomain.MONOTONIC,
        )
        update_observed_time_epoch!(
            state,
            UInt32(2),
            UInt64(1),
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            UInt64(15_000_000),
            UInt64(0),
            Merge.ClockDomain.MONOTONIC,
        )
        result = join_barrier_ready!(state, out_time, UInt64(0))
        @test result.ready
    end

    @testset "Stale input degradation (Appendix A.5.1)" begin
        config = JoinBarrierConfig(UInt32(9005), SEQUENCE, false, false)
        state = JoinBarrierState(config)
        rules = SequenceMergeRule[
            SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
            SequenceMergeRule(UInt32(2), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
        ]
        map = SequenceMergeMap(UInt32(9005), UInt64(1), UInt64(5_000_000_000), rules)
        @test apply_sequence_merge_map!(state, map)

        update_observed_seq_epoch!(state, UInt32(1), UInt64(1), UInt64(10), UInt64(1))
        update_observed_seq_epoch!(state, UInt32(2), UInt64(1), UInt64(10), UInt64(1))
        result = join_barrier_ready!(state, UInt64(10), UInt64(6_000_000_000))
        @test result.ready

        update_observed_seq_epoch!(state, UInt32(1), UInt64(1), UInt64(11), UInt64(6_000_000_000))
        result = join_barrier_ready!(state, UInt64(11), UInt64(12_000_000_000))
        @test result.stale_count == 1
        @test result.stale_inputs[1] == UInt32(2)
    end
end
