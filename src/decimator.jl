mutable struct DecimatorConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    stream_id::UInt32
    epoch::UInt64
    decimation::UInt16
end

mutable struct DecimatorState
    consumer_state::ConsumerState
    config::DecimatorConfig
    client::Aeron.Client
    pub_descriptor::Aeron.Publication
    descriptor_buf::Vector{UInt8}
    descriptor_encoder::FrameDescriptor.Encoder{Vector{UInt8}}
    descriptor_claim::Aeron.BufferClaim
    frame_counter::UInt64
end

function init_decimator(consumer_state::ConsumerState, config::DecimatorConfig)
    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)

    return DecimatorState(
        consumer_state,
        config,
        client,
        pub_descriptor,
        Vector{UInt8}(undef, 512),
        FrameDescriptor.Encoder(Vector{UInt8}),
        Aeron.BufferClaim(),
        UInt64(0),
    )
end

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

function republish_descriptor!(
    state::DecimatorState,
    header::TensorSlotHeader,
    _payload::AbstractVector{UInt8},
)
    sent = try_claim_sbe!(state.pub_descriptor, state.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        buf_view = unsafe_wrap(Vector{UInt8}, pointer(buf), length(buf))
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, buf_view, 0)
        FrameDescriptor.streamId!(state.descriptor_encoder, state.config.stream_id)
        FrameDescriptor.epoch!(state.descriptor_encoder, state.config.epoch)
        FrameDescriptor.seq!(state.descriptor_encoder, header.frame_id)
        FrameDescriptor.headerIndex!(state.descriptor_encoder, UInt32(header.payload_slot))
        FrameDescriptor.timestampNs!(state.descriptor_encoder, header.timestamp_ns)
        FrameDescriptor.metaVersion!(state.descriptor_encoder, header.meta_version)
    end

    if sent
        return true
    end

    FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, state.descriptor_buf, 0)
    FrameDescriptor.streamId!(state.descriptor_encoder, state.config.stream_id)
    FrameDescriptor.epoch!(state.descriptor_encoder, state.config.epoch)
    FrameDescriptor.seq!(state.descriptor_encoder, header.frame_id)
    FrameDescriptor.headerIndex!(state.descriptor_encoder, UInt32(header.payload_slot))
    FrameDescriptor.timestampNs!(state.descriptor_encoder, header.timestamp_ns)
    FrameDescriptor.metaVersion!(state.descriptor_encoder, header.meta_version)
    Aeron.offer(
        state.pub_descriptor,
        view(state.descriptor_buf, 1:sbe_encoded_length(state.descriptor_encoder)),
    )
    return true
end
