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
