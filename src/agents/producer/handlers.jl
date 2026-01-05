"""
Create a control-channel fragment assembler for the producer.

Arguments:
- `state`: producer state.
- `hooks`: optional producer hooks.

Returns:
- `Aeron.FragmentAssembler` configured for control messages.
"""
function make_control_assembler(state::ProducerState; hooks::ProducerHooks = NOOP_PRODUCER_HOOKS)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_CONSUMER_HELLO
            ConsumerHello.wrap!(st.runtime.hello_decoder, buffer, 0; header = header)
            handle_consumer_hello!(st, st.runtime.hello_decoder)
            hooks.on_consumer_hello!(st, st.runtime.hello_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a QoS fragment assembler for the producer.

Arguments:
- `state`: producer state.
- `hooks`: optional producer hooks.

Returns:
- `Aeron.FragmentAssembler` configured for QoS messages.
"""
function make_qos_assembler(state::ProducerState; hooks::ProducerHooks = NOOP_PRODUCER_HOOKS)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.runtime.qos_decoder, buffer, 0; header = header)
            handle_qos_consumer!(st, st.runtime.qos_decoder)
            hooks.on_qos_consumer!(st, st.runtime.qos_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll the control subscription for ConsumerHello messages.

Arguments:
- `state`: producer state.
- `assembler`: fragment assembler for control channel.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
@inline function poll_control!(
    state::ProducerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.control.sub_control, assembler, fragment_limit)
end

"""
Poll the QoS subscription for QosConsumer messages.

Arguments:
- `state`: producer state.
- `assembler`: fragment assembler for QoS channel.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
@inline function poll_qos!(
    state::ProducerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_qos, assembler, fragment_limit)
end

"""
Refresh activity timestamps in header and payload superblocks.

Arguments:
- `state`: producer state.

Returns:
- `nothing`.
"""
function refresh_activity_timestamps!(
    state::ProducerState,
    now_ns::UInt64 = UInt64(Clocks.time_nanos(state.clock)),
)
    wrap_superblock!(state.runtime.superblock_encoder, state.mappings.header_mmap, 0)
    ShmRegionSuperblock.activityTimestampNs!(state.runtime.superblock_encoder, now_ns)

    for pmmap in values(state.mappings.payload_mmaps)
        wrap_superblock!(state.runtime.superblock_encoder, pmmap, 0)
        ShmRegionSuperblock.activityTimestampNs!(state.runtime.superblock_encoder, now_ns)
    end
    return nothing
end

@inline function (handler::ProducerAnnounceHandler)(state::ProducerState, now_ns::UInt64)
    if state.emit_announce
        emit_announce!(state)
    end
    refresh_activity_timestamps!(state, now_ns)
    return 1
end

@inline function (handler::ProducerQosHandler)(state::ProducerState, now_ns::UInt64)
    emit_qos!(state)
    return 1
end

@inline function consumer_stream_timeout_ns(state::ProducerState)
    base = max(state.config.announce_interval_ns, state.config.qos_interval_ns)
    return base * 5
end

@inline function consumer_stream_last_seen_ns(entry::ProducerConsumerStream)
    return max(entry.last_hello_ns, entry.last_qos_ns)
end

@inline function reset_consumer_timeout!(state::ProducerState, entry::ProducerConsumerStream, now_ns::UInt64)
    set_interval!(entry.timeout_timer, consumer_stream_timeout_ns(state))
    reset!(entry.timeout_timer, now_ns)
    return nothing
end

@inline function update_descriptor_timer!(entry::ProducerConsumerStream, now_ns::UInt64)
    if entry.max_rate_hz == 0
        set_interval!(entry.descriptor_timer, UInt64(0))
        return nothing
    end
    period_ns = UInt64(1_000_000_000) ÷ UInt64(entry.max_rate_hz)
    set_interval!(entry.descriptor_timer, period_ns)
    if now_ns > period_ns
        reset!(entry.descriptor_timer, now_ns - period_ns)
    else
        reset!(entry.descriptor_timer, UInt64(0))
    end
    return nothing
end

function clear_consumer_stream!(entry::ProducerConsumerStream)
    entry.descriptor_pub === nothing || close(entry.descriptor_pub)
    entry.control_pub === nothing || close(entry.control_pub)
    entry.descriptor_pub = nothing
    entry.control_pub = nothing
    entry.descriptor_channel = ""
    entry.control_channel = ""
    entry.descriptor_stream_id = UInt32(0)
    entry.control_stream_id = UInt32(0)
    entry.max_rate_hz = UInt16(0)
    set_interval!(entry.descriptor_timer, UInt64(0))
    set_interval!(entry.timeout_timer, UInt64(0))
    entry.last_hello_ns = UInt64(0)
    entry.last_qos_ns = UInt64(0)
    return nothing
end

function cleanup_consumer_streams!(state::ProducerState, now_ns::UInt64)
    closed = 0
    for entry in values(state.consumer_streams)
        last_seen = consumer_stream_last_seen_ns(entry)
        last_seen == 0 && continue
        if expired(entry.timeout_timer, now_ns)
            clear_consumer_stream!(entry)
            closed += 1
        end
    end
    return closed
end

function update_consumer_streams!(state::ProducerState, msg::ConsumerHello.Decoder)
    consumer_id = ConsumerHello.consumerId(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    descriptor_stream_id = ConsumerHello.descriptorStreamId(msg)
    control_stream_id = ConsumerHello.controlStreamId(msg)
    descriptor_null = ConsumerHello.descriptorStreamId_null_value(ConsumerHello.Decoder)
    control_null = ConsumerHello.controlStreamId_null_value(ConsumerHello.Decoder)
    descriptor_channel = String(ConsumerHello.descriptorChannel(msg))
    control_channel = String(ConsumerHello.controlChannel(msg))
    descriptor_stream_id_provided =
        descriptor_stream_id != 0 && descriptor_stream_id != descriptor_null
    control_stream_id_provided =
        control_stream_id != 0 && control_stream_id != control_null
    descriptor_channel_provided = !isempty(descriptor_channel)
    control_channel_provided = !isempty(control_channel)
    descriptor_requested = descriptor_channel_provided && descriptor_stream_id_provided
    control_requested = control_channel_provided && control_stream_id_provided
    invalid_descriptor_request = descriptor_channel_provided != descriptor_stream_id_provided
    invalid_control_request = control_channel_provided != control_stream_id_provided

    if !descriptor_requested && !control_requested && !invalid_descriptor_request && !invalid_control_request
        return false
    end

    entry = get(state.consumer_streams, consumer_id, nothing)
    if entry === nothing
        entry = ProducerConsumerStream(
            nothing,
            nothing,
            "",
            "",
            UInt32(0),
            UInt32(0),
            UInt16(0),
            PolledTimer(UInt64(0)),
            PolledTimer(consumer_stream_timeout_ns(state)),
            now_ns,
            UInt64(0),
        )
        state.consumer_streams[consumer_id] = entry
    end

    entry.last_hello_ns = now_ns
    entry.max_rate_hz = ConsumerHello.maxRateHz(msg)
    reset_consumer_timeout!(state, entry, now_ns)
    update_descriptor_timer!(entry, now_ns)

    changed = false
    if descriptor_requested
        if entry.descriptor_pub === nothing ||
            entry.descriptor_stream_id != descriptor_stream_id ||
            entry.descriptor_channel != descriptor_channel
            entry.descriptor_pub === nothing || close(entry.descriptor_pub)
            try
                entry.descriptor_pub = Aeron.add_publication(
                    state.runtime.control.client,
                    descriptor_channel,
                    Int32(descriptor_stream_id),
                )
                entry.descriptor_stream_id = descriptor_stream_id
                entry.descriptor_channel = descriptor_channel
                changed = true
            catch
                entry.descriptor_pub = nothing
                entry.descriptor_stream_id = UInt32(0)
                entry.descriptor_channel = ""
                changed = true
            end
        end
    elseif entry.descriptor_pub !== nothing
        close(entry.descriptor_pub)
        entry.descriptor_pub = nothing
        entry.descriptor_channel = ""
        entry.descriptor_stream_id = UInt32(0)
        changed = true
    end

    if control_requested
        if entry.control_pub === nothing ||
            entry.control_stream_id != control_stream_id ||
            entry.control_channel != control_channel
            entry.control_pub === nothing || close(entry.control_pub)
            try
                entry.control_pub = Aeron.add_publication(
                    state.runtime.control.client,
                    control_channel,
                    Int32(control_stream_id),
                )
                entry.control_stream_id = control_stream_id
                entry.control_channel = control_channel
                changed = true
            catch
                entry.control_pub = nothing
                entry.control_stream_id = UInt32(0)
                entry.control_channel = ""
                changed = true
            end
        end
    elseif entry.control_pub !== nothing
        close(entry.control_pub)
        entry.control_pub = nothing
        entry.control_channel = ""
        entry.control_stream_id = UInt32(0)
        changed = true
    end

    if invalid_descriptor_request || invalid_control_request
        emit_consumer_config!(
            state,
            consumer_id;
            use_shm = true,
            mode = ConsumerHello.mode(msg),
            payload_fallback_uri = "",
            descriptor_channel = "",
            descriptor_stream_id = UInt32(0),
            control_channel = "",
            control_stream_id = UInt32(0),
        )
        return false
    end

    if changed
        emit_consumer_config!(
            state,
            consumer_id;
            use_shm = true,
            mode = ConsumerHello.mode(msg),
            payload_fallback_uri = "",
            descriptor_channel = entry.descriptor_channel,
            descriptor_stream_id = entry.descriptor_stream_id,
            control_channel = entry.control_channel,
            control_stream_id = entry.control_stream_id,
        )
    end
    return changed
end

"""
Handle an incoming QosConsumer message.

Arguments:
- `state`: producer state.
- `msg`: decoded QosConsumer message.

Returns:
- `nothing`.
"""
function handle_qos_consumer!(state::ProducerState, msg::QosConsumer.Decoder)
    QosConsumer.streamId(msg) == state.config.stream_id || return false
    consumer_id = QosConsumer.consumerId(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    entry = get(state.consumer_streams, consumer_id, nothing)
    if entry === nothing
        entry = ProducerConsumerStream(
            nothing,
            nothing,
            "",
            "",
            UInt32(0),
            UInt32(0),
            UInt16(0),
            PolledTimer(UInt64(0)),
            PolledTimer(consumer_stream_timeout_ns(state)),
            UInt64(0),
            now_ns,
        )
        state.consumer_streams[consumer_id] = entry
    end
    entry.last_qos_ns = now_ns
    reset_consumer_timeout!(state, entry, now_ns)
    update_descriptor_timer!(entry, now_ns)
    return true
end

"""
Handle an incoming ConsumerHello message.

Arguments:
- `state`: producer state.
- `msg`: decoded ConsumerHello message.

Returns:
- `nothing`.
"""
function handle_consumer_hello!(state::ProducerState, msg::ConsumerHello.Decoder)
    if ConsumerHello.supportsProgress(msg) == ShmTensorpoolControl.Bool_.TRUE
        state.supports_progress = true
        interval = ConsumerHello.progressIntervalUs(msg)
        bytes_delta = ConsumerHello.progressBytesDelta(msg)

        if interval != typemax(UInt32)
            hint_ns = UInt64(interval) * 1000
            state.progress_interval_ns = max(
                state.config.progress_interval_ns,
                min(state.progress_interval_ns, hint_ns),
            )
        end
        if bytes_delta != typemax(UInt32)
            hint_bytes = UInt64(bytes_delta)
            state.progress_bytes_delta = max(
                state.config.progress_bytes_delta,
                min(state.progress_bytes_delta, hint_bytes),
            )
        end
    end
    update_consumer_streams!(state, msg)
    return nothing
end
