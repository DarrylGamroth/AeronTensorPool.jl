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
@inline function with_claimed_buffer!(fill_fn, pub::Aeron.Publication, claim::Aeron.BufferClaim, length::Int)
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
