"""
Try to claim an Aeron buffer using do-block syntax and fill it.

Arguments:
- `fill_fn`: callback invoked with the claimed buffer.
- `pub`: Aeron publication.
- `claim`: reusable Aeron.BufferClaim.
- `length`: number of bytes to claim.

Returns:
- `true` if the claim was committed, `false` otherwise.
"""
@inline function publication_result_name(position::Int64)
    position == Aeron.PUBLICATION_NOT_CONNECTED && return :not_connected
    position == Aeron.PUBLICATION_BACK_PRESSURED && return :back_pressured
    position == Aeron.PUBLICATION_ADMIN_ACTION && return :admin_action
    position == Aeron.PUBLICATION_CLOSED && return :closed
    position == Aeron.PUBLICATION_MAX_POSITION_EXCEEDED && return :max_position_exceeded
    position == Aeron.PUBLICATION_ERROR && return :error
    return :unknown
end

function with_claimed_buffer!(
    fill_fn,
    pub::Aeron.Publication,
    claim::Aeron.BufferClaim,
    length::Int,
)
    position = Aeron.try_claim(pub, length, claim)
    if position >= 0
        buf = Aeron.buffer(claim)
        fill_fn(buf)
        Aeron.commit(claim)
        return true
    end
    @tp_debug "with_claimed_buffer failed" position = position result = publication_result_name(position) length =
        length max_payload_length =
        Aeron.max_payload_length(pub) max_message_length = Aeron.max_message_length(pub) connected =
        Aeron.is_connected(pub) channel_status = Aeron.channel_status(pub) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(pub) channel = Aeron.channel(pub) stream_id = Aeron.stream_id(pub)
    return false
end

"""
Set Aeron directory if non-empty.
"""
function set_aeron_dir!(ctx::Aeron.Context, aeron_dir::AbstractString)
    isempty(aeron_dir) || Aeron.aeron_dir!(ctx, aeron_dir)
    return nothing
end

function log_publication_ready(label::AbstractString, pub::Aeron.Publication, stream_id::Integer)
    @tp_info "$(label) publication ready" stream_id = stream_id channel = Aeron.channel(pub) max_payload_length =
        Aeron.max_payload_length(pub) max_message_length = Aeron.max_message_length(pub) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(pub)
    return nothing
end

function log_subscription_ready(label::AbstractString, sub::Aeron.Subscription, stream_id::Integer)
    @tp_info "$(label) subscription ready" stream_id = stream_id channel = Aeron.channel(sub) channel_status_indicator_id =
        Aeron.channel_status_indicator_id(sub)
    return nothing
end
