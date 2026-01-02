"""
Try to claim an Aeron buffer using do-block syntax and fill it with an SBE message.
"""
@inline function try_claim_sbe!(fill_fn::F, pub::Aeron.Publication, claim::Aeron.BufferClaim, length::Int) where {F}
    position = Aeron.try_claim(pub, length, claim)
    if position > 0
        buf = Aeron.buffer(claim)
        fill_fn(buf)
        Aeron.commit(claim)
        return true
    end
    return false
end

"""
Try to claim an Aeron buffer and fill it with raw payload bytes.
"""
@inline function try_claim_payload!(pub::Aeron.Publication, claim::Aeron.BufferClaim, payload::AbstractVector{UInt8})
    length = Int(sizeof(payload))
    position = Aeron.try_claim(pub, length, claim)
    if position > 0
        buf = Aeron.buffer(claim)
        copyto!(buf, 1, payload, 1, length)
        Aeron.commit(claim)
        return true
    end
    return false
end

"""
Return full SBE message length (header + body) for an encoder/decoder.
"""
@inline function sbe_message_length(msg::SBE.AbstractSbeMessage)
    return MESSAGE_HEADER_LEN + sbe_encoded_length(msg)
end

"""
Set Aeron directory if non-empty.
"""
@inline function set_aeron_dir!(ctx::Aeron.Context, aeron_dir::AbstractString)
    isempty(aeron_dir) || Aeron.aeron_dir!(ctx, aeron_dir)
    return nothing
end

"""
Create or reuse an Aeron context/client pair.
"""
function acquire_aeron(
    aeron_dir::AbstractString;
    ctx::Union{Nothing, Aeron.Context} = nothing,
    client::Union{Nothing, Aeron.Client} = nothing,
)
    if client !== nothing
        return client.context, client, false, false
    end
    if ctx === nothing
        ctx = Aeron.Context()
        set_aeron_dir!(ctx, aeron_dir)
        return ctx, Aeron.Client(ctx), true, true
    end
    set_aeron_dir!(ctx, aeron_dir)
    return ctx, Aeron.Client(ctx), false, true
end
