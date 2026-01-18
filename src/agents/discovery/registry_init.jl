"""
Initialize a discovery registry: create Aeron resources and state.

Arguments:
- `config`: discovery registry configuration.
- `client`: TensorPool client (owns Aeron resources).

Returns:
- `DiscoveryRegistryState` initialized for polling.
"""
function init_discovery_registry(config::DiscoveryRegistryConfig; client::AbstractTensorPoolClient)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    aeron_client = client.aeron_client
    sub_requests = Aeron.add_subscription(aeron_client, config.channel, config.stream_id)
    announce_subs = Vector{Aeron.Subscription}(undef, length(config.endpoints))
    metadata_subs = Vector{Union{Aeron.Subscription, Nothing}}(undef, length(config.endpoints))
    for (idx, endpoint) in pairs(config.endpoints)
        announce_subs[idx] =
            Aeron.add_subscription(aeron_client, endpoint.announce_channel, endpoint.announce_stream_id)
        metadata_subs[idx] =
            isempty(endpoint.metadata_channel) || endpoint.metadata_stream_id == 0 ?
            nothing : Aeron.add_subscription(aeron_client, endpoint.metadata_channel, endpoint.metadata_stream_id)
    end

    response_buf_bytes =
        config.response_buf_bytes == 0 ? DISCOVERY_RESPONSE_BUF_BYTES : config.response_buf_bytes

    runtime = DiscoveryRegistryRuntime(
        aeron_client,
        sub_requests,
        announce_subs,
        metadata_subs,
        DiscoveryRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DiscoveryResponse.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Vector{UInt8}(undef, Int(response_buf_bytes)),
        Aeron.BufferClaim(),
        Dict{Tuple{String, Int32}, Aeron.Publication}(),
    )

    entries = Dict{Tuple{String, UInt32}, DiscoveryEntry}()
    request_tags = Vector{StringView}()
    sizehint!(request_tags, 8)
    matching_entries = Vector{DiscoveryEntry}()
    sizehint!(matching_entries, Int(config.max_results))

    return DiscoveryRegistryState(
        config,
        clock,
        runtime,
        entries,
        request_tags,
        matching_entries,
        0,
    )
end
