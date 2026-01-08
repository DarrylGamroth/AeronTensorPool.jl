
"""
Metadata publisher for DataSourceAnnounce/DataSourceMeta.
"""
mutable struct MetadataPublisher
    pub::Aeron.Publication
    claim::Aeron.BufferClaim
    announce_encoder::DataSourceAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    meta_encoder::DataSourceMeta.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    stream_id::UInt32
    producer_id::UInt32
    epoch::UInt64
end

"""
Create a MetadataPublisher with explicit publication settings.
"""
function MetadataPublisher(
    pub::Aeron.Publication,
    stream_id::UInt32,
    producer_id::UInt32,
    epoch::UInt64,
)
    return MetadataPublisher(
        pub,
        Aeron.BufferClaim(),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        stream_id,
        producer_id,
        epoch,
    )
end

"""
Create a MetadataPublisher from a ProducerHandle.
"""
function MetadataPublisher(handle::ProducerHandle)
    return MetadataPublisher(handle_state(handle))
end

"""
Create a MetadataPublisher from a ProducerState.
"""
function MetadataPublisher(state::ProducerState)
    return MetadataPublisher(
        state.runtime.pub_metadata,
        Aeron.BufferClaim(),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        state.config.stream_id,
        state.config.producer_id,
        state.epoch,
    )
end

"""
Emit a DataSourceAnnounce message.

Arguments:
- `publisher`: metadata publisher.
- `meta_version`: metadata correlation/version for this stream.
- `name`: human-friendly data source name.
- `summary`: short summary (optional).

Returns:
- `true` if committed, `false` otherwise.
"""
function emit_metadata_announce!(
    publisher::MetadataPublisher,
    meta_version::UInt32,
    name::AbstractString;
    summary::AbstractString = "",
)
    msg_len = MESSAGE_HEADER_LEN +
        Int(DataSourceAnnounce.sbe_block_length(DataSourceAnnounce.Decoder)) +
        4 + ncodeunits(name) +
        4 + ncodeunits(summary)

    sent = let pub = publisher
        with_claimed_buffer!(pub.pub, pub.claim, msg_len) do buf
            DataSourceAnnounce.wrap_and_apply_header!(pub.announce_encoder, buf, 0)
            DataSourceAnnounce.streamId!(pub.announce_encoder, pub.stream_id)
            DataSourceAnnounce.producerId!(pub.announce_encoder, pub.producer_id)
            DataSourceAnnounce.epoch!(pub.announce_encoder, pub.epoch)
            DataSourceAnnounce.metaVersion!(pub.announce_encoder, meta_version)
            DataSourceAnnounce.name!(pub.announce_encoder, name)
            DataSourceAnnounce.summary!(pub.announce_encoder, summary)
        end
    end
    return sent
end

"""
Emit a DataSourceMeta message.

Arguments:
- `publisher`: metadata publisher.
- `meta_version`: metadata correlation/version for this stream.
- `timestamp_ns`: timestamp for this metadata snapshot.
- `attributes`: metadata attributes.

Returns:
- `true` if committed, `false` otherwise.
"""
function emit_metadata_meta!(
    publisher::MetadataPublisher,
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

    sent = let pub = publisher,
        attributes = attributes,
        meta_version = meta_version,
        timestamp_ns = timestamp_ns
        with_claimed_buffer!(pub.pub, pub.claim, msg_len) do buf
            DataSourceMeta.wrap_and_apply_header!(pub.meta_encoder, buf, 0)
            DataSourceMeta.streamId!(pub.meta_encoder, pub.stream_id)
            DataSourceMeta.metaVersion!(pub.meta_encoder, meta_version)
            DataSourceMeta.timestampNs!(pub.meta_encoder, timestamp_ns)
            attrs = DataSourceMeta.attributes!(pub.meta_encoder, length(attributes))
            for attr in attributes
                entry = DataSourceMeta.Attributes.next!(attrs)
                DataSourceMeta.Attributes.key!(entry, attr.key)
                DataSourceMeta.Attributes.format!(entry, attr.format)
                DataSourceMeta.Attributes.value!(entry, attr.value)
            end
        end
    end
    return sent
end

"""
Metadata cache that tracks DataSourceAnnounce/DataSourceMeta.
"""
mutable struct MetadataCache
    sub::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    announce_decoder::DataSourceAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    meta_decoder::DataSourceMeta.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    entries::Dict{UInt32, MetadataEntry}
end

"""
Create a MetadataCache for a metadata channel/stream.
"""
function MetadataCache(client::Aeron.Client, channel::AbstractString, stream_id::Int32)
    sub = Aeron.add_subscription(client, channel, stream_id)
    cache = MetadataCache(
        sub,
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing)),
        DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Dict{UInt32, MetadataEntry}(),
    )
    cache.assembler = make_metadata_cache_assembler(cache)
    return cache
