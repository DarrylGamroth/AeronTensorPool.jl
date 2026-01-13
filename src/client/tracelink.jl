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
    msg_len = MESSAGE_HEADER_LEN +
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
