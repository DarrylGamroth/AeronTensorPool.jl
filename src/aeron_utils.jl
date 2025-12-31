@inline function try_claim_sbe!(pub::Aeron.Publication, claim::Aeron.BufferClaim, length::Int, fill_fn::Function)
    position = Aeron.try_claim(pub, length, claim)
    if position > 0
        buf = Aeron.buffer(claim)
        fill_fn(buf)
        Aeron.commit(claim)
        return true
    end
    return false
end

@inline function sbe_message_length(msg::SBE.AbstractSbeMessage)
    return MESSAGE_HEADER_LEN + sbe_encoded_length(msg)
end

@inline function set_aeron_dir!(ctx::Aeron.Context, aeron_dir::AbstractString)
    isempty(aeron_dir) || Aeron.aeron_dir!(ctx, aeron_dir)
    return nothing
end
