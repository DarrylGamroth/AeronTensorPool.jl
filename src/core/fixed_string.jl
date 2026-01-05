using FixedSizeArrays
using StringViews

"""
Fixed-size mutable string buffer backed by a fixed-size byte vector.
"""
struct FixedString <: AbstractString
    buf::FixedSizeVectorDefault{UInt8}
end

@inline function FixedString(capacity::Integer)
    return FixedString(FixedSizeVectorDefault{UInt8}(undef, Int(capacity)))
end

@inline function Base.view(fs::FixedString)
    len = length(fs)
    len == 0 && return StringView("")
    return StringView(view(fs.buf, 1:len))
end

Base.codeunit(::Type{FixedString}) = UInt8
Base.codeunit(::FixedString) = UInt8
Base.codeunit(fs::FixedString, i::Integer) = fs.buf[i]
Base.ncodeunits(fs::FixedString) = length(fs)
Base.length(fs::FixedString) = (pos = findfirst(iszero, fs.buf); pos === nothing ? length(fs.buf) : pos - 1)
Base.isempty(fs::FixedString) = length(fs) == 0
Base.size(fs::FixedString) = (length(fs),)
Base.empty!(fs::FixedString) = (isempty(fs.buf) || (fs.buf[1] = 0x00); fs)

function Base.copyto!(dest::FixedString, src::AbstractString)
    len = ncodeunits(src)
    cap = length(dest.buf)
    len <= cap || throw(ArgumentError("string length $(len) exceeds max $(cap)"))
    if len > 0
        copyto!(dest.buf, 1, codeunits(src), 1, len)
        if len < cap
            dest.buf[len + 1] = 0x00
        end
    elseif !isempty(dest.buf)
        dest.buf[1] = 0x00
    end
    return dest
end

Base.iterate(fs::FixedString) = iterate(view(fs))
Base.iterate(fs::FixedString, state::Int) = iterate(view(fs), state)
Base.getindex(fs::FixedString, i::Int) = view(fs)[i]
Base.thisind(fs::FixedString, i::Int) = thisind(view(fs), i)
Base.nextind(fs::FixedString, i::Int) = nextind(view(fs), i)
Base.prevind(fs::FixedString, i::Int) = prevind(view(fs), i)
Base.isvalid(fs::FixedString, i::Int) = isvalid(view(fs), i)

Base.@propagate_inbounds function Base.setindex!(fs::FixedString, value::UInt8, i::Int)
    fs.buf[i] = value
    return fs
end
