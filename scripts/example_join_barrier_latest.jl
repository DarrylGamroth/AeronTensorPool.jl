#!/usr/bin/env julia
using AeronTensorPool

const Merge = AeronTensorPool.ShmTensorpoolMerge

function main()
    out_stream = UInt32(9002)
    epoch = UInt64(1)
    now_ns = UInt64(0)

    config = JoinBarrierConfig(out_stream, LATEST_VALUE, false, false)
    state = JoinBarrierState(config)

    rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(10001), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
        SequenceMergeRule(UInt32(10002), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    map = SequenceMergeMap(out_stream, epoch, nothing, rules)
    apply_sequence_merge_map!(state, map)

    result = join_barrier_ready!(state, UInt64(0), now_ns)
    println("ready before observations: $(result.ready) missing=$(result.missing_count)")

    update_observed_seq_epoch!(state, UInt32(10001), epoch, UInt64(10), now_ns)
    update_observed_seq_epoch!(state, UInt32(10002), epoch, UInt64(12), now_ns)
    result = join_barrier_ready!(state, UInt64(0), now_ns)
    println("ready after observations: $(result.ready)")

    invalidate_latest!(state, UInt32(10002))
    result = join_barrier_ready!(state, UInt64(0), now_ns)
    println("ready after invalidate: $(result.ready) missing=$(result.missing_count)")
end

main()
