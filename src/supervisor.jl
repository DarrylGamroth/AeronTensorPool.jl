struct ProducerInfo
    stream_id::UInt32
    epoch::UInt64
    last_announce_ns::UInt64
    last_qos_ns::UInt64
    current_seq::UInt64
end

struct ConsumerInfo
    stream_id::UInt32
    consumer_id::UInt32
    epoch::UInt64
    mode::Mode.SbeEnum
    last_hello_ns::UInt64
    last_qos_ns::UInt64
    last_seq_seen::UInt64
    drops_gap::UInt64
    drops_late::UInt64
end

mutable struct SupervisorConfig
    aeron_dir::String
    aeron_uri::String
    control_stream_id::Int32
    qos_stream_id::Int32
    stream_id::UInt32
    liveness_timeout_ns::UInt64
    liveness_check_interval_ns::UInt64
end

struct SupervisorLivenessHandler end

mutable struct SupervisorState
    config::SupervisorConfig
    clock::Clocks.AbstractClock
    client::Aeron.Client
    pub_control::Aeron.Publication
    sub_control::Aeron.Subscription
    sub_qos::Aeron.Subscription
    producers::Dict{UInt32, ProducerInfo}
    consumers::Dict{UInt32, ConsumerInfo}
    timer_set::TimerSet{Tuple{PolledTimer}, Tuple{SupervisorLivenessHandler}}
    config_buf::Vector{UInt8}
    config_encoder::ConsumerConfigMsg.Encoder{Vector{UInt8}}
    config_claim::Aeron.BufferClaim
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    hello_decoder::ConsumerHello.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_producer_decoder::QosProducer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_consumer_decoder::QosConsumer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

function init_supervisor(config::SupervisorConfig)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(config.liveness_check_interval_ns),),
        (SupervisorLivenessHandler(),),
    )

    return SupervisorState(
        config,
        clock,
        client,
        pub_control,
        sub_control,
        sub_qos,
        Dict{UInt32, ProducerInfo}(),
        Dict{UInt32, ConsumerInfo}(),
        timer_set,
        Vector{UInt8}(undef, 512),
        ConsumerConfigMsg.Encoder(Vector{UInt8}),
        Aeron.BufferClaim(),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
end

function handle_shm_pool_announce!(state::SupervisorState, msg::ShmPoolAnnounce.Decoder)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    pid = ShmPoolAnnounce.producerId(msg)
    ep = ShmPoolAnnounce.epoch(msg)
    info = get(state.producers, pid, nothing)
    last_qos = isnothing(info) ? UInt64(0) : info.last_qos_ns
    current_seq = isnothing(info) ? UInt64(0) : info.current_seq

    state.producers[pid] = ProducerInfo(
        ShmPoolAnnounce.streamId(msg),
        ep,
        now_ns,
        last_qos,
        current_seq,
    )
    return nothing
end

function handle_qos_producer!(state::SupervisorState, msg::QosProducer.Decoder)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    pid = QosProducer.producerId(msg)
    info = get(state.producers, pid, nothing)
    if isnothing(info)
        state.producers[pid] = ProducerInfo(
            QosProducer.streamId(msg),
            QosProducer.epoch(msg),
            UInt64(0),
            now_ns,
            QosProducer.currentSeq(msg),
        )
    else
        state.producers[pid] = ProducerInfo(
            info.stream_id,
            QosProducer.epoch(msg),
            info.last_announce_ns,
            now_ns,
            QosProducer.currentSeq(msg),
        )
    end
    return nothing
end

function handle_consumer_hello!(state::SupervisorState, msg::ConsumerHello.Decoder)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    cid = ConsumerHello.consumerId(msg)
    info = get(state.consumers, cid, nothing)
    last_qos = isnothing(info) ? UInt64(0) : info.last_qos_ns
    last_seq = isnothing(info) ? UInt64(0) : info.last_seq_seen
    drops_gap = isnothing(info) ? UInt64(0) : info.drops_gap
    drops_late = isnothing(info) ? UInt64(0) : info.drops_late

    state.consumers[cid] = ConsumerInfo(
        ConsumerHello.streamId(msg),
        cid,
        UInt64(0),
        ConsumerHello.mode(msg),
        now_ns,
        last_qos,
        last_seq,
        drops_gap,
        drops_late,
    )
    return nothing
end

function handle_qos_consumer!(state::SupervisorState, msg::QosConsumer.Decoder)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))

    cid = QosConsumer.consumerId(msg)
    info = get(state.consumers, cid, nothing)
    if isnothing(info)
        state.consumers[cid] = ConsumerInfo(
            QosConsumer.streamId(msg),
            cid,
            QosConsumer.epoch(msg),
            QosConsumer.mode(msg),
            UInt64(0),
            now_ns,
            QosConsumer.lastSeqSeen(msg),
            QosConsumer.dropsGap(msg),
            QosConsumer.dropsLate(msg),
        )
    else
        state.consumers[cid] = ConsumerInfo(
            info.stream_id,
            cid,
            QosConsumer.epoch(msg),
            info.mode,
            info.last_hello_ns,
            now_ns,
            QosConsumer.lastSeqSeen(msg),
            QosConsumer.dropsGap(msg),
            QosConsumer.dropsLate(msg),
        )
    end
    return nothing
