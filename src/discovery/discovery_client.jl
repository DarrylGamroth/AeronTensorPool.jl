"""
Discovery response slot tracked by the client poller.
"""
mutable struct DiscoveryResponseSlot
    request_id::UInt64
    out_entries::Vector{DiscoveryEntry}
    status::DiscoveryStatus.SbeEnum
    count::Int
    error_message::FixedString
    ready::Bool
end

const EMPTY_STRING_VECTOR = String[]

@inline function DiscoveryResponseSlot(out_entries::Vector{DiscoveryEntry})
    return DiscoveryResponseSlot(
        UInt64(0),
        out_entries,
        DiscoveryStatus.OK,
        0,
        FixedString(DRIVER_ERROR_MAX_BYTES),
        false,
    )
end

"""
Poller for discovery responses (Aeron-style).
"""
mutable struct DiscoveryResponsePoller
    subscription::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    response_decoder::DiscoveryResponse.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    slots::Dict{UInt64, DiscoveryResponseSlot}
end

function DiscoveryResponsePoller(sub::Aeron.Subscription)
    poller = DiscoveryResponsePoller(
        sub,
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, _, _
            nothing
        end),
        DiscoveryResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Dict{UInt64, DiscoveryResponseSlot}(),
    )
    sizehint!(poller.slots, 4)
    poller.assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(poller) do plr, buffer, _
        handle_discovery_response!(plr, buffer)
        nothing
    end)
    return poller
end

"""
Discovery client state for request/response messaging.
"""
mutable struct DiscoveryClientState
    pub::Aeron.Publication
    sub::Aeron.Subscription
    request_encoder::DiscoveryRequest.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    request_claim::Aeron.BufferClaim
    poller::DiscoveryResponsePoller
    client_id::UInt32
    response_channel::String
    response_stream_id::UInt32
    next_request_id::UInt64
end

"""
Initialize a discovery client for request/response messaging.

Arguments:
- `client`: Aeron client to use for publications/subscriptions.
- `request_channel`: Aeron channel for discovery requests.
- `request_stream_id`: Aeron stream id for discovery requests.
- `response_channel`: Aeron channel for discovery responses.
- `response_stream_id`: Aeron stream id for discovery responses.
- `client_id`: unique client identifier.

Returns:
- `DiscoveryClientState` initialized for polling.
"""
function init_discovery_client(
    client::Aeron.Client,
    request_channel::AbstractString,
    request_stream_id::Int32,
    response_channel::AbstractString,
    response_stream_id::UInt32,
    client_id::UInt32,
)
    pub = Aeron.add_publication(client, request_channel, request_stream_id)
    sub = Aeron.add_subscription(client, response_channel, Int32(response_stream_id))
    poller = DiscoveryResponsePoller(sub)
    return DiscoveryClientState(
        pub,
        sub,
        DiscoveryRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        poller,
        client_id,
        String(response_channel),
        response_stream_id,
        (UInt64(client_id) << 32) + 1,
    )
end

"""
Return the next request id for discovery requests.

Arguments:
- `state`: discovery client state.

Returns:
- Request id (UInt64).
"""
@inline function next_request_id!(state::DiscoveryClientState)
    req_id = state.next_request_id
    state.next_request_id += 1
    return req_id
end

@inline function DiscoveryEntry()
    tags = Vector{FixedString}()
    sizehint!(tags, Int(DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT))
    pools = Vector{DiscoveryPoolEntry}()
    sizehint!(pools, Int(DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT))
    return DiscoveryEntry(
        FixedString(DISCOVERY_INSTANCE_ID_MAX_BYTES),
        FixedString(DISCOVERY_CONTROL_CHANNEL_MAX_BYTES),
        UInt32(0),
        UInt32(0),
        UInt32(0),
        UInt64(0),
        UInt32(0),
        FixedString(DRIVER_URI_MAX_BYTES),
        UInt32(0),
        UInt16(0),
        UInt8(0),
        DiscoveryResponse.Results.dataSourceId_null_value(DiscoveryResponse.Results.Decoder),
        FixedString(DISCOVERY_MAX_DATASOURCE_NAME_BYTES),
        tags,
        pools,
        PolledTimer(UInt64(0)),
        UInt64(0),
    )
