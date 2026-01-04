"""
Create a payload fragment assembler for bridge receiver chunks.

Arguments:
- `state`: bridge receiver state.
- `hooks`: optional bridge hooks.

Returns:
- `Aeron.FragmentAssembler` configured for payload chunks.
"""
function make_bridge_payload_assembler(state::BridgeReceiverState; hooks::BridgeHooks = NOOP_BRIDGE_HOOKS)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = ShmTensorpoolBridge.MessageHeader.Decoder(buffer, 0)
        if ShmTensorpoolBridge.MessageHeader.templateId(header) == TEMPLATE_BRIDGE_FRAME_CHUNK
            BridgeFrameChunk.wrap!(st.chunk_decoder, buffer, 0; header = header)
            now_ns = UInt64(Clocks.time_nanos(st.clock))
            bridge_receive_chunk!(st, st.chunk_decoder, now_ns)
            hooks.on_receive_chunk!(st, st.chunk_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a control fragment assembler for bridge receiver control channel.

Arguments:
- `state`: bridge receiver state.

Returns:
- `Aeron.FragmentAssembler` configured for control messages.
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
Create a control fragment assembler for bridge sender control channel.

Arguments:
- `state`: bridge sender state.

Returns:
- `Aeron.FragmentAssembler` configured for control messages.
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
Create a metadata fragment assembler for bridge sender.

Arguments:
- `state`: bridge sender state.

Returns:
- `Aeron.FragmentAssembler` configured for metadata messages.
"""
function make_bridge_metadata_sender_assembler(state::BridgeSenderState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_DATA_SOURCE_ANNOUNCE
            DataSourceAnnounce.wrap!(st.metadata_announce_decoder, buffer, 0; header = header)
            bridge_forward_metadata_announce!(st, st.metadata_announce_decoder)
        elseif template_id == TEMPLATE_DATA_SOURCE_META
            DataSourceMeta.wrap!(st.metadata_meta_decoder, buffer, 0; header = header)
            bridge_forward_metadata_meta!(st, st.metadata_meta_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a metadata fragment assembler for bridge receiver.

Arguments:
- `state`: bridge receiver state.

Returns:
- `Aeron.FragmentAssembler` configured for metadata messages.
"""
function make_bridge_metadata_receiver_assembler(state::BridgeReceiverState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_DATA_SOURCE_ANNOUNCE
            DataSourceAnnounce.wrap!(st.metadata_announce_decoder, buffer, 0; header = header)
            bridge_publish_metadata_announce!(st, st.metadata_announce_decoder)
        elseif template_id == TEMPLATE_DATA_SOURCE_META
            DataSourceMeta.wrap!(st.metadata_meta_decoder, buffer, 0; header = header)
            bridge_publish_metadata_meta!(st, st.metadata_meta_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Bridge sender duty cycle: poll input and forward frames.

Arguments:
- `state`: bridge sender state.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Work count (sum of polled fragments and timer work).
"""
function bridge_sender_do_work!(
    state::BridgeSenderState;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    work_count = 0
    work_count += Aeron.poll(state.sub_control, state.control_assembler, fragment_limit)
    if state.sub_metadata !== nothing
        work_count += Aeron.poll(state.sub_metadata, state.metadata_assembler, fragment_limit)
    end
    return work_count
end

"""
Bridge receiver duty cycle: poll chunks and rematerialize frames.

Arguments:
- `state`: bridge receiver state.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Work count (sum of polled fragments and timer work).
"""
function bridge_receiver_do_work!(
    state::BridgeReceiverState;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    fetch!(state.clock)
    work_count = 0
    work_count += Aeron.poll(state.sub_control, state.control_assembler, fragment_limit)
    work_count += Aeron.poll(state.sub_payload, state.payload_assembler, fragment_limit)
    if state.sub_metadata !== nothing
        work_count += Aeron.poll(state.sub_metadata, state.metadata_assembler, fragment_limit)
    end
    return work_count
end
