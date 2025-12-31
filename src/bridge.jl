mutable struct BridgeConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    payload_stream_id::Int32
    stream_id::UInt32
    bridge_epoch::UInt64
end

mutable struct BridgeState
    consumer_state::ConsumerState
    config::BridgeConfig
    client::Aeron.Client
    pub_descriptor::Aeron.Publication
    pub_payload::Aeron.Publication
    descriptor_buf::Vector{UInt8}
    descriptor_encoder::FrameDescriptor.Encoder{Vector{UInt8}}
    descriptor_claim::Aeron.BufferClaim
end

function init_bridge(consumer_state::ConsumerState, config::BridgeConfig)
    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    pub_payload = Aeron.add_publication(client, config.aeron_uri, config.payload_stream_id)

    return BridgeState(
        consumer_state,
        config,
        client,
        pub_descriptor,
        pub_payload,
        Vector{UInt8}(undef, 512),
        FrameDescriptor.Encoder(Vector{UInt8}),
        Aeron.BufferClaim(),
    )
end

function bridge_frame!(state::BridgeState, header::TensorSlotHeader, payload::AbstractVector{UInt8})
    Aeron.offer(state.pub_payload, payload)

    sent = try_claim_sbe!(state.pub_descriptor, state.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        buf_view = unsafe_wrap(Vector{UInt8}, pointer(buf), length(buf))
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, buf_view, 0)
        FrameDescriptor.streamId!(state.descriptor_encoder, state.config.stream_id)
        FrameDescriptor.epoch!(state.descriptor_encoder, state.config.bridge_epoch)
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
    FrameDescriptor.epoch!(state.descriptor_encoder, state.config.bridge_epoch)
    FrameDescriptor.seq!(state.descriptor_encoder, header.frame_id)
    FrameDescriptor.headerIndex!(state.descriptor_encoder, UInt32(header.payload_slot))
    FrameDescriptor.timestampNs!(state.descriptor_encoder, header.timestamp_ns)
    FrameDescriptor.metaVersion!(state.descriptor_encoder, header.meta_version)
    Aeron.offer(
        state.pub_descriptor,
        view(state.descriptor_buf, 1:sbe_message_length(state.descriptor_encoder)),
    )
    return true
end