end

function ensure_entry_capacity!(entries::Vector{DiscoveryEntry}, count::Int)
    while length(entries) < count
        push!(entries, DiscoveryEntry())
    end
    return nothing
end

function ensure_tag_capacity!(tags::Vector{FixedString}, count::Int)
    while length(tags) < count
        push!(tags, FixedString(DISCOVERY_TAG_MAX_BYTES))
    end
    return nothing
end

@inline function discovery_request_length(
    tags::AbstractVector{<:AbstractString},
    response_channel::AbstractString,
    data_source_name::AbstractString,
)
    tags_len = 0
    for tag in tags
        tags_len += DISCOVERY_VAR_ASCII_HEADER_LEN + sizeof(tag)
    end
    return DISCOVERY_MESSAGE_HEADER_LEN +
        Int(DiscoveryRequest.sbe_block_length(DiscoveryRequest.Decoder)) +
        DISCOVERY_GROUP_HEADER_LEN +
        tags_len +
        DiscoveryRequest.responseChannel_header_length +
        sizeof(response_channel) +
        DiscoveryRequest.dataSourceName_header_length +
        sizeof(data_source_name)
end

"""
Send a discovery request and return the request id.

Arguments (keywords):
- `stream_id`: optional stream id filter.
- `producer_id`: optional producer id filter.
- `data_source_id`: optional data source id filter.
- `data_source_name`: optional data source name filter.
- `tags`: optional tag filter list (AND semantics).

Returns:
- Request id on success, or 0 on failure.
"""
function send_discovery_request!(
    state::DiscoveryClientState;
    stream_id::Union{UInt32, Nothing} = nothing,
    producer_id::Union{UInt32, Nothing} = nothing,
    data_source_id::Union{UInt64, Nothing} = nothing,
    data_source_name::AbstractString = "",
    tags::AbstractVector{<:AbstractString} = EMPTY_STRING_VECTOR,
)
    isempty(state.response_channel) && return UInt64(0)
    state.response_stream_id == 0 && return UInt64(0)
    request_id = next_request_id!(state)
    msg_len = discovery_request_length(tags, state.response_channel, data_source_name)
    sent = let st = state,
        request_id = request_id,
        stream_id = stream_id,
        producer_id = producer_id,
        data_source_id = data_source_id,
        data_source_name = data_source_name,
        tags = tags
        with_claimed_buffer!(st.pub, st.request_claim, msg_len) do buf
            DiscoveryRequest.wrap_and_apply_header!(st.request_encoder, buf, 0)
            DiscoveryRequest.requestId!(st.request_encoder, request_id)
            DiscoveryRequest.clientId!(st.request_encoder, st.client_id)
            DiscoveryRequest.responseStreamId!(st.request_encoder, st.response_stream_id)
            if stream_id === nothing
                DiscoveryRequest.streamId!(
                    st.request_encoder,
                    DiscoveryRequest.streamId_null_value(DiscoveryRequest.Decoder),
                )
            else
                DiscoveryRequest.streamId!(st.request_encoder, stream_id)
            end
            if producer_id === nothing
                DiscoveryRequest.producerId!(
                    st.request_encoder,
                    DiscoveryRequest.producerId_null_value(DiscoveryRequest.Decoder),
                )
            else
                DiscoveryRequest.producerId!(st.request_encoder, producer_id)
            end
            if data_source_id === nothing
                DiscoveryRequest.dataSourceId!(
                    st.request_encoder,
                    DiscoveryRequest.dataSourceId_null_value(DiscoveryRequest.Decoder),
                )
            else
                DiscoveryRequest.dataSourceId!(st.request_encoder, data_source_id)
            end

            tags_group = DiscoveryRequest.tags!(st.request_encoder, length(tags))
            for tag in tags
                tag_entry = DiscoveryRequest.Tags.next!(tags_group)
                tag_encoder = DiscoveryRequest.Tags.tag(tag_entry)
                var_ascii_set!(tag_encoder, tag)
                tag_len = sizeof(tag)
                pos = DiscoveryRequest.Tags.sbe_position(tag_entry)
                DiscoveryRequest.Tags.sbe_position!(
                    tag_entry,
                    pos + DISCOVERY_VAR_ASCII_HEADER_LEN + tag_len,
                )
            end

            DiscoveryRequest.responseChannel!(st.request_encoder, st.response_channel)
            DiscoveryRequest.dataSourceName!(st.request_encoder, data_source_name)
        end
    end
    sent || return UInt64(0)
    return request_id
