"""
Snowflake-based trace ID generator wrapper.
"""
struct TraceIdGenerator{C<:Clocks.AbstractClock}
    gen::SnowflakeId.SnowflakeIdGenerator{C}
end

"""
Create a TraceIdGenerator with the given node ID and clock.
"""
function TraceIdGenerator(node_id::Integer, clock::Clocks.AbstractClock = Clocks.EpochClock())
    gen = SnowflakeId.SnowflakeIdGenerator(Int64(node_id), clock)
    return TraceIdGenerator(gen)
end

"""
Create a TraceIdGenerator using a driver client assigned node ID.
"""
function TraceIdGenerator(state::DriverClientState, clock::Clocks.AbstractClock = Clocks.EpochClock())
    state.node_id != 0 || throw(ArgumentError("driver client node_id not set"))
    return TraceIdGenerator(state.node_id, clock)
end

"""
Create a TraceIdGenerator using a producer handle's driver client node ID.
"""
TraceIdGenerator(handle::ProducerHandle, clock::Clocks.AbstractClock = Clocks.EpochClock()) =
    TraceIdGenerator(handle.driver_client, clock)

"""
Generate the next trace ID.
"""
next_trace_id!(generator::TraceIdGenerator) = UInt64(SnowflakeId.next_id(generator.gen))

"""
TraceLinkSet publisher for control-plane causal links.
"""
mutable struct TraceLinkPublisher
    pub::Aeron.Publication
    claim::Aeron.BufferClaim
    encoder::TraceLinkSet.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    stream_id::UInt32
    epoch::UInt64
end

"""
Create a TraceLinkPublisher with explicit publication settings.
"""
function TraceLinkPublisher(pub::Aeron.Publication, stream_id::UInt32, epoch::UInt64)
    return TraceLinkPublisher(
        pub,
        Aeron.BufferClaim(),
        TraceLinkSet.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        stream_id,
        epoch,
    )
end

"""
Create a TraceLinkPublisher from a ProducerHandle.
"""
TraceLinkPublisher(handle::ProducerHandle) = TraceLinkPublisher(handle_state(handle))

"""
Create a TraceLinkPublisher from a ProducerState.
"""
function TraceLinkPublisher(state::ProducerState)
    return TraceLinkPublisher(
        state.runtime.control.pub_control,
        state.config.stream_id,
        state.epoch,
    )
end

"""
Tracing context for producer-side TraceLink usage.
"""
struct TraceLinkContext
    generator::TraceIdGenerator
    publisher::TraceLinkPublisher
end

"""
Update the epoch used by a TraceLinkPublisher.
"""
function update_epoch!(publisher::TraceLinkPublisher, epoch::UInt64)
    publisher.epoch = epoch
    return nothing
end

@inline function valid_trace_parents(parents::AbstractVector{UInt64})
    count = length(parents)
    count == 0 && return false
    @inbounds for i in 1:count
        id = parents[i]
        id == 0 && return false
        for j in i + 1:count
            if parents[j] == id
                return false
            end
        end
    end
    return true
end

"""
Encode TraceLinkSet fields into an encoder.

Returns `true` if the input was valid, `false` otherwise.

Note: callers must wrap the encoder (e.g., via `wrap_and_apply_header!`) before calling.
"""
function encode_tracelink_set!(
    encoder::TraceLinkSet.Encoder,
    stream_id::UInt32,
    epoch::UInt64,
    seq::UInt64,
    trace_id::UInt64,
    parents::AbstractVector{UInt64},
)
    trace_id == 0 && return false
    valid_trace_parents(parents) || return false
    TraceLinkSet.streamId!(encoder, stream_id)
    TraceLinkSet.epoch!(encoder, epoch)
    TraceLinkSet.seq!(encoder, seq)
    TraceLinkSet.traceId!(encoder, trace_id)
    group = TraceLinkSet.parents!(encoder, length(parents))
    for parent_id in parents
        entry = TraceLinkSet.Parents.next!(group)
        TraceLinkSet.Parents.traceId!(entry, parent_id)
    end
    return true
end

"""
Resolve a node ID from explicit input or a driver client.
"""
function resolve_node_id(
    node_id::Union{UInt32, Nothing},
    driver_client::Union{DriverClientState, Nothing},
)
    if !isnothing(node_id)
        return node_id
    end
    if !isnothing(driver_client) && driver_client.node_id != 0
        return driver_client.node_id
    end
    throw(ArgumentError("node_id missing; pass node_id explicitly or attach to a driver that assigns one"))
