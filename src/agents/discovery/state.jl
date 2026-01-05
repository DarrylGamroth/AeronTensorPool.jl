"""
Runtime state for discovery providers and registries.
"""
mutable struct DiscoveryRuntime
    client::Aeron.Client
    sub_requests::Aeron.Subscription
    sub_announce::Aeron.Subscription
    sub_metadata::Union{Aeron.Subscription, Nothing}
    request_decoder::DiscoveryRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    response_encoder::DiscoveryResponse.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_announce_decoder::DataSourceAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    metadata_meta_decoder::DataSourceMeta.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    response_buf::Vector{UInt8}
    response_claim::Aeron.BufferClaim
    pubs::Dict{Tuple{String, Int32}, Aeron.Publication}
end

abstract type AbstractDiscoveryState end

"""
Discovery provider state.
"""
mutable struct DiscoveryProviderState{ClockT<:Clocks.AbstractClock} <: AbstractDiscoveryState
    config::DiscoveryConfig
    clock::ClockT
    runtime::DiscoveryRuntime
    entries::Dict{Tuple{String, UInt32}, DiscoveryEntry}
    request_tags::Vector{StringView}
    matching_entries::Vector{DiscoveryEntry}
    work_count::Int
end
