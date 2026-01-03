using FixedSizeArrays
using StringViews

"""
Fixed-size mutable string buffer backed by a fixed-size byte vector.
"""
struct FixedString <: AbstractString
    buf::FixedSizeVector{UInt8}
end

@inline function FixedString(capacity::Integer)
    return FixedString(FixedSizeVector{UInt8}(undef, Int(capacity)))
end

@inline function fixed_string_capacity(fs::FixedString)
    return length(fs.buf)
end

@inline function fixed_string_len(fs::FixedString)
    pos = findfirst(iszero, fs.buf)
    return pos === nothing ? length(fs.buf) : pos - 1
end

@inline function fixed_string_clear!(fs::FixedString)
    isempty(fs.buf) && return nothing
    fs.buf[1] = 0x00
    return nothing
end

@inline function fixed_string_set!(fs::FixedString, value::AbstractString)
    len = ncodeunits(value)
    cap = length(fs.buf)
    len <= cap || throw(ArgumentError("string length $(len) exceeds max $(cap)"))
    if len > 0
        copyto!(fs.buf, 1, codeunits(value), 1, len)
        if len < cap
            fs.buf[len + 1] = 0x00
        end
    else
        fs.buf[1] = 0x00
    end
    return nothing
end

@inline function fixed_string_view(fs::FixedString)
    len = fixed_string_len(fs)
    len == 0 && return StringView("")
    return StringView(view(fs.buf, 1:len))
end

@inline function fixed_string_string(fs::FixedString)
    return String(fixed_string_view(fs))
end

Base.codeunit(::Type{FixedString}) = UInt8
Base.codeunit(::FixedString) = UInt8
Base.ncodeunits(fs::FixedString) = fixed_string_len(fs)
Base.length(fs::FixedString) = fixed_string_len(fs)
Base.isempty(fs::FixedString) = fixed_string_len(fs) == 0

Base.iterate(fs::FixedString) = iterate(fixed_string_view(fs))
Base.iterate(fs::FixedString, state) = iterate(fixed_string_view(fs), state)
Base.getindex(fs::FixedString, i::Int) = fixed_string_view(fs)[i]
Base.thisind(fs::FixedString, i::Int) = thisind(fixed_string_view(fs), i)
Base.nextind(fs::FixedString, i::Int) = nextind(fixed_string_view(fs), i)
Base.prevind(fs::FixedString, i::Int) = prevind(fixed_string_view(fs), i)
Base.isvalid(fs::FixedString, i::Int) = isvalid(fixed_string_view(fs), i)
Base.String(fs::FixedString) = fixed_string_string(fs)

Base.@propagate_inbounds function Base.setindex!(fs::FixedString, value::UInt8, i::Int)
    fs.buf[i] = value
    return fs
end
