"""
Forward ShmPoolAnnounce to the bridge control channel.

Arguments:
- `state`: bridge sender state.
- `msg`: decoded ShmPoolAnnounce message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_forward_announce!(state::BridgeSenderState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(ShmPoolAnnounce.sbe_decoded_length(msg))
    payloads = ShmPoolAnnounce.payloadPools(msg)
    payload_count = length(payloads)

    sent = let st = state,
        msg = msg,
        payloads = payloads,
        payload_count = payload_count
        with_claimed_buffer!(st.pub_control, st.control_claim, msg_len) do buf
            ShmPoolAnnounce.wrap_and_apply_header!(st.announce_encoder, buf, 0)
            ShmPoolAnnounce.streamId!(st.announce_encoder, st.mapping.dest_stream_id)
            ShmPoolAnnounce.producerId!(st.announce_encoder, ShmPoolAnnounce.producerId(msg))
            ShmPoolAnnounce.epoch!(st.announce_encoder, ShmPoolAnnounce.epoch(msg))
            ShmPoolAnnounce.announceTimestampNs!(st.announce_encoder, ShmPoolAnnounce.announceTimestampNs(msg))
            ShmPoolAnnounce.announceClockDomain!(st.announce_encoder, ShmPoolAnnounce.announceClockDomain(msg))
            ShmPoolAnnounce.layoutVersion!(st.announce_encoder, ShmPoolAnnounce.layoutVersion(msg))
            ShmPoolAnnounce.headerNslots!(st.announce_encoder, ShmPoolAnnounce.headerNslots(msg))
            ShmPoolAnnounce.headerSlotBytes!(st.announce_encoder, ShmPoolAnnounce.headerSlotBytes(msg))
            pools_group = ShmPoolAnnounce.payloadPools!(st.announce_encoder, payload_count)
            for pool in payloads
                entry = ShmPoolAnnounce.PayloadPools.next!(pools_group)
                ShmPoolAnnounce.PayloadPools.poolId!(entry, ShmPoolAnnounce.PayloadPools.poolId(pool))
                ShmPoolAnnounce.PayloadPools.poolNslots!(entry, ShmPoolAnnounce.PayloadPools.poolNslots(pool))
                ShmPoolAnnounce.PayloadPools.strideBytes!(entry, ShmPoolAnnounce.PayloadPools.strideBytes(pool))
                ShmPoolAnnounce.PayloadPools.regionUri!(entry, ShmPoolAnnounce.PayloadPools.regionUri(pool))
            end
            header_uri = ShmPoolAnnounce.headerRegionUri(msg, StringView)
            ShmPoolAnnounce.headerRegionUri!(st.announce_encoder, header_uri)
        end
    end
    sent || return false
    state.metrics.control_forwarded += 1
    return true
end

"""
Forward DataSourceAnnounce over the bridge metadata channel.

Arguments:
- `state`: bridge sender state.
- `msg`: decoded DataSourceAnnounce message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_forward_metadata_announce!(state::BridgeSenderState, msg::DataSourceAnnounce.Decoder)
    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceAnnounce.sbe_decoded_length(msg))
    stream_id = ifelse(
        state.mapping.metadata_stream_id == 0,
        state.mapping.dest_stream_id,
        state.mapping.metadata_stream_id,
    )

    return with_claimed_buffer!(state.pub_metadata, state.metadata_claim, msg_len) do buf
        DataSourceAnnounce.wrap_and_apply_header!(state.metadata_announce_encoder, buf, 0)
        DataSourceAnnounce.streamId!(state.metadata_announce_encoder, stream_id)
        DataSourceAnnounce.producerId!(state.metadata_announce_encoder, DataSourceAnnounce.producerId(msg))
        DataSourceAnnounce.epoch!(state.metadata_announce_encoder, DataSourceAnnounce.epoch(msg))
        DataSourceAnnounce.metaVersion!(state.metadata_announce_encoder, DataSourceAnnounce.metaVersion(msg))
        DataSourceAnnounce.name!(state.metadata_announce_encoder, DataSourceAnnounce.name(msg))
        DataSourceAnnounce.summary!(state.metadata_announce_encoder, DataSourceAnnounce.summary(msg))
    end
