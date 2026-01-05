"""
Initialize a discovery provider: create Aeron resources and state.

Arguments:
- `config`: discovery configuration.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `DiscoveryProviderState` initialized for polling.
"""
function init_discovery_provider(config::DiscoveryConfig; client::Aeron.Client)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    sub_requests = Aeron.add_subscription(client, config.channel, config.stream_id)
    sub_announce = Aeron.add_subscription(client, config.announce_channel, config.announce_stream_id)
    sub_metadata =
        isempty(config.metadata_channel) || config.metadata_stream_id == 0 ?
        nothing : Aeron.add_subscription(client, config.metadata_channel, config.metadata_stream_id)

    response_buf_bytes =
        config.response_buf_bytes == 0 ? DISCOVERY_RESPONSE_BUF_BYTES : config.response_buf_bytes

    runtime = DiscoveryRuntime(
        client,
        sub_requests,
        sub_announce,
        sub_metadata,
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

    return DiscoveryProviderState(
        config,
        clock,
        runtime,
        entries,
        request_tags,
        matching_entries,
        0,
    )
end