end

"""
Register an output container for a discovery request id.

Arguments:
- `poller`: discovery response poller.
- `request_id`: request id to track.
- `out_entries`: output container for results.

Returns:
- `nothing`.
"""
function register_discovery_request!(
    poller::DiscoveryResponsePoller,
    request_id::UInt64,
    out_entries::Vector{DiscoveryEntry},
)
    slot = get(poller.slots, request_id, nothing)
    if slot === nothing
        slot = DiscoveryResponseSlot(out_entries)
        poller.slots[request_id] = slot
    end
    slot.request_id = request_id
    slot.out_entries = out_entries
    slot.status = DiscoveryStatus.OK
    slot.count = 0
    slot.ready = false
    empty!(slot.error_message)
    return nothing
end

@inline function snapshot_discovery_response!(
    out_entries::Vector{DiscoveryEntry},
    msg::DiscoveryResponse.Decoder,
)
    results = DiscoveryResponse.results(msg)
    result_count = length(results)
    ensure_entry_capacity!(out_entries, result_count)
    resize!(out_entries, result_count)
    idx = 0
    for result in results
        idx += 1
        entry = out_entries[idx]
        entry.stream_id = DiscoveryResponse.Results.streamId(result)
        entry.producer_id = DiscoveryResponse.Results.producerId(result)
        entry.epoch = DiscoveryResponse.Results.epoch(result)
        entry.layout_version = DiscoveryResponse.Results.layoutVersion(result)
        entry.header_nslots = DiscoveryResponse.Results.headerNslots(result)
        entry.header_slot_bytes = DiscoveryResponse.Results.headerSlotBytes(result)
        entry.max_dims = DiscoveryResponse.Results.maxDims(result)
        entry.data_source_id = DiscoveryResponse.Results.dataSourceId(result)
        entry.driver_control_stream_id = DiscoveryResponse.Results.driverControlStreamId(result)

        pools = DiscoveryResponse.Results.payloadPools(result)
        pool_count = 0
        for pool in pools
            pool_count += 1
            ensure_pool_capacity!(entry.pools, pool_count)
            dest = entry.pools[pool_count]
            dest.pool_id = DiscoveryResponse.Results.PayloadPools.poolId(pool)
            dest.pool_nslots = DiscoveryResponse.Results.PayloadPools.poolNslots(pool)
            dest.stride_bytes = DiscoveryResponse.Results.PayloadPools.strideBytes(pool)
            copyto!(dest.region_uri, DiscoveryResponse.Results.PayloadPools.regionUri(pool, StringView))
        end
        resize!(entry.pools, pool_count)

        tags = DiscoveryResponse.Results.tags(result)
        tag_count = 0
        for tag_entry in tags
            tag_decoder = DiscoveryResponse.Results.Tags.tag(tag_entry)
            tag_view = var_ascii_view(tag_decoder)
            tag_len = ShmTensorpoolDiscovery.VarAsciiEncoding.length(tag_decoder)
            pos = DiscoveryResponse.Results.Tags.sbe_position(tag_entry)
            DiscoveryResponse.Results.Tags.sbe_position!(
                tag_entry,
                pos + DISCOVERY_VAR_ASCII_HEADER_LEN + tag_len,
            )
            tag_count += 1
            ensure_tag_capacity!(entry.tags, tag_count)
            copyto!(entry.tags[tag_count], tag_view)
        end
        resize!(entry.tags, tag_count)

        copyto!(entry.header_region_uri, DiscoveryResponse.Results.headerRegionUri(result, StringView))
        copyto!(entry.data_source_name, DiscoveryResponse.Results.dataSourceName(result, StringView))
        copyto!(entry.driver_instance_id, DiscoveryResponse.Results.driverInstanceId(result, StringView))
        copyto!(
            entry.driver_control_channel,
            DiscoveryResponse.Results.driverControlChannel(result, StringView),
        )
    end
    return result_count
