"""
Set producer metadata to be published.

Arguments:
- `state`: producer state.
- `meta_version`: metadata correlation/version.
- `name`: human-friendly name.
- `summary`: optional summary.
- `attributes`: metadata attributes.
"""
function set_metadata!(
    state::ProducerState,
    meta_version::UInt32,
    name::AbstractString;
    summary::AbstractString = "",
    attributes::AbstractVector{MetadataAttribute} = MetadataAttribute[],
)
    announce_data_source!(state, meta_version, name; summary = summary)
    set_metadata_attributes!(state, meta_version; attributes = attributes)
    return nothing
end

"""
Announce a data source name/summary without overwriting metadata attributes.

Arguments:
- `state`: producer state.
- `meta_version`: metadata correlation/version.
- `name`: data source name (used by discovery).
- `summary`: optional summary.
"""
function announce_data_source!(
    state::ProducerState,
    meta_version::UInt32,
    name::AbstractString;
    summary::AbstractString = "",
)
    state.metadata_version = meta_version
    state.metadata_name = String(name)
    state.metadata_summary = String(summary)
    return emit_metadata_announce!(
        state,
        state.metadata_version,
        state.metadata_name,
        state.metadata_summary,
    )
end

"""
Set metadata attributes without changing the announced data source name.

Arguments:
- `state`: producer state.
- `meta_version`: metadata correlation/version.
- `attributes`: metadata attributes.
"""
function set_metadata_attributes!(
    state::ProducerState,
    meta_version::UInt32;
    attributes::AbstractVector{MetadataAttribute} = MetadataAttribute[],
)
    state.metadata_version = meta_version
    state.metadata_attrs = MetadataAttribute[attributes...]
    state.metadata_dirty = true
    return nothing
end

"""
Upsert a metadata attribute (by key) without changing the data source name.

Arguments:
- `state`: producer state.
- `meta_version`: metadata correlation/version.
- `key`: metadata key.
- `format`: value format (e.g. MIME type).
- `value`: metadata value.
"""
function set_metadata_attribute!(
    state::ProducerState,
    meta_version::UInt32,
    key::AbstractString,
    format::AbstractString,
    value::AbstractVector{UInt8},
)
    state.metadata_version = meta_version
    attr = MetadataAttribute(key, format, value)
    idx = findfirst(existing -> existing.key == key, state.metadata_attrs)
    if idx === nothing
        push!(state.metadata_attrs, attr)
    else
        state.metadata_attrs[idx] = attr
    end
    state.metadata_dirty = true
    return nothing
end

function set_metadata_attribute!(
    state::ProducerState,
    meta_version::UInt32,
    key::AbstractString,
    format::AbstractString,
    value::AbstractString,
)
    return set_metadata_attribute!(
        state,
        meta_version,
        key,
        format,
        Vector{UInt8}(codeunits(value)),
    )
end

function set_metadata_attribute!(
    state::ProducerState,
    meta_version::UInt32,
    key::AbstractString,
    format::AbstractString,
    value::Integer,
)
    return set_metadata_attribute!(
        state,
        meta_version,
        key,
        format,
        Vector{UInt8}(codeunits(string(value))),
    )
end

"""
Delete a metadata attribute (by key) without changing the data source name.

Arguments:
- `state`: producer state.
- `meta_version`: metadata correlation/version.
- `key`: metadata key.
"""
function delete_metadata_attribute!(
    state::ProducerState,
    meta_version::UInt32,
    key::AbstractString,
)
    state.metadata_version = meta_version
    removed = false
    for idx in reverse(eachindex(state.metadata_attrs))
        if state.metadata_attrs[idx].key == key
            deleteat!(state.metadata_attrs, idx)
            removed = true
        end
    end
    removed && (state.metadata_dirty = true)
    return nothing
end

"""
Emit DataSourceAnnounce using the producer runtime.
"""
function emit_metadata_announce!(
    state::ProducerState,
    meta_version::UInt32,
    name::AbstractString,
    summary::AbstractString,
)
    msg_len = MESSAGE_HEADER_LEN +
        Int(DataSourceAnnounce.sbe_block_length(DataSourceAnnounce.Decoder)) +
        4 + ncodeunits(name) +
        4 + ncodeunits(summary)

    return with_claimed_buffer!(state.runtime.pub_metadata, state.runtime.metadata_claim, msg_len) do buf
        DataSourceAnnounce.wrap_and_apply_header!(state.runtime.metadata_announce_encoder, buf, 0)
        DataSourceAnnounce.streamId!(state.runtime.metadata_announce_encoder, state.config.stream_id)
        DataSourceAnnounce.producerId!(state.runtime.metadata_announce_encoder, state.config.producer_id)
        DataSourceAnnounce.epoch!(state.runtime.metadata_announce_encoder, state.epoch)
        DataSourceAnnounce.metaVersion!(state.runtime.metadata_announce_encoder, meta_version)
        DataSourceAnnounce.name!(state.runtime.metadata_announce_encoder, name)
        DataSourceAnnounce.summary!(state.runtime.metadata_announce_encoder, summary)
    end
end

"""
Emit DataSourceMeta using the producer runtime.
"""
function emit_metadata_meta!(
    state::ProducerState,
    meta_version::UInt32,
    timestamp_ns::UInt64,
    attributes::AbstractVector{MetadataAttribute},
)
    payload_len = 0
    for attr in attributes
        payload_len += 4 + ncodeunits(attr.key)
        payload_len += 4 + ncodeunits(attr.format)
        payload_len += 4 + length(attr.value)
    end
    msg_len = MESSAGE_HEADER_LEN +
        Int(DataSourceMeta.sbe_block_length(DataSourceMeta.Decoder)) +
        4 + payload_len

    return with_claimed_buffer!(state.runtime.pub_metadata, state.runtime.metadata_claim, msg_len) do buf
        DataSourceMeta.wrap_and_apply_header!(state.runtime.metadata_meta_encoder, buf, 0)
        DataSourceMeta.streamId!(state.runtime.metadata_meta_encoder, state.config.stream_id)
        DataSourceMeta.metaVersion!(state.runtime.metadata_meta_encoder, meta_version)
        DataSourceMeta.timestampNs!(state.runtime.metadata_meta_encoder, timestamp_ns)
        attrs = DataSourceMeta.attributes!(state.runtime.metadata_meta_encoder, length(attributes))
        for attr in attributes
            entry = DataSourceMeta.Attributes.next!(attrs)
            DataSourceMeta.Attributes.key!(entry, attr.key)
            DataSourceMeta.Attributes.format!(entry, attr.format)
            DataSourceMeta.Attributes.value!(entry, attr.value)
        end
    end
end

"""
Emit metadata if marked dirty.
"""
function emit_metadata_if_dirty!(state::ProducerState, now_ns::UInt64)
    state.metadata_dirty || return 0
    sent_announce = emit_metadata_announce!(
        state,
        state.metadata_version,
        state.metadata_name,
        state.metadata_summary,
    )
    sent_announce || return 0
    sent_meta = emit_metadata_meta!(state, state.metadata_version, now_ns, state.metadata_attrs)
    sent_meta || return 0
    state.metadata_dirty = false
    return 2
end
