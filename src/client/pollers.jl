import ..Control: FrameDescriptorPoller, ConsumerConfigPoller, FrameProgressPoller, TraceLinkPoller

"""
Construct a FrameDescriptorPoller from a TensorPoolClient.
"""
function FrameDescriptorPoller(
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
    handler::H,
) where {H}
    return Control.FrameDescriptorPoller(client.aeron_client, channel, stream_id, handler)
end

"""
Construct a TraceLinkPoller from a TensorPoolClient.
"""
function TraceLinkPoller(
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
    handler::H,
) where {H}
    return Control.TraceLinkPoller(client.aeron_client, channel, stream_id, handler)
end
"""
Construct a ConsumerConfigPoller from a TensorPoolClient.
"""
function ConsumerConfigPoller(
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
    handler::H,
) where {H}
    return Control.ConsumerConfigPoller(client.aeron_client, channel, stream_id, handler)
end

"""
Construct a FrameProgressPoller from a TensorPoolClient.
"""
function FrameProgressPoller(
    client::TensorPoolClient,
    channel::AbstractString,
    stream_id::Int32,
    handler::H,
) where {H}
    return Control.FrameProgressPoller(client.aeron_client, channel, stream_id, handler)
end
