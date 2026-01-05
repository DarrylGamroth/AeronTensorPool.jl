const DISCOVERY_GROUP_HEADER_LEN = 4
const DISCOVERY_VAR_ASCII_HEADER_LEN =
    Int(ShmTensorpoolDiscovery.VarAsciiEncoding.length_encoding_length(
        ShmTensorpoolDiscovery.VarAsciiEncoding.Decoder,
    ))

@inline function var_ascii_view(m::ShmTensorpoolDiscovery.VarAsciiEncoding.Decoder)
    len = ShmTensorpoolDiscovery.VarAsciiEncoding.length(m)
    offset = m.offset + ShmTensorpoolDiscovery.VarAsciiEncoding.varData_encoding_offset(m)
    return StringView(view(m.buffer, offset + 1:offset + len))
end

@inline function var_ascii_set!(
    m::ShmTensorpoolDiscovery.VarAsciiEncoding.Encoder,
    value::AbstractString,
)
    len = sizeof(value)
    ShmTensorpoolDiscovery.VarAsciiEncoding.length!(m, len)
    len == 0 && return nothing
    offset = m.offset + ShmTensorpoolDiscovery.VarAsciiEncoding.varData_encoding_offset(m)
    dest = view(m.buffer, offset + 1:offset + len)
    copyto!(dest, codeunits(value))
    return nothing
end

@inline function discovery_data_source_id_null()
    return DiscoveryResponse.Results.dataSourceId_null_value(DiscoveryResponse.Results.Decoder)
end

function ensure_pool_capacity!(pools::Vector{DiscoveryPoolEntry}, count::Int)
    while length(pools) < count
        push!(pools, DiscoveryPoolEntry(UInt16(0), UInt32(0), UInt32(0), FixedString(DRIVER_URI_MAX_BYTES)))
    end
    return nothing
end

@inline function entry_expired(entry::DiscoveryEntry, now_ns::UInt64, expiry_ns::UInt64)
    expiry_ns == 0 && return false
    last_seen = entry.last_announce_ns
    last_seen == 0 && return true
    return now_ns - last_seen > expiry_ns
end

function entry_for_stream!(
    state::AbstractDiscoveryState,
    driver_instance_id::String,
    driver_control_channel::String,
    driver_control_stream_id::UInt32,
    stream_id::UInt32,
)
    key = (driver_instance_id, stream_id)
    entry = get(state.entries, key, nothing)
    if entry === nothing
        entry = DiscoveryEntry(
            FixedString(DISCOVERY_INSTANCE_ID_MAX_BYTES),
            FixedString(DISCOVERY_CONTROL_CHANNEL_MAX_BYTES),
            driver_control_stream_id,
            stream_id,
            UInt32(0),
            UInt64(0),
            UInt32(0),
            FixedString(DRIVER_URI_MAX_BYTES),
            UInt32(0),
            UInt16(0),
            UInt8(0),
            discovery_data_source_id_null(),
            FixedString(DISCOVERY_MAX_DATASOURCE_NAME_BYTES),
            Vector{FixedString}(),
            Vector{DiscoveryPoolEntry}(),
            UInt64(0),
        )
        copyto!(entry.driver_instance_id, driver_instance_id)
        copyto!(entry.driver_control_channel, driver_control_channel)
        state.entries[key] = entry
    end
    return entry
end

