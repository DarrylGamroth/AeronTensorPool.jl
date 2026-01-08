"""
Emit a ConsumerHello message.

Arguments:
- `state`: consumer state.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_consumer_hello!(state::ConsumerState)
    progress_interval = state.config.progress_interval_us
    progress_bytes = state.config.progress_bytes_delta
    progress_major_units = state.config.progress_major_delta_units
    if !state.config.supports_progress
        progress_interval = typemax(UInt32)
        progress_bytes = typemax(UInt32)
        progress_rows = typemax(UInt32)
    end

    requested_descriptor_channel =
        state.assigned_descriptor_stream_id != 0 ?
        state.assigned_descriptor_channel :
        state.config.requested_descriptor_channel
    requested_descriptor_stream_id =
        state.assigned_descriptor_stream_id != 0 ?
        state.assigned_descriptor_stream_id :
        state.config.requested_descriptor_stream_id
    requested_control_channel =
        state.assigned_control_stream_id != 0 ?
        state.assigned_control_channel :
        state.config.requested_control_channel
    requested_control_stream_id =
        state.assigned_control_stream_id != 0 ?
        state.assigned_control_stream_id :
        state.config.requested_control_stream_id

    if !isempty(requested_descriptor_channel) && requested_descriptor_stream_id == 0
        return false
    end
    if !isempty(requested_control_channel) && requested_control_stream_id == 0
        return false
    end

    descriptor_requested = !isempty(requested_descriptor_channel) && requested_descriptor_stream_id != 0
    control_requested = !isempty(requested_control_channel) && requested_control_stream_id != 0

    msg_len = MESSAGE_HEADER_LEN +
        Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder)) +
        Int(ConsumerHello.descriptorChannel_header_length) +
        (descriptor_requested ? sizeof(requested_descriptor_channel) : 0) +
        Int(ConsumerHello.controlChannel_header_length) +
        (control_requested ? sizeof(requested_control_channel) : 0)

    sent = let st = state,
        interval = progress_interval,
        bytes = progress_bytes,
        major_delta_units = progress_major_units,
        descriptor_requested = descriptor_requested,
        control_requested = control_requested,
        requested_descriptor_channel = requested_descriptor_channel,
        requested_descriptor_stream_id = requested_descriptor_stream_id,
        requested_control_channel = requested_control_channel,
        requested_control_stream_id = requested_control_stream_id
        with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.hello_claim, msg_len) do buf
            ConsumerHello.wrap_and_apply_header!(st.runtime.hello_encoder, buf, 0)
            ConsumerHello.streamId!(st.runtime.hello_encoder, st.config.stream_id)
            ConsumerHello.consumerId!(st.runtime.hello_encoder, st.config.consumer_id)
            ConsumerHello.supportsShm!(
                st.runtime.hello_encoder,
                st.config.supports_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerHello.supportsProgress!(
                st.runtime.hello_encoder,
                st.config.supports_progress ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerHello.mode!(st.runtime.hello_encoder, st.config.mode)
            ConsumerHello.maxRateHz!(st.runtime.hello_encoder, st.config.max_rate_hz)
            ConsumerHello.expectedLayoutVersion!(st.runtime.hello_encoder, st.config.expected_layout_version)
            ConsumerHello.progressIntervalUs!(st.runtime.hello_encoder, interval)
            ConsumerHello.progressBytesDelta!(st.runtime.hello_encoder, bytes)
            ConsumerHello.progressMajorDeltaUnits!(st.runtime.hello_encoder, major_delta_units)
            if descriptor_requested
                ConsumerHello.descriptorChannel!(st.runtime.hello_encoder, requested_descriptor_channel)
            else
                ConsumerHello.descriptorChannel_length!(st.runtime.hello_encoder, 0)
            end
            if control_requested
                ConsumerHello.controlChannel!(st.runtime.hello_encoder, requested_control_channel)
            else
                ConsumerHello.controlChannel_length!(st.runtime.hello_encoder, 0)
            end
            ConsumerHello.descriptorStreamId!(
                st.runtime.hello_encoder,
                descriptor_requested ? requested_descriptor_stream_id : UInt32(0),
            )
            ConsumerHello.controlStreamId!(
                st.runtime.hello_encoder,
                control_requested ? requested_control_stream_id : UInt32(0),
            )
        end
    end
    sent || return false
    state.metrics.hello_count += 1
    return true
end

"""
Emit a QosConsumer message.

Arguments:
- `state`: consumer state.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_qos!(state::ConsumerState)
    sent = let st = state
        with_claimed_buffer!(st.runtime.pub_qos, st.runtime.qos_claim, QOS_CONSUMER_LEN) do buf
            QosConsumer.wrap_and_apply_header!(st.runtime.qos_encoder, buf, 0)
            QosConsumer.streamId!(st.runtime.qos_encoder, st.config.stream_id)
            QosConsumer.consumerId!(st.runtime.qos_encoder, st.config.consumer_id)
            QosConsumer.epoch!(st.runtime.qos_encoder, st.mappings.mapped_epoch)
            QosConsumer.lastSeqSeen!(st.runtime.qos_encoder, st.metrics.last_seq_seen)
            QosConsumer.dropsGap!(st.runtime.qos_encoder, st.metrics.drops_gap)
            QosConsumer.dropsLate!(st.runtime.qos_encoder, st.metrics.drops_late)
            QosConsumer.mode!(st.runtime.qos_encoder, st.config.mode)
        end
    end
    sent || return false
    state.metrics.qos_count += 1
    return true
end