end

function check_liveness!(state::SupervisorState, now_ns::UInt64)
    timeout = state.config.liveness_timeout_ns
    for (pid, info) in state.producers
        last_seen = max(info.last_announce_ns, info.last_qos_ns)
        if last_seen > 0 && now_ns - last_seen > timeout
            @warn "Producer stale" producer_id = pid epoch = info.epoch
        end
    end
    for (cid, info) in state.consumers
        last_seen = max(info.last_qos_ns, info.last_hello_ns)
        if last_seen > 0 && now_ns - last_seen > timeout
            @warn "Consumer stale" consumer_id = cid epoch = info.epoch
        end
        if info.drops_gap > 0 || info.drops_late > 0
            @info "Consumer drops" consumer_id = cid drops_gap = info.drops_gap drops_late = info.drops_late
        end
    end
    return true
end

@inline function (handler::SupervisorLivenessHandler)(state::SupervisorState, now_ns::UInt64)
    return check_liveness!(state, now_ns) ? 1 : 0
end

function poll_timers!(state::SupervisorState, now_ns::UInt64)
    return poll_timers!(state.timer_set, state, now_ns)
end

function emit_consumer_config!(
    state::SupervisorState,
    consumer_id::UInt32;
    use_shm::Bool = true,
    mode::Mode.SbeEnum = Mode.STREAM,
    decimation::UInt16 = UInt16(1),
    payload_fallback_uri::String = "",
)
    payload_len = sizeof(payload_fallback_uri)
    msg_len = MESSAGE_HEADER_LEN +
        Int(ConsumerConfigMsg.sbe_block_length(ConsumerConfigMsg.Decoder)) +
        Int(ConsumerConfigMsg.payloadFallbackUri_header_length) +
        payload_len

    sent = try_claim_sbe!(
        state.pub_control,
        state.config_claim,
        msg_len,
        buf -> begin
            buf_view = unsafe_wrap(Vector{UInt8}, pointer(buf), length(buf))
            ConsumerConfigMsg.wrap_and_apply_header!(state.config_encoder, buf_view, 0)
            ConsumerConfigMsg.streamId!(state.config_encoder, state.config.stream_id)
            ConsumerConfigMsg.consumerId!(state.config_encoder, consumer_id)
            ConsumerConfigMsg.useShm!(
                state.config_encoder,
                use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerConfigMsg.mode!(state.config_encoder, mode)
            ConsumerConfigMsg.decimation!(state.config_encoder, decimation)
            ConsumerConfigMsg.payloadFallbackUri!(state.config_encoder, payload_fallback_uri)
        end,
    )

    if sent
        return true
    end

    ConsumerConfigMsg.wrap_and_apply_header!(state.config_encoder, state.config_buf, 0)
    ConsumerConfigMsg.streamId!(state.config_encoder, state.config.stream_id)
    ConsumerConfigMsg.consumerId!(state.config_encoder, consumer_id)
    ConsumerConfigMsg.useShm!(
        state.config_encoder,
        use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
    )
    ConsumerConfigMsg.mode!(state.config_encoder, mode)
    ConsumerConfigMsg.decimation!(state.config_encoder, decimation)
    ConsumerConfigMsg.payloadFallbackUri!(state.config_encoder, payload_fallback_uri)

    Aeron.offer(
        state.pub_control,
        view(state.config_buf, 1:sbe_message_length(state.config_encoder)),
    )
    return true
end

function make_control_assembler(state::SupervisorState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.announce_decoder, buffer, 0; header = header)
            handle_shm_pool_announce!(st, st.announce_decoder)
        elseif template_id == TEMPLATE_CONSUMER_HELLO
            ConsumerHello.wrap!(st.hello_decoder, buffer, 0; header = header)
            handle_consumer_hello!(st, st.hello_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

function make_qos_assembler(state::SupervisorState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_QOS_PRODUCER
            QosProducer.wrap!(st.qos_producer_decoder, buffer, 0; header = header)
            handle_qos_producer!(st, st.qos_producer_decoder)
        elseif template_id == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.qos_consumer_decoder, buffer, 0; header = header)
            handle_qos_consumer!(st, st.qos_consumer_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

@inline function poll_control!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.sub_control, assembler, fragment_limit)
end

@inline function poll_qos!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.sub_qos, assembler, fragment_limit)
end

function supervisor_step!(
    state::SupervisorState,
    control_assembler::Aeron.FragmentAssembler,
    qos_assembler::Aeron.FragmentAssembler;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    work_count = 0
    work_count += poll_control!(state, control_assembler, fragment_limit)
    work_count += poll_qos!(state, qos_assembler, fragment_limit)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count += poll_timers!(state, now_ns)
    return work_count
end