function update_entry_from_announce!(
    state::AbstractDiscoveryState,
    msg::ShmPoolAnnounce.Decoder,
    driver_instance_id::String,
    driver_control_channel::String,
    driver_control_stream_id::UInt32,
)
    stream_id = ShmPoolAnnounce.streamId(msg)
    entry = entry_for_stream!(
        state,
        driver_instance_id,
        driver_control_channel,
        driver_control_stream_id,
        stream_id,
    )
    epoch = ShmPoolAnnounce.epoch(msg)
    if entry.epoch != 0 && epoch < entry.epoch
        return false
    end
    entry.stream_id = stream_id
    entry.producer_id = ShmPoolAnnounce.producerId(msg)
    entry.epoch = epoch
    entry.layout_version = ShmPoolAnnounce.layoutVersion(msg)
    entry.header_nslots = ShmPoolAnnounce.headerNslots(msg)
    entry.header_slot_bytes = ShmPoolAnnounce.headerSlotBytes(msg)
    entry.max_dims = ShmPoolAnnounce.maxDims(msg)

    pool_count = 0
    pools = ShmPoolAnnounce.payloadPools(msg)
    for pool in pools
        pool_count += 1
        ensure_pool_capacity!(entry.pools, pool_count)
        dest = entry.pools[pool_count]
        dest.pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        dest.pool_nslots = ShmPoolAnnounce.PayloadPools.poolNslots(pool)
        dest.stride_bytes = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        copyto!(dest.region_uri, ShmPoolAnnounce.PayloadPools.regionUri(pool, StringView))
    end
    resize!(entry.pools, pool_count)

    copyto!(entry.header_region_uri, ShmPoolAnnounce.headerRegionUri(msg, StringView))
    entry.last_announce_ns = UInt64(Clocks.time_nanos(state.clock))
    return true
end

function update_entry_from_metadata_announce!(
    state::AbstractDiscoveryState,
    msg::DataSourceAnnounce.Decoder,
    driver_instance_id::String,
    driver_control_channel::String,
    driver_control_stream_id::UInt32,
)
    stream_id = DataSourceAnnounce.streamId(msg)
    entry = entry_for_stream!(
        state,
        driver_instance_id,
        driver_control_channel,
        driver_control_stream_id,
        stream_id,
    )
    epoch = DataSourceAnnounce.epoch(msg)
    if entry.epoch != 0 && epoch < entry.epoch
        return false
    end
    entry.stream_id = stream_id
    entry.producer_id = DataSourceAnnounce.producerId(msg)
    entry.epoch = epoch
    copyto!(entry.data_source_name, DataSourceAnnounce.name(msg, StringView))
    DataSourceAnnounce.summary(msg, StringView)
    entry.last_announce_ns = UInt64(Clocks.time_nanos(state.clock))
    return true
end

function touch_entry_from_metadata_meta!(
    state::AbstractDiscoveryState,
    msg::DataSourceMeta.Decoder,
    driver_instance_id::String,
    driver_control_channel::String,
    driver_control_stream_id::UInt32,
)
    stream_id = DataSourceMeta.streamId(msg)
    entry = entry_for_stream!(
        state,
        driver_instance_id,
        driver_control_channel,
        driver_control_stream_id,
        stream_id,
    )
    entry.last_announce_ns = UInt64(Clocks.time_nanos(state.clock))
    return true
end

@inline function entry_has_tag(entry::DiscoveryEntry, tag::StringView)
    for entry_tag in entry.tags
        if view(entry_tag) == tag
            return true
        end
    end
    return false
end

function entry_matches!(
    entry::DiscoveryEntry,
    stream_id_filter::Union{UInt32, Nothing},
    producer_id_filter::Union{UInt32, Nothing},
    data_source_id_filter::Union{UInt64, Nothing},
    data_source_name_filter::StringView,
    request_tags::Vector{StringView},
)
    if stream_id_filter !== nothing && entry.stream_id != stream_id_filter
        return false
    end
    if producer_id_filter !== nothing && entry.producer_id != producer_id_filter
        return false
    end
    if data_source_id_filter !== nothing && entry.data_source_id != data_source_id_filter
        return false
    end
    if !isempty(data_source_name_filter) && view(entry.data_source_name) != data_source_name_filter
        return false
    end
    for tag in request_tags
        entry_has_tag(entry, tag) || return false
    end
    return true
end

function collect_request_tags!(state::AbstractDiscoveryState, msg::DiscoveryRequest.Decoder)
    empty!(state.request_tags)
    tags = DiscoveryRequest.tags(msg)
    for tag_entry in tags
        tag_decoder = DiscoveryRequest.Tags.tag(tag_entry)
        tag_view = var_ascii_view(tag_decoder)
        tag_len = ShmTensorpoolDiscovery.VarAsciiEncoding.length(tag_decoder)
        pos = DiscoveryRequest.Tags.sbe_position(tag_entry)
        DiscoveryRequest.Tags.sbe_position!(
            tag_entry,
            pos + DISCOVERY_VAR_ASCII_HEADER_LEN + tag_len,
        )
        isempty(tag_view) && continue
        duplicate = false
        for existing in state.request_tags
            if existing == tag_view
                duplicate = true
                break
            end
        end
        duplicate || push!(state.request_tags, tag_view)
    end
    return nothing