end

"""
Forward DataSourceMeta over the bridge metadata channel.

Arguments:
- `state`: bridge sender state.
- `msg`: decoded DataSourceMeta message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_forward_metadata_meta!(state::BridgeSenderState, msg::DataSourceMeta.Decoder)
    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceMeta.sbe_decoded_length(msg))
    stream_id = ifelse(
        state.mapping.metadata_stream_id == 0,
        state.mapping.dest_stream_id,
        state.mapping.metadata_stream_id,
    )

    return with_claimed_buffer!(state.pub_metadata, state.metadata_claim, msg_len) do buf
        DataSourceMeta.wrap_and_apply_header!(state.metadata_meta_encoder, buf, 0)
        DataSourceMeta.streamId!(state.metadata_meta_encoder, stream_id)
        DataSourceMeta.metaVersion!(state.metadata_meta_encoder, DataSourceMeta.metaVersion(msg))
        DataSourceMeta.timestampNs!(state.metadata_meta_encoder, DataSourceMeta.timestampNs(msg))
        attrs = DataSourceMeta.attributes(msg)
        attrs_enc = DataSourceMeta.attributes!(state.metadata_meta_encoder, length(attrs))
        for attr in attrs
            entry = DataSourceMeta.Attributes.next!(attrs_enc)
            DataSourceMeta.Attributes.key!(entry, DataSourceMeta.Attributes.key(attr))
            DataSourceMeta.Attributes.format!(entry, DataSourceMeta.Attributes.format(attr))
            DataSourceMeta.Attributes.value!(entry, DataSourceMeta.Attributes.value(attr))
        end
    end
end

"""
Publish DataSourceAnnounce on the local metadata channel.

Arguments:
- `state`: bridge receiver state.
- `msg`: decoded DataSourceAnnounce message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_publish_metadata_announce!(state::BridgeReceiverState, msg::DataSourceAnnounce.Decoder)
    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceAnnounce.sbe_decoded_length(msg))
    pub = state.pub_metadata_local
    pub === nothing && return false
    stream_id = ifelse(
        state.mapping.metadata_stream_id == 0,
        state.mapping.dest_stream_id,
        state.mapping.metadata_stream_id,
    )

    return with_claimed_buffer!(pub, state.metadata_claim, msg_len) do buf
        DataSourceAnnounce.wrap_and_apply_header!(state.metadata_announce_encoder, buf, 0)
        DataSourceAnnounce.streamId!(state.metadata_announce_encoder, stream_id)
        DataSourceAnnounce.producerId!(state.metadata_announce_encoder, DataSourceAnnounce.producerId(msg))
        DataSourceAnnounce.epoch!(state.metadata_announce_encoder, DataSourceAnnounce.epoch(msg))
        DataSourceAnnounce.metaVersion!(state.metadata_announce_encoder, DataSourceAnnounce.metaVersion(msg))
        DataSourceAnnounce.name!(state.metadata_announce_encoder, DataSourceAnnounce.name(msg))
        DataSourceAnnounce.summary!(state.metadata_announce_encoder, DataSourceAnnounce.summary(msg))
    end
end

