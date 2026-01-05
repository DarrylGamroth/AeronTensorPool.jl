"""
Runtime state for the discovery registry.
"""
mutable struct DiscoveryRegistryRuntime
    client::Aeron.Client
    sub_requests::Aeron.Subscription
    announce_subs::Vector{Aeron.Subscription}
    metadata_subs::Vector{Union{Aeron.Subscription, Nothing}}
    request_decoder::DiscoveryRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    response_encoder::DiscoveryResponse.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_announce_decoder::DataSourceAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_decoder::DataSourceMeta.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    response_buf::Vector{UInt8}
    response_claim::Aeron.BufferClaim
    pubs::Dict{Tuple{String, Int32}, Aeron.Publication}
end

"""
Discovery registry state.
"""
mutable struct DiscoveryRegistryState{ClockT<:Clocks.AbstractClock} <: AbstractDiscoveryState
    config::DiscoveryRegistryConfig
    clock::ClockT
    runtime::DiscoveryRegistryRuntime
    entries::Dict{Tuple{String, UInt32}, DiscoveryEntry}
    request_tags::Vector{StringView}
    matching_entries::Vector{DiscoveryEntry}
    work_count::Int
end
