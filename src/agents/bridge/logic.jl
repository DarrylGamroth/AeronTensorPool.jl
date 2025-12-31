"""
Initialize a bridge using an existing consumer mapping.
"""
function init_bridge(consumer_state::ConsumerState, config::BridgeConfig)
    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    pub_payload = Aeron.add_publication(client, config.aeron_uri, config.payload_stream_id)

    return BridgeState(
        consumer_state,
        config,
        ctx,
        client,
        pub_descriptor,
        pub_payload,
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
    )
end

"""
Republish a frame payload and descriptor on the bridge channel.
"""
function bridge_frame!(state::BridgeState, header::TensorSlotHeader, payload::AbstractVector{UInt8})
    sent_payload = try_claim_payload!(state.pub_payload, state.payload_claim, payload)
    sent_payload || return false

    sent = try_claim_sbe!(state.pub_descriptor, state.descriptor_claim, FRAME_DESCRIPTOR_LEN) do buf
        FrameDescriptor.wrap_and_apply_header!(state.descriptor_encoder, buf, 0)
        FrameDescriptor.streamId!(state.descriptor_encoder, state.config.stream_id)
        FrameDescriptor.epoch!(state.descriptor_encoder, state.config.bridge_epoch)
        FrameDescriptor.seq!(state.descriptor_encoder, header.frame_id)
        FrameDescriptor.headerIndex!(state.descriptor_encoder, UInt32(header.payload_slot))
        FrameDescriptor.timestampNs!(state.descriptor_encoder, header.timestamp_ns)
        FrameDescriptor.metaVersion!(state.descriptor_encoder, header.meta_version)
    end
    return sent
end
