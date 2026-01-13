@testset "Allocation checks: join barrier" begin
    out_stream = UInt32(9000)
    epoch = UInt64(1)
    now_ns = UInt64(0)

    config = JoinBarrierConfig(out_stream, SEQUENCE, false, false)
    state = JoinBarrierState(config)
    seq_rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(1), AeronTensorPool.ShmTensorpoolMerge.MergeRuleType.OFFSET, Int32(0), nothing),
        SequenceMergeRule(UInt32(2), AeronTensorPool.ShmTensorpoolMerge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    seq_map = SequenceMergeMap(out_stream, epoch, nothing, seq_rules)
    apply_sequence_merge_map!(state, seq_map)

    update_observed_seq_epoch!(state, UInt32(1), epoch, UInt64(10), now_ns)
    update_processed_seq_epoch!(state, UInt32(1), epoch, UInt64(10))
    join_barrier_ready!(state, UInt64(10), now_ns)

    GC.gc()
    @test @allocated(begin
        update_observed_seq_epoch!(state, UInt32(1), epoch, UInt64(10), now_ns)
        update_processed_seq_epoch!(state, UInt32(1), epoch, UInt64(10))
        join_barrier_ready!(state, UInt64(10), now_ns)
    end) == 0

    ts_config = JoinBarrierConfig(UInt32(9001), TIMESTAMP, false, false)
    ts_state = JoinBarrierState(ts_config)
    ts_rules = TimestampMergeRule[
        TimestampMergeRule(
            UInt32(3),
            AeronTensorPool.ShmTensorpoolMerge.MergeTimeRuleType.OFFSET_NS,
            AeronTensorPool.ShmTensorpoolMerge.TimestampSource.FRAME_DESCRIPTOR,
            Int64(0),
            nothing,
        ),
    ]
    ts_map = TimestampMergeMap(
        UInt32(9001),
        epoch,
        nothing,
        AeronTensorPool.ShmTensorpoolMerge.ClockDomain.MONOTONIC,
        UInt64(0),
        ts_rules,
    )
    apply_timestamp_merge_map!(ts_state, ts_map)

    update_observed_time_epoch!(
        ts_state,
        UInt32(3),
        epoch,
        AeronTensorPool.ShmTensorpoolMerge.TimestampSource.FRAME_DESCRIPTOR,
        UInt64(100),
        now_ns,
        AeronTensorPool.ShmTensorpoolMerge.ClockDomain.MONOTONIC,
    )
    join_barrier_ready!(ts_state, UInt64(100), now_ns)

    GC.gc()
    @test @allocated(begin
        update_observed_time_epoch!(
            ts_state,
            UInt32(3),
            epoch,
            AeronTensorPool.ShmTensorpoolMerge.TimestampSource.FRAME_DESCRIPTOR,
            UInt64(100),
            now_ns,
            AeronTensorPool.ShmTensorpoolMerge.ClockDomain.MONOTONIC,
        )
        join_barrier_ready!(ts_state, UInt64(100), now_ns)
    end) == 0

    latest_config = JoinBarrierConfig(UInt32(9002), LATEST_VALUE, false, false)
    latest_state = JoinBarrierState(latest_config)
    latest_rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(4), AeronTensorPool.ShmTensorpoolMerge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    latest_map = SequenceMergeMap(UInt32(9002), epoch, nothing, latest_rules)
    apply_sequence_merge_map!(latest_state, latest_map)

    update_observed_seq_epoch!(latest_state, UInt32(4), epoch, UInt64(1), now_ns)
    join_barrier_ready!(latest_state, UInt64(0), now_ns)
    invalidate_latest!(latest_state, UInt32(4))

    GC.gc()
    @test @allocated(begin
        update_observed_seq_epoch!(latest_state, UInt32(4), epoch, UInt64(1), now_ns)
        join_barrier_ready!(latest_state, UInt64(0), now_ns)
        invalidate_latest!(latest_state, UInt32(4))
    end) == 0
end
