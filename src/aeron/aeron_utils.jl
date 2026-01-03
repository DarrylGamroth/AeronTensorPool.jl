"""
Try to claim an Aeron buffer using do-block syntax and fill it.
"""
@inline function with_claimed_buffer!(fill_fn::F, pub::Aeron.Publication, claim::Aeron.BufferClaim, length::Int) where {F}
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
Set Aeron directory if non-empty.
"""
@inline function set_aeron_dir!(ctx::Aeron.Context, aeron_dir::AbstractString)
    isempty(aeron_dir) || Aeron.aeron_dir!(ctx, aeron_dir)
    return nothing
end