"""
Publish DataSourceMeta on the local metadata channel.

Arguments:
- `state`: bridge receiver state.
- `msg`: decoded DataSourceMeta message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_publish_metadata_meta!(state::BridgeReceiverState, msg::DataSourceMeta.Decoder)
    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceMeta.sbe_decoded_length(msg))
    pub = state.pub_metadata_local
    pub === nothing && return false
    stream_id = ifelse(
        state.mapping.metadata_stream_id == 0,
        state.mapping.dest_stream_id,
        state.mapping.metadata_stream_id,
    )

    return with_claimed_buffer!(pub, state.metadata_claim, msg_len) do buf
        DataSourceMeta.wrap_and_apply_header!(state.metadata_meta_encoder, buf, 0)
        DataSourceMeta.streamId!(state.metadata_meta_encoder, stream_id)
        DataSourceMeta.metaVersion!(state.metadata_meta_encoder, DataSourceMeta.metaVersion(msg))
        DataSourceMeta.timestampNs!(state.metadata_meta_encoder, DataSourceMeta.timestampNs(msg))
        attrs = DataSourceMeta.attributes(msg)
        attrs_enc = DataSourceMeta.attributes!(state.metadata_meta_encoder, length(attrs))
        for attr in attrs
            entry = DataSourceMeta.Attributes.next!(attrs_enc)
            DataSourceMeta.Attributes.key!(entry, DataSourceMeta.Attributes.key(attr))
            DataSourceMeta.Attributes.format!(entry, DataSourceMeta.Attributes.format(attr))
            DataSourceMeta.Attributes.value!(entry, DataSourceMeta.Attributes.value(attr))
        end
    end
end

"""
Forward QosProducer over the bridge control channel.

Arguments:
- `state`: bridge sender state.
- `msg`: decoded QosProducer message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_forward_qos_producer!(state::BridgeSenderState, msg::QosProducer.Decoder)
    state.config.forward_qos || return false
    QosProducer.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_decoded_length(msg))
    sent = with_claimed_buffer!(state.pub_control, state.control_claim, msg_len) do buf
        QosProducer.wrap_and_apply_header!(state.qos_producer_encoder, buf, 0)
        QosProducer.streamId!(state.qos_producer_encoder, state.mapping.dest_stream_id)
        QosProducer.producerId!(state.qos_producer_encoder, QosProducer.producerId(msg))
        QosProducer.epoch!(state.qos_producer_encoder, QosProducer.epoch(msg))
        QosProducer.currentSeq!(state.qos_producer_encoder, QosProducer.currentSeq(msg))
    end
    sent || return false
    state.metrics.control_forwarded += 1
    return true
end

"""
Forward QosConsumer over the bridge control channel.

Arguments:
- `state`: bridge sender state.
- `msg`: decoded QosConsumer message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_forward_qos_consumer!(state::BridgeSenderState, msg::QosConsumer.Decoder)
    state.config.forward_qos || return false
    QosConsumer.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_decoded_length(msg))
    sent = with_claimed_buffer!(state.pub_control, state.control_claim, msg_len) do buf
        QosConsumer.wrap_and_apply_header!(state.qos_consumer_encoder, buf, 0)
        QosConsumer.streamId!(state.qos_consumer_encoder, state.mapping.dest_stream_id)
        QosConsumer.consumerId!(state.qos_consumer_encoder, QosConsumer.consumerId(msg))
        QosConsumer.epoch!(state.qos_consumer_encoder, QosConsumer.epoch(msg))
        QosConsumer.lastSeqSeen!(state.qos_consumer_encoder, QosConsumer.lastSeqSeen(msg))
        QosConsumer.dropsGap!(state.qos_consumer_encoder, QosConsumer.dropsGap(msg))
        QosConsumer.dropsLate!(state.qos_consumer_encoder, QosConsumer.dropsLate(msg))
        QosConsumer.mode!(state.qos_consumer_encoder, QosConsumer.mode(msg))
    end
    sent || return false
    state.metrics.control_forwarded += 1
    return true
end

"""
Forward FrameProgress over the bridge control channel.

Arguments:
- `state`: bridge sender state.
- `msg`: decoded FrameProgress message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_forward_progress!(state::BridgeSenderState, msg::FrameProgress.Decoder)
    state.config.forward_progress || return false
    FrameProgress.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_decoded_length(msg))
    sent = with_claimed_buffer!(state.pub_control, state.control_claim, msg_len) do buf
        FrameProgress.wrap_and_apply_header!(state.progress_encoder, buf, 0)
        FrameProgress.streamId!(state.progress_encoder, state.mapping.dest_stream_id)
        FrameProgress.epoch!(state.progress_encoder, FrameProgress.epoch(msg))
        FrameProgress.seq!(state.progress_encoder, FrameProgress.seq(msg))
        FrameProgress.payloadBytesFilled!(state.progress_encoder, FrameProgress.payloadBytesFilled(msg))
        FrameProgress.state!(state.progress_encoder, FrameProgress.state(msg))
    end
    sent || return false
    state.metrics.control_forwarded += 1
    return true
