"""
Pending frame buffer for rate limiting.
"""
mutable struct RateLimiterPending
    valid::Bool
    seq::UInt64
    trace_id::UInt64
    header::SlotHeader
    payload_len::UInt32
    payload_buf::Vector{UInt8}
end

"""
Mapping-specific state for the rate limiter.
"""
mutable struct RateLimiterMappingState
    mapping::RateLimiterMapping
    lifecycle::RateLimiterMappingLifecycle
    consumer_agent::ConsumerAgent
    producer_agent::ProducerAgent
    metadata_pub::Union{Aeron.Publication, Nothing}
    metadata_claim::Aeron.BufferClaim
    dest_consumer_id::UInt32
    max_rate_hz::UInt32
    next_allowed_ns::UInt64
    last_source_epoch::UInt64
    pending::RateLimiterPending
    scratch_dims::FixedSizeVectorDefault{Int32}
    scratch_strides::FixedSizeVectorDefault{Int32}
end

"""
Rate limiter state for all mappings.
"""
mutable struct RateLimiterState
    config::RateLimiterConfig
    clock::Clocks.CachedEpochClock
    mappings::Vector{RateLimiterMappingState}
    mapping_by_source::Dict{UInt32, RateLimiterMappingState}
    metadata_sub::Union{Aeron.Subscription, Nothing}
    metadata_asm::Union{Aeron.FragmentAssembler, Nothing}
    control_sub::Union{Aeron.Subscription, Nothing}
    control_pub::Union{Aeron.Publication, Nothing}
    control_asm::Union{Aeron.FragmentAssembler, Nothing}
    qos_sub::Union{Aeron.Subscription, Nothing}
    qos_pub::Union{Aeron.Publication, Nothing}
    qos_asm::Union{Aeron.FragmentAssembler, Nothing}
    metadata_announce_encoder::DataSourceAnnounce.Encoder
    metadata_meta_encoder::DataSourceMeta.Encoder
    progress_encoder::FrameProgress.Encoder
    qos_producer_encoder::QosProducer.Encoder
    qos_consumer_encoder::QosConsumer.Encoder
    control_claim::Aeron.BufferClaim
    qos_claim::Aeron.BufferClaim
end
