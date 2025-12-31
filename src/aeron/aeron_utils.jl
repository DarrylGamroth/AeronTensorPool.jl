"""
Try to claim an Aeron buffer using do-block syntax and fill it with an SBE message.
"""
@inline function try_claim_sbe!(fill_fn::Function, pub::Aeron.Publication, claim::Aeron.BufferClaim, length::Int)
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
