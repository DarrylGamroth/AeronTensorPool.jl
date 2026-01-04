"""
Apply decimation and republish a descriptor when the ratio matches.

Arguments:
- `state`: decimator state.
- `header`: decoded tensor slot header.
- `payload`: payload bytes view.

Returns:
- `true` if republished, `false` if dropped.
"""
function handle_decimated_frame!(
    state::DecimatorState,
    header::TensorSlotHeader,
    payload::AbstractVector{UInt8},
)
    return handle_decimated_frame!(state, header, payload, NOOP_DECIMATOR_HOOKS)
end

"""
Apply decimation and republish a descriptor when the ratio matches.

Arguments:
- `state`: decimator state.
- `header`: decoded tensor slot header.
- `payload`: payload bytes view.
- `hooks`: decimator hooks.

Returns:
- `true` if republished, `false` if dropped.
"""
function handle_decimated_frame!(
    state::DecimatorState,
    header::TensorSlotHeader,
    payload::AbstractVector{UInt8},
    hooks::DecimatorHooks,
)
    if state.config.decimation == 0
        return false
    end
    state.frame_counter += 1
    if state.frame_counter % state.config.decimation == 0
        sent = republish_descriptor!(state, header, payload)
        sent && hooks.on_republish!(state, header)
        return sent
    end
    return false
end

"""
Republish a FrameDescriptor with decimator epoch and stream id.

Arguments:
- `state`: decimator state.
- `header`: decoded tensor slot header.
- `payload`: payload bytes view (unused).

Returns:
- `true` if the descriptor was committed, `false` otherwise.
"""
function republish_descriptor!(
    state::DecimatorState,
    header::TensorSlotHeader,
    _payload::AbstractVector{UInt8},
)
    sent = let st = state,
        header = header
        with_claimed_buffer!(st.pub_descriptor, st.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
            FrameDescriptor.wrap_and_apply_header!(st.descriptor_encoder, buf, 0)
            FrameDescriptor.streamId!(st.descriptor_encoder, st.config.stream_id)
            FrameDescriptor.epoch!(st.descriptor_encoder, st.config.epoch)
            FrameDescriptor.seq!(st.descriptor_encoder, header.frame_id)
            FrameDescriptor.headerIndex!(st.descriptor_encoder, UInt32(header.payload_slot))
            FrameDescriptor.timestampNs!(st.descriptor_encoder, header.timestamp_ns)
            FrameDescriptor.metaVersion!(st.descriptor_encoder, header.meta_version)
        end
    end
    return sent
end