end

"""
Publish QosProducer on the local control channel.

Arguments:
- `state`: bridge receiver state.
- `msg`: decoded QosProducer message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_publish_qos_producer!(state::BridgeReceiverState, msg::QosProducer.Decoder)
    state.config.forward_qos || return false
    QosProducer.streamId(msg) == state.mapping.dest_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_decoded_length(msg))
    pub = state.pub_control_local
    pub === nothing && return false

    sent = with_claimed_buffer!(pub, state.control_claim, msg_len) do buf
        QosProducer.wrap_and_apply_header!(state.qos_producer_encoder, buf, 0)
        QosProducer.streamId!(state.qos_producer_encoder, state.mapping.dest_stream_id)
        QosProducer.producerId!(state.qos_producer_encoder, QosProducer.producerId(msg))
        QosProducer.epoch!(state.qos_producer_encoder, QosProducer.epoch(msg))
        QosProducer.currentSeq!(state.qos_producer_encoder, QosProducer.currentSeq(msg))
    end
    sent || return false
    state.metrics.control_forwarded += 1
    return true
end

"""
Publish QosConsumer on the local control channel.

Arguments:
- `state`: bridge receiver state.
- `msg`: decoded QosConsumer message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_publish_qos_consumer!(state::BridgeReceiverState, msg::QosConsumer.Decoder)
    state.config.forward_qos || return false
    QosConsumer.streamId(msg) == state.mapping.dest_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_decoded_length(msg))
    pub = state.pub_control_local
    pub === nothing && return false

    sent = with_claimed_buffer!(pub, state.control_claim, msg_len) do buf
        QosConsumer.wrap_and_apply_header!(state.qos_consumer_encoder, buf, 0)
        QosConsumer.streamId!(state.qos_consumer_encoder, state.mapping.dest_stream_id)
        QosConsumer.consumerId!(state.qos_consumer_encoder, QosConsumer.consumerId(msg))
        QosConsumer.epoch!(state.qos_consumer_encoder, QosConsumer.epoch(msg))
        QosConsumer.lastSeqSeen!(state.qos_consumer_encoder, QosConsumer.lastSeqSeen(msg))
        QosConsumer.dropsGap!(state.qos_consumer_encoder, QosConsumer.dropsGap(msg))
        QosConsumer.dropsLate!(state.qos_consumer_encoder, QosConsumer.dropsLate(msg))
        QosConsumer.mode!(state.qos_consumer_encoder, QosConsumer.mode(msg))
    end
    sent || return false
    state.metrics.control_forwarded += 1
    return true
end

"""
Publish FrameProgress on the local control channel.

Arguments:
- `state`: bridge receiver state.
- `msg`: decoded FrameProgress message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function bridge_publish_progress!(state::BridgeReceiverState, msg::FrameProgress.Decoder)
    state.config.forward_progress || return false
    FrameProgress.streamId(msg) == state.mapping.dest_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_decoded_length(msg))
    pub = state.pub_control_local
    pub === nothing && return false

    sent = with_claimed_buffer!(pub, state.control_claim, msg_len) do buf
        FrameProgress.wrap_and_apply_header!(state.progress_encoder, buf, 0)
        FrameProgress.streamId!(state.progress_encoder, state.mapping.dest_stream_id)
        FrameProgress.epoch!(state.progress_encoder, FrameProgress.epoch(msg))
        FrameProgress.seq!(state.progress_encoder, FrameProgress.seq(msg))
        FrameProgress.payloadBytesFilled!(state.progress_encoder, FrameProgress.payloadBytesFilled(msg))
        FrameProgress.state!(state.progress_encoder, FrameProgress.state(msg))
    end
    sent || return false
    state.metrics.control_forwarded += 1
    return true
end
