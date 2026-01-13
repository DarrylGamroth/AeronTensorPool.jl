#!/usr/bin/env julia
using AeronTensorPool

const Merge = AeronTensorPool.ShmTensorpoolMerge

function main()
    out_stream = UInt32(9001)
    epoch = UInt64(1)
    out_time = UInt64(1_000_000)
    now_ns = UInt64(0)

    config = JoinBarrierConfig(out_stream, TIMESTAMP, false, false)
    state = JoinBarrierState(config)

    rules = TimestampMergeRule[
        TimestampMergeRule(
            UInt32(10001),
            Merge.MergeTimeRuleType.OFFSET_NS,
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            Int64(0),
            nothing,
        ),
    ]
    map = TimestampMergeMap(
        out_stream,
        epoch,
        nothing,
        Merge.ClockDomain.MONOTONIC,
        UInt64(0),
        rules,
    )
    apply_timestamp_merge_map!(state, map)

    result = join_barrier_ready!(state, out_time, now_ns)
    println("ready before observation: $(result.ready) missing=$(result.missing_count)")

    update_observed_time_epoch!(
        state,
        UInt32(10001),
        epoch,
        Merge.TimestampSource.FRAME_DESCRIPTOR,
        out_time,
        now_ns,
        Merge.ClockDomain.MONOTONIC,
    )

    result = join_barrier_ready!(state, out_time, now_ns)
    println("ready after observation: $(result.ready)")
end

main()
