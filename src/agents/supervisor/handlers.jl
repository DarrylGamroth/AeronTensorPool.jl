function (handler::SupervisorLivenessHandler)(state::SupervisorState, now_ns::UInt64)
    return check_liveness!(state, now_ns) ? 1 : 0
end

"""
Create a control-channel fragment assembler for the supervisor.

Arguments:
- `state`: supervisor state.
- `callbacks`: optional supervisor callbacks.

Returns:
- `Aeron.FragmentAssembler` configured for control messages.
"""
function make_control_assembler(state::SupervisorState; callbacks::SupervisorCallbacks = NOOP_SUPERVISOR_CALLBACKS)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.runtime.announce_decoder, buffer, 0; header = header)
            handle_shm_pool_announce!(st, st.runtime.announce_decoder)
            callbacks.on_announce!(st, st.runtime.announce_decoder)
        elseif template_id == TEMPLATE_CONSUMER_HELLO
            ConsumerHello.wrap!(st.runtime.hello_decoder, buffer, 0; header = header)
            handle_consumer_hello!(st, st.runtime.hello_decoder)
            callbacks.on_consumer_hello!(st, st.runtime.hello_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a QoS fragment assembler for the supervisor.

Arguments:
- `state`: supervisor state.
- `callbacks`: optional supervisor callbacks.

Returns:
- `Aeron.FragmentAssembler` configured for QoS messages.
"""
function make_qos_assembler(state::SupervisorState; callbacks::SupervisorCallbacks = NOOP_SUPERVISOR_CALLBACKS)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_QOS_PRODUCER
            QosProducer.wrap!(st.runtime.qos_producer_decoder, buffer, 0; header = header)
            handle_qos_producer!(st, st.runtime.qos_producer_decoder)
            callbacks.on_qos_producer!(st, st.runtime.qos_producer_decoder)
        elseif template_id == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.runtime.qos_consumer_decoder, buffer, 0; header = header)
            handle_qos_consumer!(st, st.runtime.qos_consumer_decoder)
            callbacks.on_qos_consumer!(st, st.runtime.qos_consumer_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll the control subscription for announce and hello messages.

Arguments:
- `state`: supervisor state.
- `assembler`: fragment assembler for control channel.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_control!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.control.sub_control, assembler, fragment_limit)
end

"""
Poll the QoS subscription for producer/consumer QoS messages.

Arguments:
- `state`: supervisor state.
- `assembler`: fragment assembler for QoS channel.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_qos!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_qos, assembler, fragment_limit)
end

"""
Handle an incoming ShmPoolAnnounce message.

Arguments:
- `state`: supervisor state.
- `msg`: decoded ShmPoolAnnounce message.

Returns:
- `nothing`.
"""
function handle_shm_pool_announce!(state::SupervisorState, msg::ShmPoolAnnounce.Decoder)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    pid = ShmPoolAnnounce.producerId(msg)
    ep = ShmPoolAnnounce.epoch(msg)
    info = get(state.tracking.producers, pid, nothing)
    if info === nothing
        timer = PolledTimer(state.config.liveness_timeout_ns)
        reset!(timer, now_ns)
        state.tracking.producers[pid] = ProducerInfo(
            ShmPoolAnnounce.streamId(msg),
            ep,
            now_ns,
            UInt64(0),
            UInt64(0),
            timer,
        )
    else
        info.stream_id = ShmPoolAnnounce.streamId(msg)
        info.epoch = ep
        info.last_announce_ns = now_ns
        reset!(info.liveness_timer, now_ns)
    end
    return nothing
end

"""
Handle an incoming QosProducer message.

Arguments:
- `state`: supervisor state.
- `msg`: decoded QosProducer message.

Returns:
- `nothing`.
"""
function handle_qos_producer!(state::SupervisorState, msg::QosProducer.Decoder)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    pid = QosProducer.producerId(msg)
    info = get(state.tracking.producers, pid, nothing)
    if info === nothing
        timer = PolledTimer(state.config.liveness_timeout_ns)
        reset!(timer, now_ns)
        state.tracking.producers[pid] = ProducerInfo(
            QosProducer.streamId(msg),
            QosProducer.epoch(msg),
            UInt64(0),
            now_ns,
            QosProducer.currentSeq(msg),
            timer,
        )
    else
        info.epoch = QosProducer.epoch(msg)
        info.last_qos_ns = now_ns
        info.current_seq = QosProducer.currentSeq(msg)
        reset!(info.liveness_timer, now_ns)
    end
    return nothing
