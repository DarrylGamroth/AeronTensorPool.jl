import ..Timers: poll!

"""
Poller for FrameDescriptor messages.

The poller owns its Aeron subscription and calls `handler(poller, decoder)` for
each accepted descriptor.
"""
mutable struct FrameDescriptorPoller{H} <: AbstractControlPoller
    client::Aeron.Client
    subscription::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    decoder::FrameDescriptor.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    handler::H
end

"""
Poller for ConsumerConfig messages.

The poller owns its Aeron subscription and calls `handler(poller, decoder)` for
each accepted config update.
"""
mutable struct ConsumerConfigPoller{H} <: AbstractControlPoller
    client::Aeron.Client
    subscription::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    decoder::ConsumerConfigMsg.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    handler::H
end

"""
Poller for FrameProgress messages.

The poller owns its Aeron subscription and calls `handler(poller, decoder)` for
each accepted progress update.
"""
mutable struct FrameProgressPoller{H} <: AbstractControlPoller
    client::Aeron.Client
    subscription::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    decoder::FrameProgress.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    handler::H
end

"""
Construct a FrameDescriptorPoller.

Arguments:
- `client`: Aeron client used to create the subscription.
- `channel`: Aeron channel for the descriptor stream.
- `stream_id`: Aeron stream id for the descriptor stream.
- `handler`: callable invoked as `handler(poller, decoder)`.
"""
function FrameDescriptorPoller(
    client::Aeron.Client,
    channel::AbstractString,
    stream_id::Int32,
    handler::H,
) where {H}
    sub = Aeron.add_subscription(client, channel, stream_id)
    poller = FrameDescriptorPoller(
        client,
        sub,
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, _, _
            nothing
        end),
        FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        handler,
    )
    poller.assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(poller) do plr, buffer, _
        handle_frame_descriptor!(plr, buffer)
        nothing
    end)
    return poller
end

"""
Construct a ConsumerConfigPoller.

Arguments:
- `client`: Aeron client used to create the subscription.
- `channel`: Aeron channel for the control stream.
- `stream_id`: Aeron stream id for the control stream.
- `handler`: callable invoked as `handler(poller, decoder)`.
"""
function ConsumerConfigPoller(
    client::Aeron.Client,
    channel::AbstractString,
    stream_id::Int32,
    handler::H,
) where {H}
    sub = Aeron.add_subscription(client, channel, stream_id)
    poller = ConsumerConfigPoller(
        client,
        sub,
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, _, _
            nothing
        end),
        ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        handler,
    )
    poller.assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(poller) do plr, buffer, _
        handle_consumer_config!(plr, buffer)
        nothing
    end)
    return poller
end

"""
Construct a FrameProgressPoller.

Arguments:
- `client`: Aeron client used to create the subscription.
- `channel`: Aeron channel for the progress stream.
- `stream_id`: Aeron stream id for the progress stream.
- `handler`: callable invoked as `handler(poller, decoder)`.
"""
function FrameProgressPoller(
    client::Aeron.Client,
    channel::AbstractString,
    stream_id::Int32,
    handler::H,
) where {H}
    sub = Aeron.add_subscription(client, channel, stream_id)
    poller = FrameProgressPoller(
        client,
        sub,
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, _, _
            nothing
        end),
        FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        handler,
    )
    poller.assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(poller) do plr, buffer, _
        handle_frame_progress!(plr, buffer)
        nothing
    end)
    return poller
end

"""
Poll fragments for any control poller.
"""
function poll!(poller::AbstractControlPoller, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(poller.subscription, poller.assembler, fragment_limit)
end

"""
Rebind a poller to a new channel/stream.
"""
function rebind!(poller::AbstractControlPoller, channel::AbstractString, stream_id::Int32)
    poller.subscription = rebind_subscription!(poller.client, poller.subscription, channel, stream_id)
    return nothing
end

"""
Close the poller's subscription.
"""
function Base.close(poller::AbstractControlPoller)
    close(poller.subscription)
    return nothing
end

function handle_frame_descriptor!(poller::FrameDescriptorPoller, buffer::AbstractVector{UInt8})
    header = MessageHeader.Decoder(buffer, 0)
    if !matches_message_header(
        header,
        TEMPLATE_FRAME_DESCRIPTOR,
        FrameDescriptor.sbe_schema_version(FrameDescriptor.Decoder),
    )
        return false
    end
    FrameDescriptor.wrap!(poller.decoder, buffer, 0; header = header)
    poller.handler(poller, poller.decoder)
    return true
end

function handle_consumer_config!(poller::ConsumerConfigPoller, buffer::AbstractVector{UInt8})
    header = MessageHeader.Decoder(buffer, 0)
    if !matches_message_header(
        header,
        TEMPLATE_CONSUMER_CONFIG,
        ConsumerConfigMsg.sbe_schema_version(ConsumerConfigMsg.Decoder),
    )
        return false
    end
    ConsumerConfigMsg.wrap!(poller.decoder, buffer, 0; header = header)
    poller.handler(poller, poller.decoder)
    return true
end

function handle_frame_progress!(poller::FrameProgressPoller, buffer::AbstractVector{UInt8})
    header = MessageHeader.Decoder(buffer, 0)
    if !matches_message_header(
        header,
        TEMPLATE_FRAME_PROGRESS,
        FrameProgress.sbe_schema_version(FrameProgress.Decoder),
    )
        return false
    end
    FrameProgress.wrap!(poller.decoder, buffer, 0; header = header)
    poller.handler(poller, poller.decoder)
    return true
end
