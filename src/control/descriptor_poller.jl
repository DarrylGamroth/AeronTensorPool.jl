"""
Helpers for polling FrameDescriptor messages into preallocated buffers.
"""

@inline function descriptor_message_len()
    return FRAME_DESCRIPTOR_LEN
end

function default_descriptor_buffers(fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    count = Int(fragment_limit)
    count >= 0 || throw(ArgumentError("fragment_limit must be non-negative"))
    msg_len = descriptor_message_len()
    buffers = Vector{Vector{UInt8}}(undef, count)
    for i in 1:count
        buffers[i] = Vector{UInt8}(undef, msg_len)
    end
    return buffers
end

"""
Poller that copies FrameDescriptor fragments into preallocated buffers.

Use the subscription-based constructor when the caller owns Aeron resources.
Use the Aeron URI constructor for a self-contained poller that owns context/client.
"""
mutable struct DescriptorPoller{TContext, TClient}
    context::TContext
    client::TClient
    subscription::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
    fragment_limit::Int32
    message_len::Int
    buffers::Vector{Vector{UInt8}}
    count::Base.RefValue{Int}
end

function DescriptorPoller(
    context::TContext,
    client::TClient,
    sub::Aeron.Subscription;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
    buffers::Union{Nothing, Vector{Vector{UInt8}}} = nothing,
) where {TContext, TClient}
    buffers === nothing && (buffers = default_descriptor_buffers(fragment_limit))
    length(buffers) >= fragment_limit || throw(ArgumentError("buffers length < fragment_limit"))
    message_len = isempty(buffers) ? descriptor_message_len() : length(buffers[1])
    count = Ref{Int}(0)
    handler = Aeron.FragmentHandler((buffers, count, message_len)) do state, buffer, _
        bufs = state[1]
        count_ref = state[2]
        msg_len = state[3]
        length(buffer) == msg_len || return nothing
        idx = count_ref[] + 1
        idx <= length(bufs) || return nothing
        copyto!(bufs[idx], 1, buffer, 1, msg_len)
        count_ref[] = idx
        return nothing
    end
    assembler = Aeron.FragmentAssembler(handler)
    return DescriptorPoller{TContext, TClient}(context, client, sub, assembler, fragment_limit, message_len, buffers, count)
end

function DescriptorPoller(
    sub::Aeron.Subscription;
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
    buffers::Union{Nothing, Vector{Vector{UInt8}}} = nothing,
)
    return DescriptorPoller(nothing, nothing, sub; fragment_limit = fragment_limit, buffers = buffers)
end

function DescriptorPoller(
    aeron_uri::AbstractString,
    stream_id::Integer;
    aeron_dir::AbstractString = "",
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
    buffers::Union{Nothing, Vector{Vector{UInt8}}} = nothing,
)
    context = Aeron.Context()
    set_aeron_dir!(context, aeron_dir)
    client = Aeron.Client(context)
    sub = Aeron.add_subscription(client, aeron_uri, stream_id)
    log_subscription_ready("Descriptor", sub, stream_id)
    return DescriptorPoller(context, client, sub; fragment_limit = fragment_limit, buffers = buffers)
end

"""
Poll descriptor fragments into `poller.buffers`.

Returns the number of frames copied.
"""
function poll_descriptors!(poller::DescriptorPoller)
    poller.count[] = 0
    Aeron.poll(poller.subscription, poller.assembler, poller.fragment_limit)
    return poller.count[]
end

function Base.close(poller::DescriptorPoller)
    close(poller.subscription)
    poller.client === nothing || close(poller.client)
    poller.context === nothing || close(poller.context)
    return nothing
end
