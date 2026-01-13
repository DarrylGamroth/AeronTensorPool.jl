"""
Create a descriptor fragment assembler for the consumer.

Arguments:
- `state`: consumer state.
- `callbacks`: optional consumer callbacks (default: NOOP_CONSUMER_CALLBACKS).

Returns:
- `Aeron.FragmentAssembler` configured for descriptor messages.
"""
function make_descriptor_assembler(state::ConsumerState; callbacks::ConsumerCallbacks = NOOP_CONSUMER_CALLBACKS)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.schemaId(header) != MessageHeader.sbe_schema_id(MessageHeader.Decoder)
            return nothing
        end
        if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
            @tp_info "consumer descriptor received"
            FrameDescriptor.wrap!(st.runtime.desc_decoder, buffer, 0; header = header)
            if try_read_frame!(st, st.runtime.desc_decoder)
                st.metrics.frames_ok += 1
                callbacks.on_frame!(st, st.runtime.frame_view)
                @tp_info "consumer frame ready" seq = seqlock_sequence(st.runtime.frame_view.header.seq_commit)
            end
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a control-channel fragment assembler for the consumer.

Arguments:
- `state`: consumer state.

Returns:
- `Aeron.FragmentAssembler` configured for control messages.
"""
function make_control_assembler(state::ConsumerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.schemaId(header) != MessageHeader.sbe_schema_id(MessageHeader.Decoder)
            return nothing
        end
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.runtime.announce_decoder, buffer, 0; header = header)
            handle_shm_pool_announce!(st, st.runtime.announce_decoder)
        elseif template_id == TEMPLATE_CONSUMER_CONFIG
            ConsumerConfigMsg.wrap!(st.runtime.config_decoder, buffer, 0; header = header)
            apply_consumer_config!(st, st.runtime.config_decoder)
        elseif template_id == TEMPLATE_FRAME_PROGRESS
            FrameProgress.wrap!(st.runtime.progress_decoder, buffer, 0; header = header)
            handle_frame_progress!(st, st.runtime.progress_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a progress fragment assembler for the consumer.

Arguments:
- `state`: consumer state.

Returns:
- `Aeron.FragmentAssembler` configured for progress messages.
"""
function make_progress_assembler(state::ConsumerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.schemaId(header) != MessageHeader.sbe_schema_id(MessageHeader.Decoder)
            return nothing
        end
        if MessageHeader.templateId(header) == TEMPLATE_FRAME_PROGRESS
            FrameProgress.wrap!(st.runtime.progress_decoder, buffer, 0; header = header)
            handle_frame_progress!(st, st.runtime.progress_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Validate a FrameProgress message against the current SHM header.

Returns `true` if progress is accepted, `false` if it is dropped.
"""
function handle_frame_progress!(state::ConsumerState, msg::FrameProgress.Decoder)
    state.config.supports_progress || return false
    header_mmap = state.mappings.header_mmap
    header_mmap === nothing && return false

    seq = FrameProgress.seq(msg)
    state.mappings.mapped_nslots == 0 && return false
    header_index = UInt32(seq & (UInt64(state.mappings.mapped_nslots) - 1))
    header_index >= state.mappings.mapped_nslots && return false

    header_offset = header_slot_offset(header_index)
    commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
    first = seqlock_read_begin(commit_ptr)
    seqlock_is_committed(first) || return false

    wrap_slot_header!(state.runtime.slot_decoder, header_mmap, header_offset)
    header = try_read_slot_header(state.runtime.slot_decoder, state.runtime.tensor_decoder)
    header === nothing && return false

    second = seqlock_read_end(commit_ptr)
    if first != second || !seqlock_is_committed(second)
        return false
    end
    header.seq_commit == second || return false
    seqlock_sequence(second) == seq || return false

    payload_bytes = FrameProgress.payloadBytesFilled(msg)
    UInt64(header.values_len_bytes) >= payload_bytes || return false
    progress_stride_ok!(state, header.tensor) || return false

    idx = Int(header_index) + 1
    last_frame = state.mappings.progress_last_frame[idx]
    if last_frame != seq
        state.mappings.progress_last_frame[idx] = seq
        state.mappings.progress_last_bytes[idx] = UInt64(0)
    end
    last = state.mappings.progress_last_bytes[idx]
    payload_bytes < last && return false
    state.mappings.progress_last_bytes[idx] = payload_bytes
    return true
end

"""
Poll the descriptor subscription and process frames.

Arguments:
- `state`: consumer state.
- `assembler`: fragment assembler for descriptors.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_descriptor!(
    state::ConsumerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.sub_descriptor, assembler, fragment_limit)
end

"""
Poll the control subscription and apply mapping/config updates.

Arguments:
- `state`: consumer state.
- `assembler`: fragment assembler for control channel.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_control!(
    state::ConsumerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Aeron.poll(state.runtime.control.sub_control, assembler, fragment_limit)
end

"""
Poll the per-consumer progress subscription when assigned.

Arguments:
- `state`: consumer state.
- `assembler`: fragment assembler for progress channel.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_progress!(
    state::ConsumerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    sub = state.runtime.sub_progress
    sub === nothing && return 0
    return Aeron.poll(sub, assembler, fragment_limit)
end

function (handler::ConsumerHelloHandler)(state::ConsumerState, now_ns::UInt64)
    emit_consumer_hello!(state)
    return 1
end

function (handler::ConsumerQosHandler)(state::ConsumerState, now_ns::UInt64)
    emit_qos!(state)
    return 1
end

"""
Apply a ConsumerConfig message to the consumer settings.

Arguments:
- `state`: consumer state.
- `msg`: decoded ConsumerConfig message.

Returns:
- `true` if applied, `false` otherwise.
"""
function apply_consumer_config!(state::ConsumerState, msg::ConsumerConfigMsg.Decoder)
    ConsumerConfigMsg.streamId(msg) == state.config.stream_id || return false
    ConsumerConfigMsg.consumerId(msg) == state.config.consumer_id || return false

    state.config.use_shm = (ConsumerConfigMsg.useShm(msg) == ShmTensorpoolControl.Bool_.TRUE)
    state.config.mode = ConsumerConfigMsg.mode(msg)
    state.config.payload_fallback_uri = String(ConsumerConfigMsg.payloadFallbackUri(msg))

    descriptor_channel = String(ConsumerConfigMsg.descriptorChannel(msg))
    descriptor_stream_id = ConsumerConfigMsg.descriptorStreamId(msg)
    descriptor_null = ConsumerConfigMsg.descriptorStreamId_null_value(ConsumerConfigMsg.Decoder)
    descriptor_assigned =
        !isempty(descriptor_channel) && descriptor_stream_id != 0 && descriptor_stream_id != descriptor_null

    if descriptor_assigned
        if state.assigned_descriptor_stream_id != descriptor_stream_id ||
            state.assigned_descriptor_channel != descriptor_channel
            new_sub = Aeron.add_subscription(
                state.runtime.control.client,
                descriptor_channel,
                Int32(descriptor_stream_id),
            )
            close(state.runtime.sub_descriptor)
            state.runtime.sub_descriptor = new_sub
            state.assigned_descriptor_channel = descriptor_channel
            state.assigned_descriptor_stream_id = descriptor_stream_id
        end
    elseif state.assigned_descriptor_stream_id != 0
        new_sub = Aeron.add_subscription(
            state.runtime.control.client,
            state.config.aeron_uri,
            state.config.descriptor_stream_id,
        )
        close(state.runtime.sub_descriptor)
        state.runtime.sub_descriptor = new_sub
        state.assigned_descriptor_channel = ""
        state.assigned_descriptor_stream_id = UInt32(0)
    end

    control_channel = String(ConsumerConfigMsg.controlChannel(msg))
    control_stream_id = ConsumerConfigMsg.controlStreamId(msg)
    control_null = ConsumerConfigMsg.controlStreamId_null_value(ConsumerConfigMsg.Decoder)
    control_assigned =
        !isempty(control_channel) && control_stream_id != 0 && control_stream_id != control_null

    if control_assigned
        if state.assigned_control_stream_id != control_stream_id ||
            state.assigned_control_channel != control_channel
            new_sub = Aeron.add_subscription(
                state.runtime.control.client,
                control_channel,
                Int32(control_stream_id),
            )
            state.runtime.sub_progress === nothing || close(state.runtime.sub_progress)
            state.runtime.sub_progress = new_sub
            state.assigned_control_channel = control_channel
            state.assigned_control_stream_id = control_stream_id
        end
    elseif state.runtime.sub_progress !== nothing
        close(state.runtime.sub_progress)
        state.runtime.sub_progress = nothing
        state.assigned_control_channel = ""
        state.assigned_control_stream_id = UInt32(0)
    end

    if !state.config.use_shm
        reset_mappings!(state)
    end
    return true
end
