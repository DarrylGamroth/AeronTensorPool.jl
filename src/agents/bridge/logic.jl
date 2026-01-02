"""
Compute the effective bridge chunk size in bytes.
"""
@inline function bridge_effective_chunk_bytes(config::BridgeConfig)
    mtu = Int(config.mtu_bytes)
    max_chunk = Int(config.max_chunk_bytes)
    chunk = Int(config.chunk_bytes)

    base = mtu > 0 ? max(mtu - 128, 0) : 0
    if chunk > 0
        base = base == 0 ? chunk : min(chunk, base)
    elseif base == 0
        base = max_chunk
    end
    if max_chunk > 0
        base = min(base, max_chunk)
    end
    return base
end

"""
Return total byte length for a BridgeFrameChunk message.
"""
@inline function bridge_chunk_message_length(header_len::Int, payload_len::Int)
    block_len = Int(BridgeFrameChunk.sbe_block_length(BridgeFrameChunk.Encoder))
    return BRIDGE_MESSAGE_HEADER_LEN + block_len + 4 + header_len + 4 + payload_len
end

"""
Return var-data positions for header/payload bytes in a BridgeFrameChunk decoder.
"""
@inline function bridge_chunk_var_data_positions(decoder::BridgeFrameChunk.Decoder)
    buf = BridgeFrameChunk.sbe_buffer(decoder)
    pos = BridgeFrameChunk.sbe_position(decoder)
    header_len = Int(SBE.decode_value_le(UInt32, buf, pos))
    header_pos = pos + 4
    payload_len_pos = header_pos + header_len
    payload_len = Int(SBE.decode_value_le(UInt32, buf, payload_len_pos))
    payload_pos = payload_len_pos + 4
    return header_len, header_pos, payload_len, payload_pos
end

"""
Reset assembly state for a new frame.
"""
@inline function reset_bridge_assembly!(
    assembly::BridgeAssembly,
    seq::UInt64,
    epoch::UInt64,
    chunk_count::UInt32,
    payload_length::UInt32,
    now_ns::UInt64,
)
    assembly.seq = seq
    assembly.epoch = epoch
    assembly.chunk_count = chunk_count
    assembly.payload_length = payload_length
    assembly.received_chunks = 0
    assembly.header_present = false
    assembly.last_update_ns = now_ns
    fill!(assembly.received, false)
    return nothing
end