end

@inline function find_response_pub(
    state::AbstractDiscoveryState,
    response_channel::AbstractString,
    response_stream_id::Int32,
)
    for ((channel, stream_id), pub) in state.runtime.pubs
        if stream_id == response_stream_id && channel == response_channel
            return pub
        end
    end
    return nothing
end

function response_pub_for!(
    state::AbstractDiscoveryState,
    response_channel::AbstractString,
    response_stream_id::Int32,
)
    pub = find_response_pub(state, response_channel, response_stream_id)
    pub !== nothing && return pub
    channel = String(response_channel)
    pub = Aeron.add_publication(state.runtime.client, channel, response_stream_id)
    state.runtime.pubs[(channel, response_stream_id)] = pub
    return pub
end

function discovery_response_length(
    entries::Vector{DiscoveryEntry},
    count::Int,
    error_message::AbstractString,
)
    results_block_len = Int(DiscoveryResponse.Results.sbe_block_length(DiscoveryResponse.Results.Decoder))
    total = DISCOVERY_MESSAGE_HEADER_LEN +
        Int(DiscoveryResponse.sbe_block_length(DiscoveryResponse.Decoder)) +
        DISCOVERY_GROUP_HEADER_LEN +
        count * results_block_len

    for idx in 1:count
        entry = entries[idx]
        pools_len = 0
        for pool in entry.pools
            pools_len += 10
            pools_len += DiscoveryResponse.Results.PayloadPools.regionUri_header_length
            pools_len += sizeof(pool.region_uri)
        end
        tags_len = 0
        for tag in entry.tags
            tags_len += DISCOVERY_VAR_ASCII_HEADER_LEN
            tags_len += sizeof(tag)
        end
        total += DISCOVERY_GROUP_HEADER_LEN + pools_len
        total += DISCOVERY_GROUP_HEADER_LEN + tags_len
        total += DiscoveryResponse.Results.headerRegionUri_header_length + sizeof(entry.header_region_uri)
        total += DiscoveryResponse.Results.dataSourceName_header_length + sizeof(entry.data_source_name)
        total += DiscoveryResponse.Results.driverInstanceId_header_length + sizeof(entry.driver_instance_id)
        total += DiscoveryResponse.Results.driverControlChannel_header_length +
            sizeof(entry.driver_control_channel)
    end

    total += DiscoveryResponse.errorMessage_header_length
    isempty(error_message) || (total += sizeof(error_message))
    return total
end

