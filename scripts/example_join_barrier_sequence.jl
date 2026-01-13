#!/usr/bin/env julia
using AeronTensorPool

const Merge = AeronTensorPool.ShmTensorpoolMerge

function main()
    out_stream = UInt32(9000)
    epoch = UInt64(1)
    out_seq = UInt64(5)
    now_ns = UInt64(0)

    config = JoinBarrierConfig(out_stream, SEQUENCE, false, false)
    state = JoinBarrierState(config)

    rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(10001), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
        SequenceMergeRule(UInt32(10002), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
    ]
    map = SequenceMergeMap(out_stream, epoch, nothing, rules)
    apply_sequence_merge_map!(state, map)

    result = join_barrier_ready!(state, out_seq, now_ns)
    println("ready before observations: $(result.ready) missing=$(result.missing_count)")

    update_observed_seq_epoch!(state, UInt32(10001), epoch, out_seq, now_ns)
    update_observed_seq_epoch!(state, UInt32(10002), epoch, out_seq, now_ns)

    result = join_barrier_ready!(state, out_seq, now_ns)
    println("ready after observations: $(result.ready)")
end

main()
