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

abstract type ControlMessageKind end
struct DescriptorMessageKind <: ControlMessageKind end
struct ConsumerConfigMessageKind <: ControlMessageKind end
struct FrameProgressMessageKind <: ControlMessageKind end

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

@inline control_message_kind(::FrameDescriptorPoller) = DescriptorMessageKind()
@inline control_message_kind(::ConsumerConfigPoller) = ConsumerConfigMessageKind()
@inline control_message_kind(::FrameProgressPoller) = FrameProgressMessageKind()

@inline control_message_template_id(::DescriptorMessageKind) = TEMPLATE_FRAME_DESCRIPTOR
@inline control_message_template_id(::ConsumerConfigMessageKind) = TEMPLATE_CONSUMER_CONFIG
@inline control_message_template_id(::FrameProgressMessageKind) = TEMPLATE_FRAME_PROGRESS

@inline control_message_schema_version(::DescriptorMessageKind) =
    FrameDescriptor.sbe_schema_version(FrameDescriptor.Decoder)
@inline control_message_schema_version(::ConsumerConfigMessageKind) =
    ConsumerConfigMsg.sbe_schema_version(ConsumerConfigMsg.Decoder)
@inline control_message_schema_version(::FrameProgressMessageKind) =
    FrameProgress.sbe_schema_version(FrameProgress.Decoder)

@inline function control_message_wrap!(
    ::DescriptorMessageKind,
    poller::FrameDescriptorPoller,
    buffer::AbstractVector{UInt8},
    header::MessageHeader.Decoder,
)
    FrameDescriptor.wrap!(poller.decoder, buffer, 0; header = header)
    return nothing
end

@inline function control_message_wrap!(
    ::ConsumerConfigMessageKind,
    poller::ConsumerConfigPoller,
    buffer::AbstractVector{UInt8},
    header::MessageHeader.Decoder,
)
    ConsumerConfigMsg.wrap!(poller.decoder, buffer, 0; header = header)
    return nothing
end

@inline function control_message_wrap!(
    ::FrameProgressMessageKind,
    poller::FrameProgressPoller,
    buffer::AbstractVector{UInt8},
    header::MessageHeader.Decoder,
)
    FrameProgress.wrap!(poller.decoder, buffer, 0; header = header)
    return nothing
end

@inline function control_message_dispatch!(::DescriptorMessageKind, poller::FrameDescriptorPoller)
    poller.handler(poller, poller.decoder)
    return nothing
end

@inline function control_message_dispatch!(::ConsumerConfigMessageKind, poller::ConsumerConfigPoller)
    poller.handler(poller, poller.decoder)
    return nothing
end

@inline function control_message_dispatch!(::FrameProgressMessageKind, poller::FrameProgressPoller)
    poller.handler(poller, poller.decoder)
    return nothing
end

@inline function handle_control_message!(poller::AbstractControlPoller, buffer::AbstractVector{UInt8})
    kind = control_message_kind(poller)
    header = MessageHeader.Decoder(buffer, 0)
    if !matches_message_header(
        header,
        control_message_template_id(kind),
        control_message_schema_version(kind),
    )
        return false
    end
    control_message_wrap!(kind, poller, buffer, header)
    control_message_dispatch!(kind, poller)
    return true
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
    return handle_control_message!(poller, buffer)
end

function handle_consumer_config!(poller::ConsumerConfigPoller, buffer::AbstractVector{UInt8})
    return handle_control_message!(poller, buffer)
end

function handle_frame_progress!(poller::FrameProgressPoller, buffer::AbstractVector{UInt8})
    return handle_control_message!(poller, buffer)
end
