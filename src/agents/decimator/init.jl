"""
Initialize a decimator using an existing consumer mapping.
"""
function init_decimator(
    consumer_state::ConsumerState,
    config::DecimatorConfig;
    client::Aeron.Client,
)

    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)

    return DecimatorState(
        consumer_state,
        config,
        client,
        pub_descriptor,
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        UInt64(0),
    )
end
