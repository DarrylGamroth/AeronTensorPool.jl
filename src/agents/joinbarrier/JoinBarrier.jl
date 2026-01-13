module JoinBarrier

using ...Core
using ...Core.TPLog
using ...Aeron
using ...Agent
using ...AeronUtils
using ...Clocks
using ...Control: DEFAULT_FRAGMENT_LIMIT
using ...SBE
using ...UnsafeArrays
import ...ShmTensorpoolControl
import ...ShmTensorpoolMerge

const Control = ShmTensorpoolControl
const Merge = ShmTensorpoolMerge

include("types.jl")
include("state.jl")
include("merge_map.jl")
include("barrier.jl")
include("codec.jl")
include("agent.jl")

export JoinBarrierMode,
    SEQUENCE,
    TIMESTAMP,
    LATEST_VALUE,
    JoinBarrierConfig,
    JoinBarrierResult,
    JoinBarrierState,
    SequenceMergeRule,
    SequenceMergeMap,
    TimestampMergeRule,
    TimestampMergeMap,
    JoinBarrierCodec,
    MergeMapAuthority,
    join_barrier_ready!,
    sequence_ready!,
    timestamp_ready!,
    latest_value_ready!,
    apply_sequence_merge_map!,
    apply_timestamp_merge_map!,
    update_observed_seq!,
    update_processed_seq!,
    update_observed_time!,
    update_processed_time!,
    encode_sequence_merge_map_announce!,
    encode_sequence_merge_map_request!,
    encode_timestamp_merge_map_announce!,
    encode_timestamp_merge_map_request!,
    decode_sequence_merge_map_announce,
    decode_timestamp_merge_map_announce,
    send_sequence_merge_map_request!,
    send_timestamp_merge_map_request!,
    publish_sequence_merge_map!,
    publish_timestamp_merge_map!,
    JoinBarrierAgent

end