function emit_discovery_response!(
    state::AbstractDiscoveryState,
    response_channel::AbstractString,
    response_stream_id::UInt32,
    request_id::UInt64,
    status::DiscoveryStatus.SbeEnum,
    entries::Vector{DiscoveryEntry},
    entry_count::Int,
    error_message::AbstractString = "",
)
    response_stream_id > typemax(Int32) && return false
    pub = response_pub_for!(state, response_channel, Int32(response_stream_id))
    msg_len = discovery_response_length(entries, entry_count, error_message)
    return let st = state,
        request_id = request_id,
        status = status,
        entry_count = entry_count,
        error_message = error_message
        with_claimed_buffer!(pub, st.runtime.response_claim, msg_len) do buf
            DiscoveryResponse.wrap_and_apply_header!(st.runtime.response_encoder, buf, 0)
            DiscoveryResponse.requestId!(st.runtime.response_encoder, request_id)
            DiscoveryResponse.status!(st.runtime.response_encoder, status)
            results_group = DiscoveryResponse.results!(st.runtime.response_encoder, entry_count)
            for idx in 1:entry_count
                entry = entries[idx]
                result = DiscoveryResponse.Results.next!(results_group)
                DiscoveryResponse.Results.streamId!(result, entry.stream_id)
                DiscoveryResponse.Results.producerId!(result, entry.producer_id)
                DiscoveryResponse.Results.epoch!(result, entry.epoch)
                DiscoveryResponse.Results.layoutVersion!(result, entry.layout_version)
                DiscoveryResponse.Results.headerNslots!(result, entry.header_nslots)
                DiscoveryResponse.Results.headerSlotBytes!(result, entry.header_slot_bytes)
                DiscoveryResponse.Results.maxDims!(result, entry.max_dims)
                DiscoveryResponse.Results.dataSourceId!(result, entry.data_source_id)
                DiscoveryResponse.Results.driverControlStreamId!(result, entry.driver_control_stream_id)

                pools_group = DiscoveryResponse.Results.payloadPools!(result, length(entry.pools))
                for pool in entry.pools
                    pool_entry = DiscoveryResponse.Results.PayloadPools.next!(pools_group)
                    DiscoveryResponse.Results.PayloadPools.poolId!(pool_entry, pool.pool_id)
                    DiscoveryResponse.Results.PayloadPools.poolNslots!(pool_entry, pool.pool_nslots)
                    DiscoveryResponse.Results.PayloadPools.strideBytes!(pool_entry, pool.stride_bytes)
                    DiscoveryResponse.Results.PayloadPools.regionUri!(pool_entry, pool.region_uri)
                end

                tags_group = DiscoveryResponse.Results.tags!(result, length(entry.tags))
                for tag in entry.tags
                    tag_entry = DiscoveryResponse.Results.Tags.next!(tags_group)
                    tag_encoder = DiscoveryResponse.Results.Tags.tag(tag_entry)
                    var_ascii_set!(tag_encoder, view(tag))
                    tag_len = sizeof(tag)
                    pos = DiscoveryResponse.Results.Tags.sbe_position(tag_entry)
                    DiscoveryResponse.Results.Tags.sbe_position!(
                        tag_entry,
                        pos + DISCOVERY_VAR_ASCII_HEADER_LEN + tag_len,
                    )
                end

                DiscoveryResponse.Results.headerRegionUri!(result, entry.header_region_uri)
                DiscoveryResponse.Results.dataSourceName!(result, entry.data_source_name)
                DiscoveryResponse.Results.driverInstanceId!(result, entry.driver_instance_id)
                DiscoveryResponse.Results.driverControlChannel!(result, entry.driver_control_channel)
            end
            DiscoveryResponse.errorMessage!(st.runtime.response_encoder, error_message)
        end
    end
end

function handle_shm_pool_announce!(state::DiscoveryProviderState, msg::ShmPoolAnnounce.Decoder)
    return update_entry_from_announce!(
        state,
        msg,
        state.config.driver_instance_id,
        state.config.driver_control_channel,
        state.config.driver_control_stream_id,
    )
end

function handle_metadata_announce!(state::DiscoveryProviderState, msg::DataSourceAnnounce.Decoder)
    return update_entry_from_metadata_announce!(
        state,
        msg,
        state.config.driver_instance_id,
        state.config.driver_control_channel,
        state.config.driver_control_stream_id,
    )
end

function handle_metadata_meta!(state::DiscoveryProviderState, msg::DataSourceMeta.Decoder)
    return touch_entry_from_metadata_meta!(
        state,
        msg,
        state.config.driver_instance_id,
        state.config.driver_control_channel,
        state.config.driver_control_stream_id,
    )
end

