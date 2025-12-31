"""
Initialize a supervisor: create Aeron resources and timers.
"""
function init_supervisor(config::SupervisorConfig)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.aeron_dir)
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
        ctx,
        client,
        pub_control,
        sub_control,
        sub_qos,
        Dict{UInt32, ProducerInfo}(),
        Dict{UInt32, ConsumerInfo}(),
        UInt64(0),
        UInt64(0),
        timer_set,
        Vector{UInt8}(undef, 512),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
end

"""
Handle ShmPoolAnnounce messages and update producer tracking.
"""
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

"""
Handle QosProducer updates.
"""
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

"""
Handle ConsumerHello messages and update consumer tracking.
"""
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

"""
Handle QosConsumer updates.
"""
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

"""
Check liveness and return true if any action was taken.
"""
function check_liveness!(state::SupervisorState, now_ns::UInt64)
    state.liveness_count += 1
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

"""
Emit a ConsumerConfig message for a specific consumer.
"""
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

    sent = try_claim_sbe!(state.pub_control, state.config_claim, msg_len) do buf
        ConsumerConfigMsg.wrap_and_apply_header!(state.config_encoder, buf, 0)
        ConsumerConfigMsg.streamId!(state.config_encoder, state.config.stream_id)
        ConsumerConfigMsg.consumerId!(state.config_encoder, consumer_id)
        ConsumerConfigMsg.useShm!(
            state.config_encoder,
            use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerConfigMsg.mode!(state.config_encoder, mode)
        ConsumerConfigMsg.decimation!(state.config_encoder, decimation)
        ConsumerConfigMsg.payloadFallbackUri!(state.config_encoder, payload_fallback_uri)
    end

    if sent
        state.config_count += 1
        return true
    end

    ConsumerConfigMsg.wrap_and_apply_header!(state.config_encoder, unsafe_array_view(state.config_buf), 0)
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
    state.config_count += 1
    return true
end
