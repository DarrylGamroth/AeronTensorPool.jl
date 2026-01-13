"""
Join barrier readiness result with missing and stale inputs.
"""
mutable struct JoinBarrierResult
    ready::Bool
    missing_count::Int
    stale_count::Int
    missing_inputs::Vector{UInt32}
    stale_inputs::Vector{UInt32}
end

"""
Join barrier state for a single output stream.
"""
mutable struct JoinBarrierState
    config::JoinBarrierConfig
    sequence_map::Union{SequenceMergeMap, Nothing}
    timestamp_map::Union{TimestampMergeMap, Nothing}
    active_epoch::UInt64
    stale_timeout_ns::Union{Nothing, UInt64}
    clock_domain::Union{Nothing, Merge.ClockDomain.SbeEnum}
    lateness_ns::UInt64
    input_ids::Vector{UInt32}
    time_keys::Vector{UInt64}
    input_index::Dict{UInt32, Vector{Int}}
    time_index::Dict{UInt64, Vector{Int}}
    observed_seq::Vector{UInt64}
    processed_seq::Vector{UInt64}
    observed_time::Vector{UInt64}
    processed_time::Vector{UInt64}
    last_observed_ns::Vector{UInt64}
    seen_any::Vector{Bool}
    result::JoinBarrierResult
end

function JoinBarrierResult()
    return JoinBarrierResult(false, 0, 0, UInt32[], UInt32[])
end

function JoinBarrierState(config::JoinBarrierConfig)
    return JoinBarrierState(
        config,
        nothing,
        nothing,
        UInt64(0),
        nothing,
        nothing,
        UInt64(0),
        UInt32[],
        UInt64[],
        Dict{UInt32, Vector{Int}}(),
        Dict{UInt64, Vector{Int}}(),
        UInt64[],
        UInt64[],
        UInt64[],
        UInt64[],
        UInt64[],
        Bool[],
        JoinBarrierResult(),
    )
end