"""
Initialize a bridge sender using an existing consumer mapping.
"""
function init_bridge_sender(
    consumer_state::ConsumerState,
    config::BridgeConfig,
    mapping::BridgeMapping;
    aeron_ctx::Union{Nothing, Aeron.Context} = nothing,
    aeron_client::Union{Nothing, Aeron.Client} = nothing,
)
    if (config.forward_progress || config.forward_qos) &&
       (mapping.source_control_stream_id == 0 || mapping.dest_control_stream_id == 0)
        throw(ArgumentError("bridge mapping requires nonzero control stream IDs for progress/QoS forwarding"))
    end
    ctx, client, owns_ctx, owns_client = acquire_aeron(
        config.aeron_dir;
        ctx = aeron_ctx,
        client = aeron_client,
    )

    pub_payload = Aeron.add_publication(client, config.payload_channel, config.payload_stream_id)
    pub_control = Aeron.add_publication(client, config.control_channel, config.control_stream_id)
    source_control = mapping.source_control_stream_id == 0 ? consumer_state.config.control_stream_id :
        mapping.source_control_stream_id
    sub_control = Aeron.add_subscription(client, consumer_state.config.aeron_uri, source_control)
    pub_metadata = nothing
    sub_metadata = nothing
    metadata_assembler = nothing
    if config.forward_metadata && !isempty(config.metadata_channel)
        pub_metadata = Aeron.add_publication(client, config.metadata_channel, config.metadata_stream_id)
        sub_metadata = Aeron.add_subscription(client, consumer_state.config.aeron_uri, config.source_metadata_stream_id)
    end
    state = BridgeSenderState(
        consumer_state,
        config,
        mapping,
        ctx,
        client,
        owns_ctx,
        owns_client,
        pub_payload,
        pub_control,
        pub_metadata,
        BridgeFrameChunk.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeader256.Decoder(Vector{UInt8}),
        Vector{UInt8}(undef, HEADER_SLOT_BYTES),
        Vector{Int32}(undef, MAX_DIMS),
        Vector{Int32}(undef, MAX_DIMS),
        UInt64(0),
        sub_control,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        sub_metadata,
        metadata_assembler,
        DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
    if sub_metadata !== nothing
        state.metadata_assembler = make_bridge_metadata_sender_assembler(state)
    end
    state.control_assembler = make_bridge_control_sender_assembler(state)
    return state
end

"""
Initialize a bridge receiver for a single mapping.
"""
function init_bridge_receiver(
    config::BridgeConfig,
    mapping::BridgeMapping;
    producer_state::Union{Nothing, ProducerState} = nothing,
    aeron_ctx::Union{Nothing, Aeron.Context} = nothing,
    aeron_client::Union{Nothing, Aeron.Client} = nothing,
)
    if (config.forward_progress || config.forward_qos) &&
       (mapping.source_control_stream_id == 0 || mapping.dest_control_stream_id == 0)
        throw(ArgumentError("bridge mapping requires nonzero control stream IDs for progress/QoS forwarding"))
    end
    ctx, client, owns_ctx, owns_client = acquire_aeron(
        config.aeron_dir;
        ctx = aeron_ctx,
        client = aeron_client,
    )
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    sub_payload = Aeron.add_subscription(client, config.payload_channel, config.payload_stream_id)
    sub_control = Aeron.add_subscription(client, config.control_channel, config.control_stream_id)

    chunk_bytes = bridge_effective_chunk_bytes(config)
    max_payload = Int(config.max_payload_bytes)
    max_chunk = max(chunk_bytes, 1)
    max_chunks = max_payload == 0 ? 0 : cld(max_payload, max_chunk)

    assembly = BridgeAssembly(
        UInt64(0),
        UInt64(0),
        UInt32(0),
        UInt32(0),
        UInt32(0),
        false,
        Vector{UInt8}(undef, HEADER_SLOT_BYTES),
        Vector{UInt8}(undef, max_payload),
        fill(false, max_chunks),
        UInt64(0),
    )

    source_info = BridgeSourceInfo(UInt32(0), UInt64(0), UInt32(0), UInt8(0), Dict{UInt16, UInt32}())

    dest_metadata_stream_id =
        mapping.metadata_stream_id == 0 ? Int32(mapping.dest_stream_id) : Int32(mapping.metadata_stream_id)
    pub_metadata_local = nothing
    sub_metadata = nothing
    metadata_assembler = nothing
    if config.forward_metadata && !isempty(config.metadata_channel)
        sub_metadata = Aeron.add_subscription(client, config.metadata_channel, config.metadata_stream_id)
        pub_metadata_local = Aeron.add_publication(client, "aeron:ipc", dest_metadata_stream_id)
    end
    pub_control_local = nothing
    if (config.forward_qos || config.forward_progress) && mapping.dest_control_stream_id != 0
        pub_control_local = Aeron.add_publication(client, "aeron:ipc", mapping.dest_control_stream_id)
    end

    state = BridgeReceiverState(
        config,
        mapping,
        ctx,
        client,
        owns_ctx,
        owns_client,
        clock,
        UInt64(0),
        producer_state,
        sub_payload,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        sub_control,
        Aeron.FragmentAssembler(Aeron.FragmentHandler((_, _, _) -> nothing)),
        sub_metadata,
        metadata_assembler,
        pub_metadata_local,
        Aeron.BufferClaim(),
        DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        pub_control_local,
        Aeron.BufferClaim(),
        QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        BridgeFrameChunk.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeader256.Decoder(Vector{UInt8}),
        Vector{Int32}(undef, MAX_DIMS),
        Vector{Int32}(undef, MAX_DIMS),
        source_info,
        assembly,
        false,
    )

    state.payload_assembler = make_bridge_payload_assembler(state)
    state.control_assembler = make_bridge_control_assembler(state)
    if sub_metadata !== nothing
        state.metadata_assembler = make_bridge_metadata_receiver_assembler(state)
    end
    return state
end

"""
Forward a ShmPoolAnnounce on the bridge control channel.
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
        try_claim_sbe!(st.pub_control, st.control_claim, msg_len) do buf
            enc = st.announce_encoder
            ShmPoolAnnounce.wrap_and_apply_header!(enc, buf, 0)
            ShmPoolAnnounce.streamId!(enc, ShmPoolAnnounce.streamId(msg))
            ShmPoolAnnounce.producerId!(enc, ShmPoolAnnounce.producerId(msg))
            ShmPoolAnnounce.epoch!(enc, ShmPoolAnnounce.epoch(msg))
            ShmPoolAnnounce.layoutVersion!(enc, ShmPoolAnnounce.layoutVersion(msg))
            ShmPoolAnnounce.headerNslots!(enc, ShmPoolAnnounce.headerNslots(msg))
            ShmPoolAnnounce.headerSlotBytes!(enc, ShmPoolAnnounce.headerSlotBytes(msg))
            ShmPoolAnnounce.maxDims!(enc, ShmPoolAnnounce.maxDims(msg))

            group = ShmPoolAnnounce.payloadPools!(enc, payload_count)
            for pool in payloads
                entry = ShmPoolAnnounce.PayloadPools.next!(group)
                ShmPoolAnnounce.PayloadPools.poolId!(entry, ShmPoolAnnounce.PayloadPools.poolId(pool))
                ShmPoolAnnounce.PayloadPools.poolNslots!(entry, ShmPoolAnnounce.PayloadPools.poolNslots(pool))
                ShmPoolAnnounce.PayloadPools.strideBytes!(entry, ShmPoolAnnounce.PayloadPools.strideBytes(pool))
                ShmPoolAnnounce.PayloadPools.regionUri!(entry, String(ShmPoolAnnounce.PayloadPools.regionUri(pool)))
            end
            ShmPoolAnnounce.headerRegionUri!(enc, String(ShmPoolAnnounce.headerRegionUri(msg)))
        end
    end
    sent || return false
    state.last_announce_epoch = ShmPoolAnnounce.epoch(msg)
    return true
end

"""
Forward a DataSourceAnnounce from source to bridge metadata channel.
"""
function bridge_forward_metadata_announce!(state::BridgeSenderState, msg::DataSourceAnnounce.Decoder)
    state.config.forward_metadata || return false
    state.pub_metadata === nothing && return false
    DataSourceAnnounce.streamId(msg) == state.mapping.source_stream_id || return false

    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceAnnounce.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg
        try_claim_sbe!(st.pub_metadata, st.metadata_claim, msg_len) do buf
            enc = st.metadata_announce_encoder
            DataSourceAnnounce.wrap_and_apply_header!(enc, buf, 0)
            DataSourceAnnounce.streamId!(enc, DataSourceAnnounce.streamId(msg))
            DataSourceAnnounce.producerId!(enc, DataSourceAnnounce.producerId(msg))
            DataSourceAnnounce.epoch!(enc, DataSourceAnnounce.epoch(msg))
            DataSourceAnnounce.metaVersion!(enc, DataSourceAnnounce.metaVersion(msg))
            name_view = DataSourceAnnounce.name(msg)
            summary_view = DataSourceAnnounce.summary(msg)
            if !isempty(name_view)
                DataSourceAnnounce.name!(enc, name_view)
            end
            if !isempty(summary_view)
                DataSourceAnnounce.summary!(enc, summary_view)
            end
        end
    end
    return sent
end

"""
Forward a DataSourceMeta from source to bridge metadata channel.
"""
function bridge_forward_metadata_meta!(state::BridgeSenderState, msg::DataSourceMeta.Decoder)
    state.config.forward_metadata || return false
    state.pub_metadata === nothing && return false
    DataSourceMeta.streamId(msg) == state.mapping.source_stream_id || return false

    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceMeta.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg
        try_claim_sbe!(st.pub_metadata, st.metadata_claim, msg_len) do buf
            enc = st.metadata_meta_encoder
            DataSourceMeta.wrap_and_apply_header!(enc, buf, 0)
            DataSourceMeta.streamId!(enc, DataSourceMeta.streamId(msg))
            DataSourceMeta.metaVersion!(enc, DataSourceMeta.metaVersion(msg))
            DataSourceMeta.timestampNs!(enc, DataSourceMeta.timestampNs(msg))

            attrs = DataSourceMeta.attributes(msg)
            group = DataSourceMeta.attributes!(enc, length(attrs))
            for attr in attrs
                entry = DataSourceMeta.Attributes.next!(group)
                DataSourceMeta.Attributes.key!(entry, DataSourceMeta.Attributes.key(attr))
                DataSourceMeta.Attributes.format!(entry, DataSourceMeta.Attributes.format(attr))
                DataSourceMeta.Attributes.value!(entry, DataSourceMeta.Attributes.value(attr))
            end
        end
    end
    return sent
end

"""
Publish a forwarded DataSourceAnnounce on the local metadata stream.
"""
function bridge_publish_metadata_announce!(state::BridgeReceiverState, msg::DataSourceAnnounce.Decoder)
    state.config.forward_metadata || return false
    state.pub_metadata_local === nothing && return false
    DataSourceAnnounce.streamId(msg) == state.mapping.source_stream_id || return false

    dest_stream_id =
        state.mapping.metadata_stream_id == 0 ? UInt32(state.mapping.dest_stream_id) : state.mapping.metadata_stream_id
    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceAnnounce.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg,
        dest_stream_id = dest_stream_id
        try_claim_sbe!(st.pub_metadata_local, st.metadata_claim, msg_len) do buf
            enc = st.metadata_announce_encoder
            DataSourceAnnounce.wrap_and_apply_header!(enc, buf, 0)
            DataSourceAnnounce.streamId!(enc, dest_stream_id)
            DataSourceAnnounce.producerId!(enc, DataSourceAnnounce.producerId(msg))
            DataSourceAnnounce.epoch!(enc, DataSourceAnnounce.epoch(msg))
            DataSourceAnnounce.metaVersion!(enc, DataSourceAnnounce.metaVersion(msg))
            name_view = DataSourceAnnounce.name(msg)
            summary_view = DataSourceAnnounce.summary(msg)
            if !isempty(name_view)
                DataSourceAnnounce.name!(enc, name_view)
            end
            if !isempty(summary_view)
                DataSourceAnnounce.summary!(enc, summary_view)
            end
        end
    end
    return sent
end

"""
Publish a forwarded DataSourceMeta on the local metadata stream.
"""
function bridge_publish_metadata_meta!(state::BridgeReceiverState, msg::DataSourceMeta.Decoder)
    state.config.forward_metadata || return false
    state.pub_metadata_local === nothing && return false
    DataSourceMeta.streamId(msg) == state.mapping.source_stream_id || return false

    dest_stream_id =
        state.mapping.metadata_stream_id == 0 ? UInt32(state.mapping.dest_stream_id) : state.mapping.metadata_stream_id
    msg_len = MESSAGE_HEADER_LEN + Int(DataSourceMeta.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg,
        dest_stream_id = dest_stream_id
        try_claim_sbe!(st.pub_metadata_local, st.metadata_claim, msg_len) do buf
            enc = st.metadata_meta_encoder
            DataSourceMeta.wrap_and_apply_header!(enc, buf, 0)
            DataSourceMeta.streamId!(enc, dest_stream_id)
            DataSourceMeta.metaVersion!(enc, DataSourceMeta.metaVersion(msg))
            DataSourceMeta.timestampNs!(enc, DataSourceMeta.timestampNs(msg))

            attrs = DataSourceMeta.attributes(msg)
            group = DataSourceMeta.attributes!(enc, length(attrs))
            for attr in attrs
                entry = DataSourceMeta.Attributes.next!(group)
                DataSourceMeta.Attributes.key!(entry, DataSourceMeta.Attributes.key(attr))
                DataSourceMeta.Attributes.format!(entry, DataSourceMeta.Attributes.format(attr))
                DataSourceMeta.Attributes.value!(entry, DataSourceMeta.Attributes.value(attr))
            end
        end
    end
    return sent
end

"""
Forward a QosProducer from source to bridge control channel.
"""
function bridge_forward_qos_producer!(state::BridgeSenderState, msg::QosProducer.Decoder)
    state.config.forward_qos || return false
    QosProducer.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg
        try_claim_sbe!(st.pub_control, st.control_claim, msg_len) do buf
            enc = st.qos_producer_encoder
            QosProducer.wrap_and_apply_header!(enc, buf, 0)
            QosProducer.streamId!(enc, QosProducer.streamId(msg))
            QosProducer.producerId!(enc, QosProducer.producerId(msg))
            QosProducer.epoch!(enc, QosProducer.epoch(msg))
            QosProducer.currentSeq!(enc, QosProducer.currentSeq(msg))
        end
    end
    return sent
end

"""
Forward a QosConsumer from source to bridge control channel.
"""
function bridge_forward_qos_consumer!(state::BridgeSenderState, msg::QosConsumer.Decoder)
    state.config.forward_qos || return false
    QosConsumer.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg
        try_claim_sbe!(st.pub_control, st.control_claim, msg_len) do buf
            enc = st.qos_consumer_encoder
            QosConsumer.wrap_and_apply_header!(enc, buf, 0)
            QosConsumer.streamId!(enc, QosConsumer.streamId(msg))
            QosConsumer.consumerId!(enc, QosConsumer.consumerId(msg))
            QosConsumer.epoch!(enc, QosConsumer.epoch(msg))
            QosConsumer.lastSeqSeen!(enc, QosConsumer.lastSeqSeen(msg))
            QosConsumer.dropsGap!(enc, QosConsumer.dropsGap(msg))
            QosConsumer.dropsLate!(enc, QosConsumer.dropsLate(msg))
            QosConsumer.mode!(enc, QosConsumer.mode(msg))
        end
    end
    return sent
end

"""
Forward a FrameProgress from source to bridge control channel.
"""
function bridge_forward_progress!(state::BridgeSenderState, msg::FrameProgress.Decoder)
    state.config.forward_progress || return false
    FrameProgress.streamId(msg) == state.mapping.source_stream_id || return false
    msg_len = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg
        try_claim_sbe!(st.pub_control, st.control_claim, msg_len) do buf
            enc = st.progress_encoder
            FrameProgress.wrap_and_apply_header!(enc, buf, 0)
            FrameProgress.streamId!(enc, FrameProgress.streamId(msg))
            FrameProgress.epoch!(enc, FrameProgress.epoch(msg))
            FrameProgress.frameId!(enc, FrameProgress.frameId(msg))
            FrameProgress.headerIndex!(enc, FrameProgress.headerIndex(msg))
            FrameProgress.payloadBytesFilled!(enc, FrameProgress.payloadBytesFilled(msg))
            FrameProgress.state!(enc, FrameProgress.state(msg))
            FrameProgress.rowsFilled!(enc, FrameProgress.rowsFilled(msg))
        end
    end
    return sent
end

"""
Publish a forwarded QosProducer on the local QoS stream.
"""
function bridge_publish_qos_producer!(state::BridgeReceiverState, msg::QosProducer.Decoder)
    state.config.forward_qos || return false
    state.pub_control_local === nothing && return false
    QosProducer.streamId(msg) == state.mapping.source_stream_id || return false

    msg_len = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg
        try_claim_sbe!(st.pub_control_local, st.control_claim, msg_len) do buf
            enc = st.qos_producer_encoder
            QosProducer.wrap_and_apply_header!(enc, buf, 0)
            QosProducer.streamId!(enc, UInt32(st.mapping.dest_stream_id))
            QosProducer.producerId!(enc, QosProducer.producerId(msg))
            QosProducer.epoch!(enc, QosProducer.epoch(msg))
            QosProducer.currentSeq!(enc, QosProducer.currentSeq(msg))
        end
    end
    return sent
end

"""
Publish a forwarded QosConsumer on the local QoS stream.
"""
function bridge_publish_qos_consumer!(state::BridgeReceiverState, msg::QosConsumer.Decoder)
    state.config.forward_qos || return false
    state.pub_control_local === nothing && return false
    QosConsumer.streamId(msg) == state.mapping.source_stream_id || return false

    msg_len = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg
        try_claim_sbe!(st.pub_control_local, st.control_claim, msg_len) do buf
            enc = st.qos_consumer_encoder
            QosConsumer.wrap_and_apply_header!(enc, buf, 0)
            QosConsumer.streamId!(enc, UInt32(st.mapping.dest_stream_id))
            QosConsumer.consumerId!(enc, QosConsumer.consumerId(msg))
            QosConsumer.epoch!(enc, QosConsumer.epoch(msg))
            QosConsumer.lastSeqSeen!(enc, QosConsumer.lastSeqSeen(msg))
            QosConsumer.dropsGap!(enc, QosConsumer.dropsGap(msg))
            QosConsumer.dropsLate!(enc, QosConsumer.dropsLate(msg))
            QosConsumer.mode!(enc, QosConsumer.mode(msg))
        end
    end
    return sent
end

"""
Publish a forwarded FrameProgress on the local control stream.
"""
function bridge_publish_progress!(state::BridgeReceiverState, msg::FrameProgress.Decoder)
    state.config.forward_progress || return false
    state.pub_control_local === nothing && return false
    FrameProgress.streamId(msg) == state.mapping.source_stream_id || return false
    state.producer_state === nothing && return false

    nslots = state.producer_state.config.nslots
    nslots == 0 && return false
    seq = FrameProgress.frameId(msg)
    header_index = UInt32(seq & (UInt64(nslots) - 1))

    msg_len = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_decoded_length(msg))
    sent = let st = state,
        msg = msg,
        seq = seq,
        header_index = header_index
        try_claim_sbe!(st.pub_control_local, st.control_claim, msg_len) do buf
            enc = st.progress_encoder
            FrameProgress.wrap_and_apply_header!(enc, buf, 0)
            FrameProgress.streamId!(enc, UInt32(st.mapping.dest_stream_id))
            FrameProgress.epoch!(enc, FrameProgress.epoch(msg))
            FrameProgress.frameId!(enc, seq)
            FrameProgress.headerIndex!(enc, header_index)
            FrameProgress.payloadBytesFilled!(enc, FrameProgress.payloadBytesFilled(msg))
            FrameProgress.state!(enc, FrameProgress.state(msg))
            FrameProgress.rowsFilled!(enc, FrameProgress.rowsFilled(msg))
        end
    end
    return sent
end

"""
Rematerialize an assembled bridge frame into local SHM and publish a descriptor.
"""
function bridge_rematerialize!(
    state::BridgeReceiverState,
    producer_state::ProducerState,
    frame::BridgeAssembledFrame,
)
    producer_driver_active(producer_state) || return false
    frame.payload_length <= UInt32(length(frame.payload)) || return false

    wrap_tensor_header!(state.header_decoder, frame.header_bytes, 0)
    frame_id = TensorSlotHeader256.frameId(state.header_decoder)
    frame_id == frame.seq || return false

    payload_len = Int(frame.payload_length)
    pool_idx = select_pool(producer_state.config.payload_pools, payload_len)
    pool_idx == 0 && return false
    pool = producer_state.config.payload_pools[pool_idx]
    payload_slot = UInt32(frame.seq & (UInt64(producer_state.config.nslots) - 1))
    payload_slot < pool.nslots || return false

    header_index = payload_slot
    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(producer_state.mappings.header_mmap, header_offset)
    seqlock_begin_write!(commit_ptr, frame_id)

    payload_mmap = producer_state.mappings.payload_mmaps[pool.pool_id]
    payload_offset = payload_slot_offset(pool.stride_bytes, payload_slot)
    copyto!(payload_mmap, payload_offset + 1, frame.payload, 1, payload_len)

    dims_tuple = TensorSlotHeader256.dims(state.header_decoder, NTuple{MAX_DIMS, Int32})
    strides_tuple = TensorSlotHeader256.strides(state.header_decoder, NTuple{MAX_DIMS, Int32})
    @inbounds for i in 1:MAX_DIMS
        state.scratch_dims[i] = dims_tuple[i]
        state.scratch_strides[i] = strides_tuple[i]
    end

    wrap_tensor_header!(producer_state.runtime.header_encoder, producer_state.mappings.header_mmap, header_offset)
    write_tensor_slot_header!(
        producer_state.runtime.header_encoder,
        frame_id,
        TensorSlotHeader256.timestampNs(state.header_decoder),
        TensorSlotHeader256.metaVersion(state.header_decoder),
        UInt32(payload_len),
        payload_slot,
        UInt32(0),
        pool.pool_id,
        TensorSlotHeader256.dtype(state.header_decoder),
        TensorSlotHeader256.majorOrder(state.header_decoder),
        TensorSlotHeader256.ndims(state.header_decoder),
        state.scratch_dims,
        state.scratch_strides,
    )

    seqlock_commit_write!(commit_ptr, frame_id)

    now_ns = UInt64(Clocks.time_nanos(producer_state.clock))
    sent = let st = state,
        producer_state = producer_state,
        frame = frame,
        header_index = header_index,
        now_ns = now_ns
        try_claim_sbe!(
            producer_state.runtime.pub_descriptor,
            producer_state.runtime.descriptor_claim,
            FRAME_DESCRIPTOR_LEN,
        ) do buf
            FrameDescriptor.wrap_and_apply_header!(producer_state.runtime.descriptor_encoder, buf, 0)
            encode_frame_descriptor!(
                producer_state.runtime.descriptor_encoder,
                producer_state,
                frame.seq,
                header_index,
                TensorSlotHeader256.metaVersion(st.header_decoder),
                now_ns,
            )
        end
    end
    sent || return false

    if producer_state.supports_progress && should_emit_progress!(producer_state, UInt64(payload_len), true)
        emit_progress_complete!(producer_state, frame_id, header_index, UInt64(payload_len))
    end

    if frame.seq >= producer_state.seq
        producer_state.seq = frame.seq + 1
    end
    return true
end

"""
Publish BridgeFrameChunk messages for the descriptor's frame.
"""
function bridge_send_frame!(state::BridgeSenderState, desc::FrameDescriptor.Decoder)
    consumer_driver_active(state.consumer_state) || return false
    state.consumer_state.mappings.header_mmap === nothing && return false
    FrameDescriptor.epoch(desc) == state.consumer_state.mappings.mapped_epoch || return false
    FrameDescriptor.streamId(desc) == state.mapping.source_stream_id || return false

    header_index = FrameDescriptor.headerIndex(desc)
    header_mmap = state.consumer_state.mappings.header_mmap::Vector{UInt8}
    if state.consumer_state.mappings.mapped_nslots == 0 ||
       header_index >= state.consumer_state.mappings.mapped_nslots
        return false
    end

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
    first = seqlock_read_begin(commit_ptr)
    seqlock_is_write_in_progress(first) && return false

    copyto!(state.header_buf, 1, header_mmap, header_offset + 1, HEADER_SLOT_BYTES)
    wrap_tensor_header!(state.header_decoder, header_mmap, header_offset)

    frame_id = TensorSlotHeader256.frameId(state.header_decoder)
    payload_len = Int(TensorSlotHeader256.valuesLenBytes(state.header_decoder))
    payload_slot = TensorSlotHeader256.payloadSlot(state.header_decoder)
    payload_offset = TensorSlotHeader256.payloadOffset(state.header_decoder)
    pool_id = TensorSlotHeader256.poolId(state.header_decoder)

    if frame_id != FrameDescriptor.seq(desc) || payload_offset != 0
        return false
    end
    payload_slot == header_index || return false
    payload_slot < state.consumer_state.mappings.mapped_nslots || return false

    pool_stride = get(state.consumer_state.mappings.pool_stride_bytes, pool_id, UInt32(0))
    pool_stride == 0 && return false
    payload_len <= Int(pool_stride) || return false
    payload_len <= Int(state.config.max_payload_bytes) || return false

    payload_mmap = get(state.consumer_state.mappings.payload_mmaps, pool_id, nothing)
    payload_mmap === nothing && return false

    second = seqlock_read_end(commit_ptr)
    if first != second || seqlock_is_write_in_progress(second)
        return false
    end

    chunk_bytes = bridge_effective_chunk_bytes(state.config)
    chunk_bytes > 0 || return false
    chunk_count = cld(payload_len, chunk_bytes)
    chunk_count > 0 || return false
    chunk_count <= 65535 || return false

    payload_base = payload_slot_offset(pool_stride, payload_slot)
    seq = FrameDescriptor.seq(desc)
    epoch = FrameDescriptor.epoch(desc)

    for chunk_index in 0:(chunk_count - 1)
        chunk_offset = chunk_index * chunk_bytes
        chunk_len = min(chunk_bytes, payload_len - chunk_offset)
        header_included = chunk_index == 0
        header_len = header_included ? HEADER_SLOT_BYTES : 0
        msg_len = bridge_chunk_message_length(header_len, chunk_len)

        sent = let st = state,
            epoch = epoch,
            seq = seq,
            chunk_index = chunk_index,
            chunk_count = chunk_count,
            chunk_offset = chunk_offset,
            chunk_len = chunk_len,
            payload_len = payload_len,
            header_included = header_included,
            payload_mmap = payload_mmap,
            payload_base = payload_base
            try_claim_sbe!(st.pub_payload, st.chunk_claim, msg_len) do buf
                BridgeFrameChunk.wrap_and_apply_header!(st.chunk_encoder, buf, 0)
                BridgeFrameChunk.streamId!(st.chunk_encoder, st.mapping.source_stream_id)
                BridgeFrameChunk.epoch!(st.chunk_encoder, epoch)
                BridgeFrameChunk.seq!(st.chunk_encoder, seq)
                BridgeFrameChunk.chunkIndex!(st.chunk_encoder, UInt32(chunk_index))
                BridgeFrameChunk.chunkCount!(st.chunk_encoder, UInt32(chunk_count))
                BridgeFrameChunk.chunkOffset!(st.chunk_encoder, UInt32(chunk_offset))
                BridgeFrameChunk.chunkLength!(st.chunk_encoder, UInt32(chunk_len))
                BridgeFrameChunk.payloadLength!(st.chunk_encoder, UInt32(payload_len))
                BridgeFrameChunk.headerIncluded!(
                    st.chunk_encoder,
                    header_included ? BridgeBool.TRUE : BridgeBool.FALSE,
                )
                if header_included
                    BridgeFrameChunk.headerBytes!(st.chunk_encoder, st.header_buf)
                else
                    BridgeFrameChunk.headerBytes!(st.chunk_encoder, nothing)
                end
                if chunk_len == 0
                    BridgeFrameChunk.payloadBytes!(st.chunk_encoder, nothing)
                else
                    payload_view = @view payload_mmap[
                        payload_base + chunk_offset + 1:payload_base + chunk_offset + chunk_len
                    ]
                    BridgeFrameChunk.payloadBytes!(st.chunk_encoder, payload_view)
                end
            end
        end
        sent || return false
    end
    return true
end

"""
Update receiver state with the latest forwarded announce.
"""
function bridge_apply_source_announce!(state::BridgeReceiverState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.mapping.source_stream_id || return false
    pool_stride_bytes = state.source_info.pool_stride_bytes
    empty!(pool_stride_bytes)
    pools = ShmPoolAnnounce.payloadPools(msg)
    for pool in pools
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_stride_bytes[pool_id] = pool_stride
    end
    state.source_info.stream_id = ShmPoolAnnounce.streamId(msg)
    state.source_info.epoch = ShmPoolAnnounce.epoch(msg)
    state.source_info.layout_version = ShmPoolAnnounce.layoutVersion(msg)
    state.source_info.max_dims = ShmPoolAnnounce.maxDims(msg)
    state.have_announce = true
    return true
end

"""
Assemble a BridgeFrameChunk into an in-flight frame.
"""
function bridge_receive_chunk!(
    state::BridgeReceiverState,
    chunk::BridgeFrameChunk.Decoder,
    now_ns::UInt64,
)
    state.have_announce || return nothing
    BridgeFrameChunk.streamId(chunk) == state.mapping.source_stream_id || return nothing

    seq = BridgeFrameChunk.seq(chunk)
    epoch = BridgeFrameChunk.epoch(chunk)
    epoch == state.source_info.epoch || return nothing

    chunk_index = UInt32(BridgeFrameChunk.chunkIndex(chunk))
    chunk_count = UInt32(BridgeFrameChunk.chunkCount(chunk))
    chunk_offset = UInt32(BridgeFrameChunk.chunkOffset(chunk))
    chunk_length = UInt32(BridgeFrameChunk.chunkLength(chunk))
    payload_length = UInt32(BridgeFrameChunk.payloadLength(chunk))
    header_included = BridgeFrameChunk.headerIncluded(chunk) == BridgeBool.TRUE

    chunk_count == 0 && return nothing
    chunk_count <= 65535 || return nothing
    chunk_index < chunk_count || return nothing
    payload_length <= state.config.max_payload_bytes || return nothing
    payload_length <= UInt32(length(state.assembly.payload)) || return nothing
    chunk_count <= UInt32(length(state.assembly.received)) || return nothing

    header_len, header_pos, payload_len, payload_pos = bridge_chunk_var_data_positions(chunk)
    header_included && header_len != HEADER_SLOT_BYTES && return nothing
    !header_included && header_len != 0 && return nothing
    payload_len != Int(chunk_length) && return nothing
    (chunk_index == 0) == header_included || return nothing

    max_chunk = bridge_effective_chunk_bytes(state.config)
    max_chunk > 0 || return nothing
    Int(chunk_length) <= max_chunk || return nothing

    if chunk_index == 0 && chunk_offset != 0
        return nothing
    end
    Int(chunk_offset) + Int(chunk_length) <= Int(payload_length) || return nothing

    assembly = state.assembly
    timeout_ns = state.config.assembly_timeout_ns
    if timeout_ns > 0 && now_ns > assembly.last_update_ns &&
       now_ns - assembly.last_update_ns > timeout_ns
        reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
    end

    if assembly.seq != seq || assembly.epoch != epoch || assembly.chunk_count != chunk_count ||
       assembly.payload_length != payload_length
        if payload_length > UInt32(length(assembly.payload)) ||
           chunk_count > UInt32(length(assembly.received))
            return nothing
        end
        reset_bridge_assembly!(assembly, seq, epoch, chunk_count, payload_length, now_ns)
    end

    if assembly.received[Int(chunk_index) + 1]
        buf = BridgeFrameChunk.sbe_buffer(chunk)
        mismatch = false
        @inbounds for i in 1:Int(chunk_length)
            if assembly.payload[Int(chunk_offset) + i] != buf[payload_pos + i]
                mismatch = true
                break
            end
        end
        if mismatch
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
        end
        return nothing
    end

    if header_included
        copyto!(
            assembly.header_bytes,
            1,
            BridgeFrameChunk.sbe_buffer(chunk),
            header_pos + 1,
            header_len,
        )
        assembly.header_present = true
    end

    if chunk_length > 0
        copyto!(
            assembly.payload,
            Int(chunk_offset) + 1,
            BridgeFrameChunk.sbe_buffer(chunk),
            payload_pos + 1,
            Int(chunk_length),
        )
    end

    assembly.received[Int(chunk_index) + 1] = true
    assembly.received_chunks += UInt32(1)
    assembly.last_update_ns = now_ns

    if assembly.received_chunks == assembly.chunk_count && assembly.header_present
        wrap_tensor_header!(state.header_decoder, assembly.header_bytes, 0)
        values_len = TensorSlotHeader256.valuesLenBytes(state.header_decoder)
        if values_len != assembly.payload_length
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
        ndims = TensorSlotHeader256.ndims(state.header_decoder)
        dtype = TensorSlotHeader256.dtype(state.header_decoder)
        major_order = TensorSlotHeader256.majorOrder(state.header_decoder)
        if ndims > state.source_info.max_dims || !valid_dtype(dtype) || !valid_major_order(major_order)
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
        pool_id = TensorSlotHeader256.poolId(state.header_decoder)
        stride = get(state.source_info.pool_stride_bytes, pool_id, UInt32(0))
        if stride == 0 || assembly.payload_length > stride
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
        frame_id = TensorSlotHeader256.frameId(state.header_decoder)
        if frame_id != assembly.seq
            reset_bridge_assembly!(assembly, UInt64(0), UInt64(0), UInt32(0), UInt32(0), now_ns)
            return nothing
        end
    return BridgeAssembledFrame(
            assembly.seq,
            assembly.epoch,
            assembly.payload_length,
            assembly.header_bytes,
            assembly.payload,
        )
    end

    return nothing
end

"""
Create a FragmentAssembler for bridge payload chunks.
"""
function make_bridge_payload_assembler(state::BridgeReceiverState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = BridgeMessageHeader.Decoder(buffer, 0)
        if BridgeMessageHeader.templateId(header) == TEMPLATE_BRIDGE_FRAME_CHUNK
            BridgeFrameChunk.wrap!(st.chunk_decoder, buffer, 0; header = header)
            frame = bridge_receive_chunk!(st, st.chunk_decoder, st.now_ns)
            if frame !== nothing && st.producer_state !== nothing
                bridge_rematerialize!(st, st.producer_state, frame)
            end
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a FragmentAssembler for forwarded control messages.
"""
function make_bridge_control_assembler(state::BridgeReceiverState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.announce_decoder, buffer, 0; header = header)
            bridge_apply_source_announce!(st, st.announce_decoder)
        elseif template_id == TEMPLATE_QOS_PRODUCER
            QosProducer.wrap!(st.qos_producer_decoder, buffer, 0; header = header)
            bridge_publish_qos_producer!(st, st.qos_producer_decoder)
        elseif template_id == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.qos_consumer_decoder, buffer, 0; header = header)
            bridge_publish_qos_consumer!(st, st.qos_consumer_decoder)
        elseif template_id == TEMPLATE_FRAME_PROGRESS
            FrameProgress.wrap!(st.progress_decoder, buffer, 0; header = header)
            bridge_publish_progress!(st, st.progress_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a FragmentAssembler for forwarding control messages on the sender.
"""
function make_bridge_control_sender_assembler(state::BridgeSenderState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.announce_decoder, buffer, 0; header = header)
            bridge_forward_announce!(st, st.announce_decoder)
        elseif template_id == TEMPLATE_QOS_PRODUCER
            QosProducer.wrap!(st.qos_producer_decoder, buffer, 0; header = header)
            bridge_forward_qos_producer!(st, st.qos_producer_decoder)
        elseif template_id == TEMPLATE_QOS_CONSUMER
            QosConsumer.wrap!(st.qos_consumer_decoder, buffer, 0; header = header)
            bridge_forward_qos_consumer!(st, st.qos_consumer_decoder)
        elseif template_id == TEMPLATE_FRAME_PROGRESS
            FrameProgress.wrap!(st.progress_decoder, buffer, 0; header = header)
            bridge_forward_progress!(st, st.progress_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a FragmentAssembler for source metadata forwarding on the sender.
"""
function make_bridge_metadata_sender_assembler(state::BridgeSenderState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == DataSourceAnnounce.sbe_template_id(DataSourceAnnounce.Decoder)
            DataSourceAnnounce.wrap!(st.metadata_announce_decoder, buffer, 0; header = header)
            bridge_forward_metadata_announce!(st, st.metadata_announce_decoder)
        elseif template_id == DataSourceMeta.sbe_template_id(DataSourceMeta.Decoder)
            DataSourceMeta.wrap!(st.metadata_meta_decoder, buffer, 0; header = header)
            bridge_forward_metadata_meta!(st, st.metadata_meta_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a FragmentAssembler for forwarding metadata to local IPC on the receiver.
"""
function make_bridge_metadata_receiver_assembler(state::BridgeReceiverState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == DataSourceAnnounce.sbe_template_id(DataSourceAnnounce.Decoder)
            DataSourceAnnounce.wrap!(st.metadata_announce_decoder, buffer, 0; header = header)
            bridge_publish_metadata_announce!(st, st.metadata_announce_decoder)
        elseif template_id == DataSourceMeta.sbe_template_id(DataSourceMeta.Decoder)
            DataSourceMeta.wrap!(st.metadata_meta_decoder, buffer, 0; header = header)
            bridge_publish_metadata_meta!(st, st.metadata_meta_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Poll metadata subscription for a bridge sender.
"""
function bridge_sender_do_work!(
    state::BridgeSenderState;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    work_count = 0
    work_count += Aeron.poll(state.sub_control, state.control_assembler, fragment_limit)
    if state.sub_metadata !== nothing && state.metadata_assembler !== nothing
        work_count += Aeron.poll(state.sub_metadata, state.metadata_assembler, fragment_limit)
    end
    return work_count
end

"""
Poll bridge receiver subscriptions and return work count.
"""
function bridge_receiver_do_work!(
    state::BridgeReceiverState;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    work_count = 0
    fetch!(state.clock)
    state.now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count += Aeron.poll(state.sub_control, state.control_assembler, fragment_limit)
    work_count += Aeron.poll(state.sub_payload, state.payload_assembler, fragment_limit)
    if state.sub_metadata !== nothing && state.metadata_assembler !== nothing
        work_count += Aeron.poll(state.sub_metadata, state.metadata_assembler, fragment_limit)
    end
    return work_count
end