end

function handle_discovery_response!(
    poller::DiscoveryResponsePoller,
    buffer::AbstractVector{UInt8},
)
    header = DiscoveryMessageHeader.Decoder(buffer, 0)
    DiscoveryMessageHeader.schemaId(header) == DISCOVERY_SCHEMA_ID || return nothing
    DiscoveryMessageHeader.version(header) ==
        DiscoveryResponse.sbe_schema_version(DiscoveryResponse.Decoder) || return nothing
    if DiscoveryMessageHeader.templateId(header) != TEMPLATE_DISCOVERY_RESPONSE
        return nothing
    end

    DiscoveryResponse.wrap!(poller.response_decoder, buffer, 0; header = header)
    msg = poller.response_decoder
    request_id = DiscoveryResponse.requestId(msg)
    slot = get(poller.slots, request_id, nothing)
    slot === nothing && return nothing

    slot.status = DiscoveryResponse.status(msg)
    if slot.status == DiscoveryStatus.OK
        slot.count = snapshot_discovery_response!(slot.out_entries, msg)
    else
        slot.count = 0
        resize!(slot.out_entries, 0)
        DiscoveryResponse.results(msg)
    end
    copyto!(slot.error_message, DiscoveryResponse.errorMessage(msg, StringView))
    slot.ready = true
    return nothing
end

"""
Poll discovery responses and update matching slots.

Arguments:
- `poller`: discovery response poller.
- `fragment_limit`: max fragments to poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_discovery_responses!(
    poller::DiscoveryResponsePoller,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(poller.subscription, poller.assembler, fragment_limit)
end

"""
Send a discovery request and register an output container.

Arguments:
- `state`: discovery client state.
- `out_entries`: output container for results.
- `stream_id`: optional stream id filter (keyword).
- `producer_id`: optional producer id filter (keyword).
- `data_source_id`: optional data source id filter (keyword).
- `data_source_name`: optional data source name filter (keyword).
- `tags`: optional tag filter list (keyword).

Returns:
- Request id on success, or 0 on failure.
"""
function discover_streams!(
    state::DiscoveryClientState,
    out_entries::Vector{DiscoveryEntry};
    stream_id::Union{UInt32, Nothing} = nothing,
    producer_id::Union{UInt32, Nothing} = nothing,
    data_source_id::Union{UInt64, Nothing} = nothing,
    data_source_name::AbstractString = "",
    tags::AbstractVector{<:AbstractString} = EMPTY_STRING_VECTOR,
)
    request_id = send_discovery_request!(
        state;
        stream_id = stream_id,
        producer_id = producer_id,
        data_source_id = data_source_id,
        data_source_name = data_source_name,
        tags = tags,
    )
    request_id == 0 && return UInt64(0)
    register_discovery_request!(state.poller, request_id, out_entries)
    return request_id
end

"""
Poll for a completed discovery response.

Arguments:
- `state`: discovery client state.
- `request_id`: request id to check.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- `DiscoveryResponseSlot` if ready, otherwise `nothing`.
"""
function poll_discovery_response!(
    state::DiscoveryClientState,
    request_id::UInt64;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    poll_discovery_responses!(state.poller, fragment_limit)
    slot = get(state.poller.slots, request_id, nothing)
    slot === nothing && return nothing
    slot.ready || return nothing
    delete!(state.poller.slots, request_id)
    return slot
end
