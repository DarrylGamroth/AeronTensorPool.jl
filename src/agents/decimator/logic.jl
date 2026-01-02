"""
Initialize a decimator using an existing consumer mapping.
"""
function init_decimator(
    consumer_state::ConsumerState,
    config::DecimatorConfig;
    aeron_ctx::Union{Nothing, Aeron.Context} = nothing,
    aeron_client::Union{Nothing, Aeron.Client} = nothing,
)
    ctx, client, owns_ctx, owns_client = acquire_aeron(
        config.aeron_dir;
        ctx = aeron_ctx,
        client = aeron_client,
    )

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)

    return DecimatorState(
        consumer_state,
        config,
        ctx,
        client,
        owns_ctx,
        owns_client,
        pub_descriptor,
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
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
    sent = let st = state,
        header = header
        try_claim_sbe!(st.pub_descriptor, st.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
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
