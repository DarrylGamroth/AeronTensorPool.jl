"""
Join barrier mode selection.
"""
@enum JoinBarrierMode::UInt8 begin
    SEQUENCE = 1
    TIMESTAMP = 2
    LATEST_VALUE = 3
end

"""
Configuration for join barrier evaluation.
"""
struct JoinBarrierConfig
    out_stream_id::UInt32
    mode::JoinBarrierMode
    use_processed_cursor::Bool
    latest_value_use_timestamp::Bool
end

"""
Sequence MergeMap rule (OFFSET or WINDOW).
"""
struct SequenceMergeRule
    input_stream_id::UInt32
    rule_type::Merge.MergeRuleType.SbeEnum
    offset::Union{Nothing, Int32}
    window_size::Union{Nothing, UInt32}
end

"""
Sequence MergeMap for an output stream and epoch.
"""
struct SequenceMergeMap
    out_stream_id::UInt32
    epoch::UInt64
    stale_timeout_ns::Union{Nothing, UInt64}
    rules::Vector{SequenceMergeRule}
end

"""
Timestamp MergeMap rule (OFFSET_NS or WINDOW_NS).
"""
struct TimestampMergeRule
    input_stream_id::UInt32
    rule_type::Merge.MergeTimeRuleType.SbeEnum
    timestamp_source::Merge.TimestampSource.SbeEnum
    offset_ns::Union{Nothing, Int64}
    window_ns::Union{Nothing, UInt64}
end

"""
Timestamp MergeMap for an output stream and epoch.
"""
struct TimestampMergeMap
    out_stream_id::UInt32
    epoch::UInt64
    stale_timeout_ns::Union{Nothing, UInt64}
    clock_domain::Merge.ClockDomain.SbeEnum
    lateness_ns::UInt64
    rules::Vector{TimestampMergeRule}
end