function handle_discovery_request!(state::AbstractDiscoveryState, msg::DiscoveryRequest.Decoder)
    collect_request_tags!(state, msg)
    response_channel = DiscoveryRequest.responseChannel(msg, StringView)
    response_stream_id = DiscoveryRequest.responseStreamId(msg)
    data_source_name = DiscoveryRequest.dataSourceName(msg, StringView)

    isempty(response_channel) && return false
    if response_stream_id == 0
        return emit_discovery_response!(
            state,
            response_channel,
            response_stream_id,
            DiscoveryRequest.requestId(msg),
            DiscoveryStatus.ERROR,
            state.matching_entries,
            0,
            "invalid response_stream_id",
        )
    end

    stream_id = DiscoveryRequest.streamId(msg)
    producer_id = DiscoveryRequest.producerId(msg)
    data_source_id = DiscoveryRequest.dataSourceId(msg)
    stream_id_null = DiscoveryRequest.streamId_null_value(DiscoveryRequest.Decoder)
    producer_id_null = DiscoveryRequest.producerId_null_value(DiscoveryRequest.Decoder)
    data_source_id_null = DiscoveryRequest.dataSourceId_null_value(DiscoveryRequest.Decoder)
    stream_filter = stream_id == stream_id_null ? nothing : stream_id
    producer_filter = producer_id == producer_id_null ? nothing : producer_id
    data_source_filter = data_source_id == data_source_id_null ? nothing : data_source_id

    empty!(state.matching_entries)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    for entry in values(state.entries)
        entry_expired(entry, now_ns, state.config.expiry_ns) && continue
        if entry_matches!(
            entry,
            stream_filter,
            producer_filter,
            data_source_filter,
            data_source_name,
            state.request_tags,
        )
            push!(state.matching_entries, entry)
            if length(state.matching_entries) >= state.config.max_results
                break
            end
        end
    end

    return emit_discovery_response!(
        state,
        response_channel,
        response_stream_id,
        DiscoveryRequest.requestId(msg),
        DiscoveryStatus.OK,
        state.matching_entries,
        length(state.matching_entries),
        "",
    )
end

"""
Create a request-channel fragment assembler for discovery requests.

Arguments:
- `state`: discovery provider state.

Returns:
- `Aeron.FragmentAssembler` for discovery requests.
"""
function make_request_assembler(state::AbstractDiscoveryState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = DiscoveryMessageHeader.Decoder(buffer, 0)
        DiscoveryMessageHeader.schemaId(header) == DISCOVERY_SCHEMA_ID || return nothing
        DiscoveryMessageHeader.version(header) ==
            DiscoveryRequest.sbe_schema_version(DiscoveryRequest.Decoder) || return nothing
        if DiscoveryMessageHeader.templateId(header) == TEMPLATE_DISCOVERY_REQUEST
            DiscoveryRequest.wrap!(st.runtime.request_decoder, buffer, 0; header = header)
            handle_discovery_request!(st, st.runtime.request_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a fragment assembler for ShmPoolAnnounce messages.

Arguments:
- `state`: discovery provider state.

Returns:
- `Aeron.FragmentAssembler` for announce messages.
"""
function make_announce_assembler(state::DiscoveryProviderState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.runtime.announce_decoder, buffer, 0; header = header)
            handle_shm_pool_announce!(st, st.runtime.announce_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a fragment assembler for metadata announcements.

Arguments:
- `state`: discovery provider state.

Returns:
- `Aeron.FragmentAssembler` for metadata announce/meta messages.
"""
function make_metadata_assembler(state::DiscoveryProviderState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_DATA_SOURCE_ANNOUNCE
            DataSourceAnnounce.wrap!(st.runtime.metadata_announce_decoder, buffer, 0; header = header)
            handle_metadata_announce!(st, st.runtime.metadata_announce_decoder)
        elseif MessageHeader.templateId(header) == TEMPLATE_DATA_SOURCE_META
            DataSourceMeta.wrap!(st.runtime.metadata_meta_decoder, buffer, 0; header = header)
            handle_metadata_meta!(st, st.runtime.metadata_meta_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll discovery request subscription.

Arguments:
- `state`: discovery provider state.
- `assembler`: request fragment assembler.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
@inline function poll_requests!(
    state::AbstractDiscoveryState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_requests, assembler, fragment_limit)
end

"""
Poll ShmPoolAnnounce subscription.

Arguments:
- `state`: discovery provider state.
- `assembler`: announce fragment assembler.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
@inline function poll_announce!(
    state::AbstractDiscoveryState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_announce, assembler, fragment_limit)
end

"""
Poll metadata subscription.

Arguments:
- `state`: discovery provider state.
- `assembler`: metadata fragment assembler.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
@inline function poll_metadata!(
    state::AbstractDiscoveryState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    sub = state.runtime.sub_metadata
    sub === nothing && return 0
    return Aeron.poll(sub, assembler, fragment_limit)
end