end

"""
Create TraceLink generator/publisher pair for a producer handle.
"""
function enable_tracing!(
    handle::ProducerHandle;
    node_id::Union{UInt32, Nothing} = nothing,
    clock::Clocks.AbstractClock = Clocks.EpochClock(),
)
    resolved = resolve_node_id(node_id, handle.driver_client)
    generator = TraceIdGenerator(resolved, clock)
    publisher = TraceLinkPublisher(handle)
    return TraceLinkContext(generator, publisher)
end

"""
Create TraceLink generator/publisher pair for a producer state.
"""
function enable_tracing!(
    state::ProducerState;
    node_id::Union{UInt32, Nothing} = nothing,
    clock::Clocks.AbstractClock = Clocks.EpochClock(),
)
    resolved = resolve_node_id(node_id, state.driver_client)
    generator = TraceIdGenerator(resolved, clock)
    publisher = TraceLinkPublisher(state)
    return TraceLinkContext(generator, publisher)
end

"""
Return the output trace ID for the given parents.

For 1→1 flows, the parent trace ID is reused; for N→1 flows, a new trace ID is minted.
Returns 0 on invalid parents.
"""
function trace_id_for_output!(generator::TraceIdGenerator, parents::AbstractVector{UInt64})
    valid_trace_parents(parents) || return UInt64(0)
    if length(parents) == 1
        return parents[1]
    end
    return next_trace_id!(generator)
end

"""
Return a new trace ID for a multi-parent merge.
"""
function new_trace_id_from_parents!(generator::TraceIdGenerator, parents::AbstractVector{UInt64})
    valid_trace_parents(parents) || return UInt64(0)
    length(parents) > 1 || return parents[1]
    return next_trace_id!(generator)
end

"""
Reuse a trace ID for 1→1 processing.
"""
reuse_trace_id(trace_id::UInt64) = trace_id

"""
Emit a TraceLinkSet message with minimal validation.
"""
function emit_tracelink!(
    publisher::TraceLinkPublisher,
    seq::UInt64,
    trace_id::UInt64,
    parents::AbstractVector{UInt64},
)
    return emit_tracelink_set!(publisher, seq, trace_id, parents)
end

"""
Decode a TraceLinkSet from a buffer and apply the header.

Returns `true` if the message schema matches, `false` otherwise.
"""
function decode_tracelink_set!(
    decoder::TraceLinkSet.Decoder,
    buffer::AbstractVector{UInt8},
    offset::Int = 0,
)
    header = TraceLinkMessageHeader.Decoder(buffer, offset)
    TraceLinkMessageHeader.schemaId(header) ==
        TraceLinkMessageHeader.sbe_schema_id(TraceLinkMessageHeader.Decoder) || return false
    TraceLinkMessageHeader.templateId(header) ==
        TraceLinkSet.sbe_template_id(TraceLinkSet.Decoder) || return false
    TraceLinkSet.wrap!(decoder, buffer, offset; header = header)
    return true
end

"""
Emit a TraceLinkSet message linking an output trace to parent trace IDs.

Arguments:
- `publisher`: TraceLink publisher.
- `seq`: output sequence number.
- `trace_id`: output trace ID (must be non-zero).
- `parents`: parent trace IDs (length >= 1, unique, non-zero).

Returns:
- `true` if committed, `false` otherwise.
"""
function emit_tracelink_set!(
    publisher::TraceLinkPublisher,
    seq::UInt64,
    trace_id::UInt64,
    parents::AbstractVector{UInt64},
)
    trace_id == 0 && return false
    valid_trace_parents(parents) || return false
    parent_count = length(parents)
    msg_len = TRACELINK_MESSAGE_HEADER_LEN +
        Int(TraceLinkSet.sbe_block_length(TraceLinkSet.Decoder)) +
        Int(TraceLinkSet.Parents.sbe_header_size(TraceLinkSet.Parents.Decoder)) +
        parent_count * Int(TraceLinkSet.Parents.sbe_block_length(TraceLinkSet.Parents.Decoder))

    sent = let pub = publisher, seq = seq, trace_id = trace_id, parents = parents
        with_claimed_buffer!(pub.pub, pub.claim, msg_len) do buf
            TraceLinkSet.wrap_and_apply_header!(pub.encoder, buf, 0)
            encode_tracelink_set!(pub.encoder, pub.stream_id, pub.epoch, seq, trace_id, parents) || return nothing
        end
    end
    return sent
end