end

MetadataCache(aeron_uri::AbstractString, metadata_stream_id::Int32; client::Aeron.Client) =
    MetadataCache(client, aeron_uri, metadata_stream_id)

MetadataCache(config::ProducerConfig; client::Aeron.Client) =
    MetadataCache(client, config.aeron_uri, config.metadata_stream_id)

"""
Close a MetadataCache and its Aeron subscription.
"""
function Base.close(cache::MetadataCache)
    close(cache.sub)
    return nothing
end

"""
Poll metadata updates and refresh cache entries.
"""
function poll_metadata!(cache::MetadataCache, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(cache.sub, cache.assembler, fragment_limit)
end

"""
Get the cached metadata entry for a stream.
"""
metadata_entry(cache::MetadataCache, stream_id::UInt32) = get(cache.entries, stream_id, nothing)

function make_metadata_cache_assembler(cache::MetadataCache)
    handler = Aeron.FragmentHandler(cache) do st, buffer, header
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_DATA_SOURCE_ANNOUNCE
            DataSourceAnnounce.wrap!(st.announce_decoder, buffer, 0; header = header)
            update_metadata_announce!(st, st.announce_decoder)
        elseif template_id == TEMPLATE_DATA_SOURCE_META
            DataSourceMeta.wrap!(st.meta_decoder, buffer, 0; header = header)
            update_metadata_meta!(st, st.meta_decoder)
        end
        return nothing
    end
    return Aeron.FragmentAssembler(handler)
end

function update_metadata_announce!(cache::MetadataCache, msg::DataSourceAnnounce.Decoder)
    stream_id = DataSourceAnnounce.streamId(msg)
    entry = get!(cache.entries, stream_id) do
        MetadataEntry(stream_id)
    end
    entry.producer_id = DataSourceAnnounce.producerId(msg)
    entry.epoch = DataSourceAnnounce.epoch(msg)
    entry.meta_version = DataSourceAnnounce.metaVersion(msg)
    entry.name = String(DataSourceAnnounce.name(msg, StringView))
    entry.summary = String(DataSourceAnnounce.summary(msg, StringView))
    return entry
end

function update_metadata_meta!(cache::MetadataCache, msg::DataSourceMeta.Decoder)
    stream_id = DataSourceMeta.streamId(msg)
    entry = get!(cache.entries, stream_id) do
        MetadataEntry(stream_id)
    end
    meta_version = DataSourceMeta.metaVersion(msg)
    if meta_version < entry.meta_version
        return entry
    end
    attrs = DataSourceMeta.attributes(msg)
    count = length(attrs)
    attributes = Vector{MetadataAttribute}(undef, count)
    idx = 1
    for attr in attrs
        key = String(DataSourceMeta.Attributes.key(attr, StringView))
        format = String(DataSourceMeta.Attributes.format(attr, StringView))
        value = DataSourceMeta.Attributes.value(attr)
        attributes[idx] = MetadataAttribute(key, format, Vector{UInt8}(value))
        idx += 1
    end
    entry.meta_version = meta_version
    entry.timestamp_ns = DataSourceMeta.timestampNs(msg)
    entry.attributes = attributes
    return entry
end
