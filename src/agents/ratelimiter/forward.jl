"""
Lookup a mapping by source stream id.
"""
@inline function mapping_for_source(state::RateLimiterState, stream_id::UInt32)
    return get(state.mapping_by_source, stream_id, nothing)
end

function forward_data_source_announce!(
    state::RateLimiterState,
    mapping::RateLimiterMappingState,
    msg::DataSourceAnnounce.Decoder,
)
    pub = mapping.metadata_pub
    pub === nothing && return false

    name = DataSourceAnnounce.name(msg, StringView)
    summary = DataSourceAnnounce.summary(msg, StringView)
    msg_len = MESSAGE_HEADER_LEN +
        Int(DataSourceAnnounce.sbe_block_length(DataSourceAnnounce.Decoder)) +
        4 + ncodeunits(name) +
        4 + ncodeunits(summary)

    return with_claimed_buffer!(pub, mapping.metadata_claim, msg_len) do buf
        DataSourceAnnounce.wrap_and_apply_header!(state.metadata_announce_encoder, buf, 0)
        DataSourceAnnounce.streamId!(state.metadata_announce_encoder, mapping.mapping.dest_stream_id)
        DataSourceAnnounce.producerId!(state.metadata_announce_encoder, DataSourceAnnounce.producerId(msg))
        DataSourceAnnounce.epoch!(state.metadata_announce_encoder, DataSourceAnnounce.epoch(msg))
        DataSourceAnnounce.metaVersion!(state.metadata_announce_encoder, DataSourceAnnounce.metaVersion(msg))
        DataSourceAnnounce.name!(state.metadata_announce_encoder, name)
        DataSourceAnnounce.summary!(state.metadata_announce_encoder, summary)
    end
end

function forward_data_source_meta!(
    state::RateLimiterState,
    mapping::RateLimiterMappingState,
    msg::DataSourceMeta.Decoder,
)
    pub = mapping.metadata_pub
    pub === nothing && return false

    payload_len = 0
    attr_count = 0
    attrs = DataSourceMeta.attributes(msg)
    for attr in attrs
        key = DataSourceMeta.Attributes.key(attr, StringView)
        format = DataSourceMeta.Attributes.format(attr, StringView)
        value = DataSourceMeta.Attributes.value(attr)
        payload_len += 4 + ncodeunits(key)
        payload_len += 4 + ncodeunits(format)
        payload_len += 4 + length(value)
        attr_count += 1
    end
    DataSourceMeta.sbe_rewind!(msg)
    msg_len = MESSAGE_HEADER_LEN +
        Int(DataSourceMeta.sbe_block_length(DataSourceMeta.Decoder)) +
        4 + payload_len

    return with_claimed_buffer!(pub, mapping.metadata_claim, msg_len) do buf
        DataSourceMeta.wrap_and_apply_header!(state.metadata_meta_encoder, buf, 0)
        DataSourceMeta.streamId!(state.metadata_meta_encoder, mapping.mapping.dest_stream_id)
        DataSourceMeta.metaVersion!(state.metadata_meta_encoder, DataSourceMeta.metaVersion(msg))
        DataSourceMeta.timestampNs!(state.metadata_meta_encoder, DataSourceMeta.timestampNs(msg))
        attrs_encoder = DataSourceMeta.attributes!(state.metadata_meta_encoder, attr_count)
        attrs = DataSourceMeta.attributes(msg)
        for attr in attrs
            entry = DataSourceMeta.Attributes.next!(attrs_encoder)
            DataSourceMeta.Attributes.key!(entry, DataSourceMeta.Attributes.key(attr, StringView))
            DataSourceMeta.Attributes.format!(entry, DataSourceMeta.Attributes.format(attr, StringView))
            DataSourceMeta.Attributes.value!(entry, DataSourceMeta.Attributes.value(attr))
        end
    end
end

function forward_progress!(
    state::RateLimiterState,
    mapping::RateLimiterMappingState,
    msg::FrameProgress.Decoder,
)
    pub = state.control_pub
    pub === nothing && return false

    msg_len = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_block_length(FrameProgress.Decoder))
    return with_claimed_buffer!(pub, state.control_claim, msg_len) do buf
        FrameProgress.wrap_and_apply_header!(state.progress_encoder, buf, 0)
        FrameProgress.streamId!(state.progress_encoder, mapping.mapping.dest_stream_id)
        FrameProgress.epoch!(state.progress_encoder, FrameProgress.epoch(msg))
        FrameProgress.frameId!(state.progress_encoder, FrameProgress.frameId(msg))
        FrameProgress.headerIndex!(state.progress_encoder, FrameProgress.headerIndex(msg))
        FrameProgress.payloadBytesFilled!(state.progress_encoder, FrameProgress.payloadBytesFilled(msg))
        FrameProgress.state!(state.progress_encoder, FrameProgress.state(msg))
        FrameProgress.rowsFilled!(state.progress_encoder, FrameProgress.rowsFilled(msg))
    end
end

function forward_qos_producer!(
    state::RateLimiterState,
    mapping::RateLimiterMappingState,
    msg::QosProducer.Decoder,
)
    pub = state.qos_pub
    pub === nothing && return false

    msg_len = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_block_length(QosProducer.Decoder))
    return with_claimed_buffer!(pub, state.qos_claim, msg_len) do buf
        QosProducer.wrap_and_apply_header!(state.qos_producer_encoder, buf, 0)
        QosProducer.streamId!(state.qos_producer_encoder, mapping.mapping.dest_stream_id)
        QosProducer.producerId!(state.qos_producer_encoder, QosProducer.producerId(msg))
        QosProducer.epoch!(state.qos_producer_encoder, QosProducer.epoch(msg))
        QosProducer.currentSeq!(state.qos_producer_encoder, QosProducer.currentSeq(msg))
    end
end

function forward_qos_consumer!(
    state::RateLimiterState,
    mapping::RateLimiterMappingState,
    msg::QosConsumer.Decoder,
)
    pub = state.qos_pub
    pub === nothing && return false

    msg_len = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_block_length(QosConsumer.Decoder))
    return with_claimed_buffer!(pub, state.qos_claim, msg_len) do buf
        QosConsumer.wrap_and_apply_header!(state.qos_consumer_encoder, buf, 0)
        QosConsumer.streamId!(state.qos_consumer_encoder, mapping.mapping.dest_stream_id)
        QosConsumer.consumerId!(state.qos_consumer_encoder, QosConsumer.consumerId(msg))
        QosConsumer.epoch!(state.qos_consumer_encoder, QosConsumer.epoch(msg))
        QosConsumer.lastSeqSeen!(state.qos_consumer_encoder, QosConsumer.lastSeqSeen(msg))
        QosConsumer.dropsGap!(state.qos_consumer_encoder, QosConsumer.dropsGap(msg))
        QosConsumer.dropsLate!(state.qos_consumer_encoder, QosConsumer.dropsLate(msg))
    end
end