end

"""
Handle an incoming ConsumerHello message.

Arguments:
- `state`: supervisor state.
- `msg`: decoded ConsumerHello message.

Returns:
- `nothing`.
"""
function handle_consumer_hello!(state::SupervisorState, msg::ConsumerHello.Decoder)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    cid = ConsumerHello.consumerId(msg)
    info = get(state.tracking.consumers, cid, nothing)
    if info === nothing
        timer = PolledTimer(state.config.liveness_timeout_ns)
        reset!(timer, now_ns)
        state.tracking.consumers[cid] = ConsumerInfo(
            ConsumerHello.streamId(msg),
            cid,
            UInt64(0),
            ConsumerHello.mode(msg),
            now_ns,
            UInt64(0),
            UInt64(0),
            UInt64(0),
            UInt64(0),
            timer,
        )
    else
        info.last_hello_ns = now_ns
        reset!(info.liveness_timer, now_ns)
    end
    return nothing
end

"""
Handle an incoming QosConsumer message.

Arguments:
- `state`: supervisor state.
- `msg`: decoded QosConsumer message.

Returns:
- `nothing`.
"""
function handle_qos_consumer!(state::SupervisorState, msg::QosConsumer.Decoder)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    cid = QosConsumer.consumerId(msg)
    info = get(state.tracking.consumers, cid, nothing)
    if info === nothing
        timer = PolledTimer(state.config.liveness_timeout_ns)
        reset!(timer, now_ns)
        state.tracking.consumers[cid] = ConsumerInfo(
            QosConsumer.streamId(msg),
            cid,
            QosConsumer.epoch(msg),
            QosConsumer.mode(msg),
            UInt64(0),
            now_ns,
            QosConsumer.lastSeqSeen(msg),
            QosConsumer.dropsGap(msg),
            QosConsumer.dropsLate(msg),
            timer,
        )
    else
        info.epoch = QosConsumer.epoch(msg)
        info.last_qos_ns = now_ns
        info.last_seq_seen = QosConsumer.lastSeqSeen(msg)
        info.drops_gap = QosConsumer.dropsGap(msg)
        info.drops_late = QosConsumer.dropsLate(msg)
        reset!(info.liveness_timer, now_ns)
    end
    return nothing
end

"""
Check liveness and return true if any action was taken.
"""
function check_liveness!(state::SupervisorState, now_ns::UInt64)
    state.tracking.liveness_count += 1
    for (pid, info) in state.tracking.producers
        if expired(info.liveness_timer, now_ns)
            @tp_warn "Producer stale" producer_id = pid epoch = info.epoch
        end
    end
    for (cid, info) in state.tracking.consumers
        if expired(info.liveness_timer, now_ns)
            @tp_warn "Consumer stale" consumer_id = cid epoch = info.epoch
        end
        if info.drops_gap > 0 || info.drops_late > 0
            @tp_info "Consumer drops" consumer_id = cid drops_gap = info.drops_gap drops_late = info.drops_late
        end
    end
    return true
end

"""
Emit a ConsumerConfig message to a consumer.

Arguments:
- `state`: supervisor state.
- `consumer_id`: consumer identifier.
- `mode`: consumer mode enum.
- `fallback_uri`: payload fallback URI (default: "").

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_consumer_config!(
    state::SupervisorState,
    consumer_id::UInt32;
    use_shm::Bool = true,
    mode::Mode.SbeEnum = Mode.STREAM,
    payload_fallback_uri::String = "",
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
        sizeof(payload_fallback_uri) + sizeof(descriptor_channel) + sizeof(control_channel)

    sent = let st = state,
        consumer_id = consumer_id,
        use_shm = use_shm,
        mode = mode,
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
            ConsumerConfigMsg.descriptorStreamId!(
                st.runtime.config_encoder,
                descriptor_stream_id != 0 ? descriptor_stream_id : UInt32(0),
            )
            ConsumerConfigMsg.controlStreamId!(
                st.runtime.config_encoder,
                control_stream_id != 0 ? control_stream_id : UInt32(0),
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

    sent || return false
    state.tracking.config_count += 1
    return true
end
