import ..Control: FrameDescriptorPoller, ConsumerConfigPoller, FrameProgressPoller, TraceLinkPoller

"""
Construct a FrameDescriptorPoller from a TensorPoolClient.
"""
function FrameDescriptorPoller(
    handler::H,
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
) where {H}
    return Control.FrameDescriptorPoller(handler, client.aeron_client, channel, stream_id)
end

"""
Construct a TraceLinkPoller from a TensorPoolClient.
"""
function TraceLinkPoller(
    handler::H,
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
) where {H}
    return Control.TraceLinkPoller(handler, client.aeron_client, channel, stream_id)
end
"""
Construct a ConsumerConfigPoller from a TensorPoolClient.
"""
function ConsumerConfigPoller(
    handler::H,
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
) where {H}
    return Control.ConsumerConfigPoller(handler, client.aeron_client, channel, stream_id)
end

"""
Construct a FrameProgressPoller from a TensorPoolClient.
"""
function FrameProgressPoller(
    handler::H,
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
) where {H}
    return Control.FrameProgressPoller(handler, client.aeron_client, channel, stream_id)
end
