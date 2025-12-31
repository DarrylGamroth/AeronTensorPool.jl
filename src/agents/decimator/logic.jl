"""
Initialize a decimator using an existing consumer mapping.
"""
function init_decimator(consumer_state::ConsumerState, config::DecimatorConfig)
    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)

    return DecimatorState(
        consumer_state,
        config,
        ctx,
        client,
        pub_descriptor,
        Vector{UInt8}(undef, 512),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        UInt64(0),
    )
end

"""
Apply decimation and republish a descriptor when the ratio matches.
"""
function handle_decimated_frame!(
    state::DecimatorState,
    header::TensorSlotHeader,
    payload::AbstractVector{UInt8},
)
    if state.config.decimation == 0
        return false
    end
    state.frame_counter += 1
    if state.frame_counter % state.config.decimation == 0
        return republish_descriptor!(state, header, payload)
    end
    return false
end

"""
Republish a FrameDescriptor with decimator epoch and stream id.
"""
function republish_descriptor!(
    state::DecimatorState,
    header::TensorSlotHeader,
    _payload::AbstractVector{UInt8},
)
    sent = try_claim_sbe!(state.pub_descriptor, state.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, buf, 0)
        FrameDescriptor.streamId!(state.descriptor_encoder, state.config.stream_id)
        FrameDescriptor.epoch!(state.descriptor_encoder, state.config.epoch)
        FrameDescriptor.seq!(state.descriptor_encoder, header.frame_id)
        FrameDescriptor.headerIndex!(state.descriptor_encoder, UInt32(header.payload_slot))
        FrameDescriptor.timestampNs!(state.descriptor_encoder, header.timestamp_ns)
        FrameDescriptor.metaVersion!(state.descriptor_encoder, header.meta_version)
    end
    return sent
end
