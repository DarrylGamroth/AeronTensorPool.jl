"""
Return true if a progress update should be emitted.
"""
@inline function should_emit_progress!(state::ProducerState, bytes_filled::UInt64, final::Bool)
    if final
        return true
    end
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    if now_ns - state.metrics.last_progress_ns < state.progress_interval_ns &&
       bytes_filled - state.metrics.last_progress_bytes < state.progress_bytes_delta
        return false
    end
    return true
end

"""
Emit a FrameProgress COMPLETE message.

Arguments:
- `state`: producer state.
- `frame_id`: frame identifier (seq).
- `header_index`: header slot index.
- `bytes_filled`: payload bytes filled.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_progress_complete!(
    state::ProducerState,
    frame_id::UInt64,
    header_index::UInt32,
    bytes_filled::UInt64,
)
    sent = let st = state,
        frame_id = frame_id,
        header_index = header_index,
        bytes_filled = bytes_filled
        with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.progress_claim, FRAME_PROGRESS_LEN) do buf
            FrameProgress.wrap_and_apply_header!(st.runtime.progress_encoder, buf, 0)
            FrameProgress.streamId!(st.runtime.progress_encoder, st.config.stream_id)
            FrameProgress.epoch!(st.runtime.progress_encoder, st.epoch)
            FrameProgress.frameId!(st.runtime.progress_encoder, frame_id)
            FrameProgress.headerIndex!(st.runtime.progress_encoder, header_index)
            FrameProgress.payloadBytesFilled!(st.runtime.progress_encoder, bytes_filled)
            FrameProgress.state!(st.runtime.progress_encoder, FrameProgressState.COMPLETE)
        end
    end
    sent || return false
    state.metrics.last_progress_ns = UInt64(Clocks.time_nanos(state.clock))
    state.metrics.last_progress_bytes = bytes_filled
    publish_progress_to_consumers!(state, frame_id, header_index, bytes_filled)
    return true
end

"""
Emit a ShmPoolAnnounce message.

Arguments:
- `state`: producer state.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_announce!(state::ProducerState)
    payload_count = length(state.config.payload_pools)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    msg_len = MESSAGE_HEADER_LEN +
        Int(ShmPoolAnnounce.sbe_block_length(ShmPoolAnnounce.Decoder)) +
        4 +
        sum(
            10 + ShmPoolAnnounce.PayloadPools.regionUri_header_length + sizeof(pool.uri)
            for pool in state.config.payload_pools
        ) +
        ShmPoolAnnounce.headerRegionUri_header_length +
        sizeof(state.config.header_uri)

    sent = let st = state,
        payload_count = payload_count,
        now_ns = now_ns
        with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.progress_claim, msg_len) do buf
            ShmPoolAnnounce.wrap_and_apply_header!(st.runtime.announce_encoder, buf, 0)
            ShmPoolAnnounce.streamId!(st.runtime.announce_encoder, st.config.stream_id)
            ShmPoolAnnounce.producerId!(st.runtime.announce_encoder, st.config.producer_id)
            ShmPoolAnnounce.epoch!(st.runtime.announce_encoder, st.epoch)
            ShmPoolAnnounce.announceTimestampNs!(st.runtime.announce_encoder, now_ns)
            ShmPoolAnnounce.layoutVersion!(st.runtime.announce_encoder, st.config.layout_version)
            ShmPoolAnnounce.headerNslots!(st.runtime.announce_encoder, st.config.nslots)
            ShmPoolAnnounce.headerSlotBytes!(st.runtime.announce_encoder, UInt16(HEADER_SLOT_BYTES))
            ShmPoolAnnounce.maxDims!(st.runtime.announce_encoder, st.config.max_dims)

            pools_group = ShmPoolAnnounce.payloadPools!(st.runtime.announce_encoder, payload_count)
            for pool in st.config.payload_pools
                entry = ShmPoolAnnounce.PayloadPools.next!(pools_group)
                ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
                ShmPoolAnnounce.PayloadPools.poolNslots!(entry, pool.nslots)
                ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
                ShmPoolAnnounce.PayloadPools.regionUri!(entry, pool.uri)
            end
            ShmPoolAnnounce.headerRegionUri!(st.runtime.announce_encoder, st.config.header_uri)
        end
    end
    sent || return false
    state.metrics.announce_count += 1
    return true
end

"""
Emit a QosProducer message.

Arguments:
- `state`: producer state.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_qos!(state::ProducerState)
    sent = let st = state
        with_claimed_buffer!(st.runtime.pub_qos, st.runtime.qos_claim, QOS_PRODUCER_LEN) do buf
            QosProducer.wrap_and_apply_header!(st.runtime.qos_encoder, buf, 0)
            QosProducer.streamId!(st.runtime.qos_encoder, st.config.stream_id)
            QosProducer.producerId!(st.runtime.qos_encoder, st.config.producer_id)
            QosProducer.epoch!(st.runtime.qos_encoder, st.epoch)
            QosProducer.currentSeq!(st.runtime.qos_encoder, st.seq)
        end
    end
    sent || return false
    state.metrics.qos_count += 1
    return true
end

"""
Emit a ConsumerConfig message to a consumer.

Arguments:
- `state`: producer state.
- `consumer_id`: consumer identifier.
- `mode`: consumer mode enum.
- `decimation`: decimation ratio (default: 1).
- `fallback_uri`: payload fallback URI (default: "").

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_consumer_config!(
    state::ProducerState,
    consumer_id::UInt32;
    use_shm::Bool = state.config.nslots > 0,
    mode::Mode.SbeEnum = Mode.STREAM,
    decimation::UInt16 = UInt16(1),
    payload_fallback_uri::AbstractString = "",
    descriptor_channel::AbstractString = "",
    descriptor_stream_id::UInt32 = UInt32(0),
    control_channel::AbstractString = "",
    control_stream_id::UInt32 = UInt32(0),
)
    msg_len = MESSAGE_HEADER_LEN +
        Int(ConsumerConfigMsg.sbe_block_length(ConsumerConfigMsg.Decoder)) +
        Int(ConsumerConfigMsg.payloadFallbackUri_header_length) +
        Int(ConsumerConfigMsg.descriptorChannel_header_length) +
        Int(ConsumerConfigMsg.controlChannel_header_length) +
        sizeof(payload_fallback_uri) +
        sizeof(descriptor_channel) +
        sizeof(control_channel)

    sent = let st = state,
        consumer_id = consumer_id,
        use_shm = use_shm,
        mode = mode,
        decimation = decimation,
        payload_fallback_uri = payload_fallback_uri,
        descriptor_channel = descriptor_channel,
        descriptor_stream_id = descriptor_stream_id,
        control_channel = control_channel,
        control_stream_id = control_stream_id
        with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.config_claim, msg_len) do buf
            ConsumerConfigMsg.wrap_and_apply_header!(st.runtime.config_encoder, buf, 0)
            ConsumerConfigMsg.streamId!(st.runtime.config_encoder, st.config.stream_id)
            ConsumerConfigMsg.consumerId!(st.runtime.config_encoder, consumer_id)
            ConsumerConfigMsg.useShm!(
                st.runtime.config_encoder,
                use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerConfigMsg.mode!(st.runtime.config_encoder, mode)
            ConsumerConfigMsg.decimation!(st.runtime.config_encoder, decimation)
            ConsumerConfigMsg.descriptorStreamId!(
                st.runtime.config_encoder,
                descriptor_stream_id != 0 ?
                descriptor_stream_id :
                ConsumerConfigMsg.descriptorStreamId_null_value(ConsumerConfigMsg.Encoder),
            )
            ConsumerConfigMsg.controlStreamId!(
                st.runtime.config_encoder,
                control_stream_id != 0 ?
                control_stream_id :
                ConsumerConfigMsg.controlStreamId_null_value(ConsumerConfigMsg.Encoder),
            )
            ConsumerConfigMsg.payloadFallbackUri!(st.runtime.config_encoder, payload_fallback_uri)
            if isempty(descriptor_channel)
                ConsumerConfigMsg.descriptorChannel_length!(st.runtime.config_encoder, 0)
            else
                ConsumerConfigMsg.descriptorChannel!(st.runtime.config_encoder, descriptor_channel)
            end
            if isempty(control_channel)
                ConsumerConfigMsg.controlChannel_length!(st.runtime.config_encoder, 0)
            else
                ConsumerConfigMsg.controlChannel!(st.runtime.config_encoder, control_channel)
            end
        end
    end
    return sent
end

function publish_descriptor_to_consumers!(
    state::ProducerState,
    seq::UInt64,
    header_index::UInt32,
    meta_version::UInt32,
    now_ns::UInt64,
)
    any_sent = false
    for entry in values(state.consumer_streams)
        pub = entry.descriptor_pub
        pub === nothing && continue
        if entry.max_rate_hz != 0 && now_ns < entry.next_descriptor_ns
            continue
        end
        sent = let st = state,
            seq = seq,
            header_index = header_index,
            meta_version = meta_version,
            now_ns = now_ns,
            pub = pub
            with_claimed_buffer!(pub, st.runtime.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
                FrameDescriptor.wrap_and_apply_header!(st.runtime.descriptor_encoder, buf, 0)
                encode_frame_descriptor!(st.runtime.descriptor_encoder, st, seq, header_index, meta_version, now_ns)
            end
        end
        if sent
            any_sent = true
        end
        if sent && entry.max_rate_hz != 0
            period_ns = UInt64(1_000_000_000) ÷ UInt64(entry.max_rate_hz)
            entry.next_descriptor_ns = now_ns + period_ns
        end
    end
    return any_sent
end

function publish_progress_to_consumers!(
    state::ProducerState,
    frame_id::UInt64,
    header_index::UInt32,
    bytes_filled::UInt64,
)
    for entry in values(state.consumer_streams)
        pub = entry.control_pub
        pub === nothing && continue
        let st = state,
            frame_id = frame_id,
            header_index = header_index,
            bytes_filled = bytes_filled,
            pub = pub
            with_claimed_buffer!(pub, st.runtime.progress_claim, FRAME_PROGRESS_LEN) do buf
                FrameProgress.wrap_and_apply_header!(st.runtime.progress_encoder, buf, 0)
                FrameProgress.streamId!(st.runtime.progress_encoder, st.config.stream_id)
                FrameProgress.epoch!(st.runtime.progress_encoder, st.epoch)
                FrameProgress.frameId!(st.runtime.progress_encoder, frame_id)
                FrameProgress.headerIndex!(st.runtime.progress_encoder, header_index)
                FrameProgress.payloadBytesFilled!(st.runtime.progress_encoder, bytes_filled)
                FrameProgress.state!(st.runtime.progress_encoder, FrameProgressState.COMPLETE)
            end
        end
    end
    return nothing
end
