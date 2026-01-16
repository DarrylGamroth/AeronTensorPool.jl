module ShmTensorpoolBridge
using EnumX
using StringViews
@inline function rstrip_nul(a::Union{AbstractString, AbstractArray})
        pos = findfirst(iszero, a)
        len = if pos !== nothing
                pos - 1
            else
                Base.length(a)
            end
        return view(a, 1:len)
    end
@enumx T = SbeEnum Bool_::UInt8 begin
        FALSE = 0
        TRUE = 1
        NULL_VALUE = UInt8(255)
    end
module MessageHeader
using SBE: AbstractSbeCompositeType, AbstractSbeEncodedType
import SBE: id, since_version, encoding_offset, encoding_length, null_value, min_value, max_value
import SBE: value, value!
import SBE: sbe_buffer, sbe_offset, sbe_acting_version, sbe_encoded_length
import SBE: sbe_schema_id, sbe_schema_version
using MappedArrays: mappedarray
nothing
begin
    import SBE: encode_value_le, decode_value_le, encode_array_le, decode_array_le
    const encode_value = encode_value_le
    const decode_value = decode_value_le
    const encode_array = encode_array_le
    const decode_array = decode_array_le
end
abstract type AbstractMessageHeader <: AbstractSbeCompositeType end
struct Decoder{T <: AbstractArray{UInt8}} <: AbstractMessageHeader
    buffer::T
    offset::Int64
    acting_version::UInt16
end
struct Encoder{T <: AbstractArray{UInt8}} <: AbstractMessageHeader
    buffer::T
    offset::Int64
end
@inline function Decoder(buffer::AbstractArray{UInt8})
        Decoder(buffer, Int64(0), UInt16(1))
    end
@inline function Decoder(buffer::AbstractArray{UInt8}, offset::Integer)
        Decoder(buffer, Int64(offset), UInt16(1))
    end
@inline function Encoder(buffer::AbstractArray{UInt8})
        Encoder(buffer, Int64(0))
    end
sbe_buffer(m::AbstractMessageHeader) = begin
        m.buffer
    end
sbe_offset(m::AbstractMessageHeader) = begin
        m.offset
    end
sbe_encoded_length(::AbstractMessageHeader) = begin
        UInt16(8)
    end
sbe_encoded_length(::Type{<:AbstractMessageHeader}) = begin
        UInt16(8)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractMessageHeader) = begin
        UInt16(902)
    end
sbe_schema_id(::Type{<:AbstractMessageHeader}) = begin
        UInt16(902)
    end
sbe_schema_version(::AbstractMessageHeader) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractMessageHeader}) = begin
        UInt16(1)
    end
Base.sizeof(m::AbstractMessageHeader) = begin
        sbe_encoded_length(m)
    end
function Base.convert(::Type{<:AbstractArray{UInt8}}, m::AbstractMessageHeader)
    return view(m.buffer, m.offset + 1:m.offset + sbe_encoded_length(m))
end
function Base.show(io::IO, m::AbstractMessageHeader)
    print(io, "MessageHeader", "(offset=", m.offset, ", size=", sbe_encoded_length(m), ")")
end
begin
    blockLength_id(::AbstractMessageHeader) = begin
            UInt16(0xffff)
        end
    blockLength_id(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0xffff)
        end
    blockLength_since_version(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    blockLength_since_version(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    blockLength_in_acting_version(m::AbstractMessageHeader) = begin
            m.acting_version >= UInt16(0)
        end
    blockLength_encoding_offset(::AbstractMessageHeader) = begin
            Int(0)
        end
    blockLength_encoding_offset(::Type{<:AbstractMessageHeader}) = begin
            Int(0)
        end
    blockLength_encoding_length(::AbstractMessageHeader) = begin
            Int(2)
        end
    blockLength_encoding_length(::Type{<:AbstractMessageHeader}) = begin
            Int(2)
        end
    blockLength_null_value(::AbstractMessageHeader) = begin
            UInt16(65535)
        end
    blockLength_null_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65535)
        end
    blockLength_min_value(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    blockLength_min_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    blockLength_max_value(::AbstractMessageHeader) = begin
            UInt16(65534)
        end
    blockLength_max_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65534)
        end
end
begin
    @inline function blockLength(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 0)
        end
    @inline blockLength!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 0, val)
            end
    export blockLength, blockLength!
end
begin
    templateId_id(::AbstractMessageHeader) = begin
            UInt16(0xffff)
        end
    templateId_id(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0xffff)
        end
    templateId_since_version(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    templateId_since_version(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    templateId_in_acting_version(m::AbstractMessageHeader) = begin
            m.acting_version >= UInt16(0)
        end
    templateId_encoding_offset(::AbstractMessageHeader) = begin
            Int(2)
        end
    templateId_encoding_offset(::Type{<:AbstractMessageHeader}) = begin
            Int(2)
        end
    templateId_encoding_length(::AbstractMessageHeader) = begin
            Int(2)
        end
    templateId_encoding_length(::Type{<:AbstractMessageHeader}) = begin
            Int(2)
        end
    templateId_null_value(::AbstractMessageHeader) = begin
            UInt16(65535)
        end
    templateId_null_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65535)
        end
    templateId_min_value(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    templateId_min_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    templateId_max_value(::AbstractMessageHeader) = begin
            UInt16(65534)
        end
    templateId_max_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65534)
        end
end
begin
    @inline function templateId(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 2)
        end
    @inline templateId!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 2, val)
            end
    export templateId, templateId!
end
begin
    schemaId_id(::AbstractMessageHeader) = begin
            UInt16(0xffff)
        end
    schemaId_id(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0xffff)
        end
    schemaId_since_version(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    schemaId_since_version(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    schemaId_in_acting_version(m::AbstractMessageHeader) = begin
            m.acting_version >= UInt16(0)
        end
    schemaId_encoding_offset(::AbstractMessageHeader) = begin
            Int(4)
        end
    schemaId_encoding_offset(::Type{<:AbstractMessageHeader}) = begin
            Int(4)
        end
    schemaId_encoding_length(::AbstractMessageHeader) = begin
            Int(2)
        end
    schemaId_encoding_length(::Type{<:AbstractMessageHeader}) = begin
            Int(2)
        end
    schemaId_null_value(::AbstractMessageHeader) = begin
            UInt16(65535)
        end
    schemaId_null_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65535)
        end
    schemaId_min_value(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    schemaId_min_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    schemaId_max_value(::AbstractMessageHeader) = begin
            UInt16(65534)
        end
    schemaId_max_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65534)
        end
end
begin
    @inline function schemaId(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 4)
        end
    @inline schemaId!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 4, val)
            end
    export schemaId, schemaId!
end
begin
    version_id(::AbstractMessageHeader) = begin
            UInt16(0xffff)
        end
    version_id(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0xffff)
        end
    version_since_version(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    version_since_version(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    version_in_acting_version(m::AbstractMessageHeader) = begin
            m.acting_version >= UInt16(0)
        end
    version_encoding_offset(::AbstractMessageHeader) = begin
            Int(6)
        end
    version_encoding_offset(::Type{<:AbstractMessageHeader}) = begin
            Int(6)
        end
    version_encoding_length(::AbstractMessageHeader) = begin
            Int(2)
        end
    version_encoding_length(::Type{<:AbstractMessageHeader}) = begin
            Int(2)
        end
    version_null_value(::AbstractMessageHeader) = begin
            UInt16(65535)
        end
    version_null_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65535)
        end
    version_min_value(::AbstractMessageHeader) = begin
            UInt16(0)
        end
    version_min_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(0)
        end
    version_max_value(::AbstractMessageHeader) = begin
            UInt16(65534)
        end
    version_max_value(::Type{<:AbstractMessageHeader}) = begin
            UInt16(65534)
        end
end
begin
    @inline function version(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 6)
        end
    @inline version!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 6, val)
            end
    export version, version!
end
export AbstractMessageHeader, Decoder, Encoder
end
module VarDataEncoding
using SBE: AbstractSbeCompositeType, AbstractSbeEncodedType
import SBE: id, since_version, encoding_offset, encoding_length, null_value, min_value, max_value
import SBE: value, value!
import SBE: sbe_buffer, sbe_offset, sbe_acting_version, sbe_encoded_length
import SBE: sbe_schema_id, sbe_schema_version
using MappedArrays: mappedarray
nothing
begin
    import SBE: encode_value_le, decode_value_le, encode_array_le, decode_array_le
    const encode_value = encode_value_le
    const decode_value = decode_value_le
    const encode_array = encode_array_le
    const decode_array = decode_array_le
end
abstract type AbstractVarDataEncoding <: AbstractSbeCompositeType end
struct Decoder{T <: AbstractArray{UInt8}} <: AbstractVarDataEncoding
    buffer::T
    offset::Int64
    acting_version::UInt16
end
struct Encoder{T <: AbstractArray{UInt8}} <: AbstractVarDataEncoding
    buffer::T
    offset::Int64
end
@inline function Decoder(buffer::AbstractArray{UInt8})
        Decoder(buffer, Int64(0), UInt16(1))
    end
@inline function Decoder(buffer::AbstractArray{UInt8}, offset::Integer)
        Decoder(buffer, Int64(offset), UInt16(1))
    end
@inline function Encoder(buffer::AbstractArray{UInt8})
        Encoder(buffer, Int64(0))
    end
sbe_buffer(m::AbstractVarDataEncoding) = begin
        m.buffer
    end
sbe_offset(m::AbstractVarDataEncoding) = begin
        m.offset
    end
sbe_encoded_length(::AbstractVarDataEncoding) = begin
        UInt16(-1)
    end
sbe_encoded_length(::Type{<:AbstractVarDataEncoding}) = begin
        UInt16(-1)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractVarDataEncoding) = begin
        UInt16(902)
    end
sbe_schema_id(::Type{<:AbstractVarDataEncoding}) = begin
        UInt16(902)
    end
sbe_schema_version(::AbstractVarDataEncoding) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractVarDataEncoding}) = begin
        UInt16(1)
    end
Base.sizeof(m::AbstractVarDataEncoding) = begin
        sbe_encoded_length(m)
    end
function Base.convert(::Type{<:AbstractArray{UInt8}}, m::AbstractVarDataEncoding)
    return view(m.buffer, m.offset + 1:m.offset + sbe_encoded_length(m))
end
function Base.show(io::IO, m::AbstractVarDataEncoding)
    print(io, "VarDataEncoding", "(offset=", m.offset, ", size=", sbe_encoded_length(m), ")")
end
begin
    length_id(::AbstractVarDataEncoding) = begin
            UInt16(0xffff)
        end
    length_id(::Type{<:AbstractVarDataEncoding}) = begin
            UInt16(0xffff)
        end
    length_since_version(::AbstractVarDataEncoding) = begin
            UInt16(0)
        end
    length_since_version(::Type{<:AbstractVarDataEncoding}) = begin
            UInt16(0)
        end
    length_in_acting_version(m::AbstractVarDataEncoding) = begin
            m.acting_version >= UInt16(0)
        end
    length_encoding_offset(::AbstractVarDataEncoding) = begin
            Int(0)
        end
    length_encoding_offset(::Type{<:AbstractVarDataEncoding}) = begin
            Int(0)
        end
    length_encoding_length(::AbstractVarDataEncoding) = begin
            Int(4)
        end
    length_encoding_length(::Type{<:AbstractVarDataEncoding}) = begin
            Int(4)
        end
    length_null_value(::AbstractVarDataEncoding) = begin
            UInt32(4294967295)
        end
    length_null_value(::Type{<:AbstractVarDataEncoding}) = begin
            UInt32(4294967295)
        end
    length_min_value(::AbstractVarDataEncoding) = begin
            UInt32(0)
        end
    length_min_value(::Type{<:AbstractVarDataEncoding}) = begin
            UInt32(0)
        end
    length_max_value(::AbstractVarDataEncoding) = begin
            UInt32(1073741824)
        end
    length_max_value(::Type{<:AbstractVarDataEncoding}) = begin
            UInt32(1073741824)
        end
end
begin
    @inline function length(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline length!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export length, length!
end
begin
    varData_id(::AbstractVarDataEncoding) = begin
            UInt16(0xffff)
        end
    varData_id(::Type{<:AbstractVarDataEncoding}) = begin
            UInt16(0xffff)
        end
    varData_since_version(::AbstractVarDataEncoding) = begin
            UInt16(0)
        end
    varData_since_version(::Type{<:AbstractVarDataEncoding}) = begin
            UInt16(0)
        end
    varData_in_acting_version(m::AbstractVarDataEncoding) = begin
            m.acting_version >= UInt16(0)
        end
    varData_encoding_offset(::AbstractVarDataEncoding) = begin
            Int(4)
        end
    varData_encoding_offset(::Type{<:AbstractVarDataEncoding}) = begin
            Int(4)
        end
    varData_encoding_length(::AbstractVarDataEncoding) = begin
            Int(-1)
        end
    varData_encoding_length(::Type{<:AbstractVarDataEncoding}) = begin
            Int(-1)
        end
    varData_null_value(::AbstractVarDataEncoding) = begin
            UInt8(255)
        end
    varData_null_value(::Type{<:AbstractVarDataEncoding}) = begin
            UInt8(255)
        end
    varData_min_value(::AbstractVarDataEncoding) = begin
            UInt8(0)
        end
    varData_min_value(::Type{<:AbstractVarDataEncoding}) = begin
            UInt8(0)
        end
    varData_max_value(::AbstractVarDataEncoding) = begin
            UInt8(254)
        end
    varData_max_value(::Type{<:AbstractVarDataEncoding}) = begin
            UInt8(254)
        end
end
begin
    @inline function varData(m::Decoder)
            return decode_value(UInt8, m.buffer, m.offset + 4)
        end
    @inline varData!(m::Encoder, val) = begin
                encode_value(UInt8, m.buffer, m.offset + 4, val)
            end
    export varData, varData!
end
export AbstractVarDataEncoding, Decoder, Encoder
end
module VarDataEncoding256
using SBE: AbstractSbeCompositeType, AbstractSbeEncodedType
import SBE: id, since_version, encoding_offset, encoding_length, null_value, min_value, max_value
import SBE: value, value!
import SBE: sbe_buffer, sbe_offset, sbe_acting_version, sbe_encoded_length
import SBE: sbe_schema_id, sbe_schema_version
using MappedArrays: mappedarray
nothing
begin
    import SBE: encode_value_le, decode_value_le, encode_array_le, decode_array_le
    const encode_value = encode_value_le
    const decode_value = decode_value_le
    const encode_array = encode_array_le
    const decode_array = decode_array_le
end
abstract type AbstractVarDataEncoding256 <: AbstractSbeCompositeType end
struct Decoder{T <: AbstractArray{UInt8}} <: AbstractVarDataEncoding256
    buffer::T
    offset::Int64
    acting_version::UInt16
end
struct Encoder{T <: AbstractArray{UInt8}} <: AbstractVarDataEncoding256
    buffer::T
    offset::Int64
end
@inline function Decoder(buffer::AbstractArray{UInt8})
        Decoder(buffer, Int64(0), UInt16(1))
    end
@inline function Decoder(buffer::AbstractArray{UInt8}, offset::Integer)
        Decoder(buffer, Int64(offset), UInt16(1))
    end
@inline function Encoder(buffer::AbstractArray{UInt8})
        Encoder(buffer, Int64(0))
    end
sbe_buffer(m::AbstractVarDataEncoding256) = begin
        m.buffer
    end
sbe_offset(m::AbstractVarDataEncoding256) = begin
        m.offset
    end
sbe_encoded_length(::AbstractVarDataEncoding256) = begin
        UInt16(-1)
    end
sbe_encoded_length(::Type{<:AbstractVarDataEncoding256}) = begin
        UInt16(-1)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractVarDataEncoding256) = begin
        UInt16(902)
    end
sbe_schema_id(::Type{<:AbstractVarDataEncoding256}) = begin
        UInt16(902)
    end
sbe_schema_version(::AbstractVarDataEncoding256) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractVarDataEncoding256}) = begin
        UInt16(1)
    end
Base.sizeof(m::AbstractVarDataEncoding256) = begin
        sbe_encoded_length(m)
    end
function Base.convert(::Type{<:AbstractArray{UInt8}}, m::AbstractVarDataEncoding256)
    return view(m.buffer, m.offset + 1:m.offset + sbe_encoded_length(m))
end
function Base.show(io::IO, m::AbstractVarDataEncoding256)
    print(io, "VarDataEncoding256", "(offset=", m.offset, ", size=", sbe_encoded_length(m), ")")
end
begin
    length_id(::AbstractVarDataEncoding256) = begin
            UInt16(0xffff)
        end
    length_id(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt16(0xffff)
        end
    length_since_version(::AbstractVarDataEncoding256) = begin
            UInt16(0)
        end
    length_since_version(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt16(0)
        end
    length_in_acting_version(m::AbstractVarDataEncoding256) = begin
            m.acting_version >= UInt16(0)
        end
    length_encoding_offset(::AbstractVarDataEncoding256) = begin
            Int(0)
        end
    length_encoding_offset(::Type{<:AbstractVarDataEncoding256}) = begin
            Int(0)
        end
    length_encoding_length(::AbstractVarDataEncoding256) = begin
            Int(4)
        end
    length_encoding_length(::Type{<:AbstractVarDataEncoding256}) = begin
            Int(4)
        end
    length_null_value(::AbstractVarDataEncoding256) = begin
            UInt32(4294967295)
        end
    length_null_value(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt32(4294967295)
        end
    length_min_value(::AbstractVarDataEncoding256) = begin
            UInt32(0)
        end
    length_min_value(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt32(0)
        end
    length_max_value(::AbstractVarDataEncoding256) = begin
            UInt32(256)
        end
    length_max_value(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt32(256)
        end
end
begin
    @inline function length(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline length!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export length, length!
end
begin
    varData_id(::AbstractVarDataEncoding256) = begin
            UInt16(0xffff)
        end
    varData_id(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt16(0xffff)
        end
    varData_since_version(::AbstractVarDataEncoding256) = begin
            UInt16(0)
        end
    varData_since_version(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt16(0)
        end
    varData_in_acting_version(m::AbstractVarDataEncoding256) = begin
            m.acting_version >= UInt16(0)
        end
    varData_encoding_offset(::AbstractVarDataEncoding256) = begin
            Int(4)
        end
    varData_encoding_offset(::Type{<:AbstractVarDataEncoding256}) = begin
            Int(4)
        end
    varData_encoding_length(::AbstractVarDataEncoding256) = begin
            Int(-1)
        end
    varData_encoding_length(::Type{<:AbstractVarDataEncoding256}) = begin
            Int(-1)
        end
    varData_null_value(::AbstractVarDataEncoding256) = begin
            UInt8(255)
        end
    varData_null_value(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt8(255)
        end
    varData_min_value(::AbstractVarDataEncoding256) = begin
            UInt8(0)
        end
    varData_min_value(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt8(0)
        end
    varData_max_value(::AbstractVarDataEncoding256) = begin
            UInt8(254)
        end
    varData_max_value(::Type{<:AbstractVarDataEncoding256}) = begin
            UInt8(254)
        end
end
begin
    @inline function varData(m::Decoder)
            return decode_value(UInt8, m.buffer, m.offset + 4)
        end
    @inline varData!(m::Encoder, val) = begin
                encode_value(UInt8, m.buffer, m.offset + 4, val)
            end
    export varData, varData!
end
export AbstractVarDataEncoding256, Decoder, Encoder
end
module BridgeFrameChunk
export AbstractBridgeFrameChunk, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractBridgeFrameChunk{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Bool_
begin
    import SBE: encode_value_le, decode_value_le, encode_array_le, decode_array_le
    const encode_value = encode_value_le
    const decode_value = decode_value_le
    const encode_array = encode_array_le
    const decode_array = decode_array_le
end
@inline function rstrip_nul(a::Union{AbstractString, AbstractArray})
        pos = findfirst(iszero, a)
        len = if pos !== nothing
                pos - 1
            else
                Base.length(a)
            end
        return view(a, 1:len)
    end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractBridgeFrameChunk{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    acting_block_length::UInt16
    acting_version::UInt16
    function Decoder{T}() where T <: AbstractArray{UInt8}
        obj = new{T}()
        obj.offset = Int64(0)
        obj.position_ptr = PositionPointer()
        obj.acting_block_length = UInt16(0)
        obj.acting_version = UInt16(0)
        return obj
    end
end
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractBridgeFrameChunk{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    function Encoder{T}() where T <: AbstractArray{UInt8}
        obj = new{T}()
        obj.offset = Int64(0)
        obj.position_ptr = PositionPointer()
        return obj
    end
end
@inline function Decoder(::Type{T}) where T <: AbstractArray{UInt8}
        return Decoder{T}()
    end
@inline function Encoder(::Type{T}) where T <: AbstractArray{UInt8}
        return Encoder{T}()
    end
@inline function wrap!(m::Decoder{T}, buffer::T, offset::Integer, acting_block_length::Integer, acting_version::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.acting_block_length = UInt16(acting_block_length)
        m.acting_version = UInt16(acting_version)
        m.position_ptr[] = m.offset + m.acting_block_length
        return m
    end
@inline function wrap!(m::Decoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Decoder(buffer, offset))
        if MessageHeader.templateId(header) != UInt16(1) || MessageHeader.schemaId(header) != UInt16(902)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(53)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(53))
        MessageHeader.templateId!(header, UInt16(1))
        MessageHeader.schemaId!(header, UInt16(902))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractBridgeFrameChunk) = begin
        m.buffer
    end
sbe_offset(m::AbstractBridgeFrameChunk) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractBridgeFrameChunk) = begin
        m.position_ptr
    end
sbe_position(m::AbstractBridgeFrameChunk) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractBridgeFrameChunk, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractBridgeFrameChunk) = begin
        UInt16(53)
    end
sbe_block_length(::Type{<:AbstractBridgeFrameChunk}) = begin
        UInt16(53)
    end
sbe_template_id(::AbstractBridgeFrameChunk) = begin
        UInt16(1)
    end
sbe_template_id(::Type{<:AbstractBridgeFrameChunk}) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractBridgeFrameChunk) = begin
        UInt16(902)
    end
sbe_schema_id(::Type{<:AbstractBridgeFrameChunk}) = begin
        UInt16(902)
    end
sbe_schema_version(::AbstractBridgeFrameChunk) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractBridgeFrameChunk}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractBridgeFrameChunk) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(53)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractBridgeFrameChunk) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractBridgeFrameChunk) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractBridgeFrameChunk) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractBridgeFrameChunk) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractBridgeFrameChunk) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function streamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline streamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export streamId, streamId!
end
begin
    epoch_id(::AbstractBridgeFrameChunk) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractBridgeFrameChunk) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractBridgeFrameChunk) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractBridgeFrameChunk) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function epoch(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 4)
        end
    @inline epoch!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 4, val)
            end
    export epoch, epoch!
end
begin
    seq_id(::AbstractBridgeFrameChunk) = begin
            UInt16(3)
        end
    seq_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(3)
        end
    seq_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    seq_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    seq_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    seq_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(12)
        end
    seq_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(12)
        end
    seq_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(8)
        end
    seq_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(8)
        end
    seq_null_value(::AbstractBridgeFrameChunk) = begin
            UInt64(18446744073709551615)
        end
    seq_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(18446744073709551615)
        end
    seq_min_value(::AbstractBridgeFrameChunk) = begin
            UInt64(0)
        end
    seq_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(0)
        end
    seq_max_value(::AbstractBridgeFrameChunk) = begin
            UInt64(18446744073709551614)
        end
    seq_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function seq_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function seq_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function seq(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 12)
        end
    @inline seq!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 12, val)
            end
    export seq, seq!
end
begin
    traceId_id(::AbstractBridgeFrameChunk) = begin
            UInt16(12)
        end
    traceId_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(12)
        end
    traceId_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    traceId_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    traceId_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    traceId_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(20)
        end
    traceId_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(20)
        end
    traceId_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(8)
        end
    traceId_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(8)
        end
    traceId_null_value(::AbstractBridgeFrameChunk) = begin
            UInt64(18446744073709551615)
        end
    traceId_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(18446744073709551615)
        end
    traceId_min_value(::AbstractBridgeFrameChunk) = begin
            UInt64(0)
        end
    traceId_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(0)
        end
    traceId_max_value(::AbstractBridgeFrameChunk) = begin
            UInt64(18446744073709551614)
        end
    traceId_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function traceId_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function traceId_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function traceId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 20)
        end
    @inline traceId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 20, val)
            end
    export traceId, traceId!
end
begin
    chunkIndex_id(::AbstractBridgeFrameChunk) = begin
            UInt16(4)
        end
    chunkIndex_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(4)
        end
    chunkIndex_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    chunkIndex_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    chunkIndex_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    chunkIndex_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(28)
        end
    chunkIndex_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(28)
        end
    chunkIndex_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    chunkIndex_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    chunkIndex_null_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967295)
        end
    chunkIndex_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967295)
        end
    chunkIndex_min_value(::AbstractBridgeFrameChunk) = begin
            UInt32(0)
        end
    chunkIndex_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(0)
        end
    chunkIndex_max_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967294)
        end
    chunkIndex_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967294)
        end
end
begin
    function chunkIndex_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function chunkIndex_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function chunkIndex(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 28)
        end
    @inline chunkIndex!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 28, val)
            end
    export chunkIndex, chunkIndex!
end
begin
    chunkCount_id(::AbstractBridgeFrameChunk) = begin
            UInt16(5)
        end
    chunkCount_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(5)
        end
    chunkCount_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    chunkCount_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    chunkCount_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    chunkCount_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(32)
        end
    chunkCount_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(32)
        end
    chunkCount_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    chunkCount_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    chunkCount_null_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967295)
        end
    chunkCount_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967295)
        end
    chunkCount_min_value(::AbstractBridgeFrameChunk) = begin
            UInt32(0)
        end
    chunkCount_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(0)
        end
    chunkCount_max_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967294)
        end
    chunkCount_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967294)
        end
end
begin
    function chunkCount_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function chunkCount_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function chunkCount(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 32)
        end
    @inline chunkCount!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 32, val)
            end
    export chunkCount, chunkCount!
end
begin
    chunkOffset_id(::AbstractBridgeFrameChunk) = begin
            UInt16(6)
        end
    chunkOffset_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(6)
        end
    chunkOffset_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    chunkOffset_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    chunkOffset_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    chunkOffset_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(36)
        end
    chunkOffset_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(36)
        end
    chunkOffset_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    chunkOffset_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    chunkOffset_null_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967295)
        end
    chunkOffset_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967295)
        end
    chunkOffset_min_value(::AbstractBridgeFrameChunk) = begin
            UInt32(0)
        end
    chunkOffset_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(0)
        end
    chunkOffset_max_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967294)
        end
    chunkOffset_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967294)
        end
end
begin
    function chunkOffset_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function chunkOffset_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function chunkOffset(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 36)
        end
    @inline chunkOffset!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 36, val)
            end
    export chunkOffset, chunkOffset!
end
begin
    chunkLength_id(::AbstractBridgeFrameChunk) = begin
            UInt16(7)
        end
    chunkLength_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(7)
        end
    chunkLength_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    chunkLength_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    chunkLength_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    chunkLength_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(40)
        end
    chunkLength_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(40)
        end
    chunkLength_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    chunkLength_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    chunkLength_null_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967295)
        end
    chunkLength_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967295)
        end
    chunkLength_min_value(::AbstractBridgeFrameChunk) = begin
            UInt32(0)
        end
    chunkLength_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(0)
        end
    chunkLength_max_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967294)
        end
    chunkLength_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967294)
        end
end
begin
    function chunkLength_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function chunkLength_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function chunkLength(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 40)
        end
    @inline chunkLength!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 40, val)
            end
    export chunkLength, chunkLength!
end
begin
    payloadLength_id(::AbstractBridgeFrameChunk) = begin
            UInt16(8)
        end
    payloadLength_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(8)
        end
    payloadLength_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    payloadLength_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    payloadLength_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    payloadLength_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(44)
        end
    payloadLength_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(44)
        end
    payloadLength_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    payloadLength_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    payloadLength_null_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967295)
        end
    payloadLength_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967295)
        end
    payloadLength_min_value(::AbstractBridgeFrameChunk) = begin
            UInt32(0)
        end
    payloadLength_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(0)
        end
    payloadLength_max_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967294)
        end
    payloadLength_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967294)
        end
end
begin
    function payloadLength_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function payloadLength_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function payloadLength(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 44)
        end
    @inline payloadLength!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 44, val)
            end
    export payloadLength, payloadLength!
end
begin
    payloadCrc32c_id(::AbstractBridgeFrameChunk) = begin
            UInt16(13)
        end
    payloadCrc32c_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(13)
        end
    payloadCrc32c_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    payloadCrc32c_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    payloadCrc32c_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    payloadCrc32c_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(48)
        end
    payloadCrc32c_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(48)
        end
    payloadCrc32c_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(4)
        end
    payloadCrc32c_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(4)
        end
    payloadCrc32c_null_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967295)
        end
    payloadCrc32c_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967295)
        end
    payloadCrc32c_min_value(::AbstractBridgeFrameChunk) = begin
            UInt32(0)
        end
    payloadCrc32c_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(0)
        end
    payloadCrc32c_max_value(::AbstractBridgeFrameChunk) = begin
            UInt32(4294967294)
        end
    payloadCrc32c_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt32(4294967294)
        end
end
begin
    function payloadCrc32c_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function payloadCrc32c_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function payloadCrc32c(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 48)
        end
    @inline payloadCrc32c!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 48, val)
            end
    export payloadCrc32c, payloadCrc32c!
end
begin
    headerIncluded_id(::AbstractBridgeFrameChunk) = begin
            UInt16(9)
        end
    headerIncluded_id(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(9)
        end
    headerIncluded_since_version(::AbstractBridgeFrameChunk) = begin
            UInt16(0)
        end
    headerIncluded_since_version(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt16(0)
        end
    headerIncluded_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerIncluded_encoding_offset(::AbstractBridgeFrameChunk) = begin
            Int(52)
        end
    headerIncluded_encoding_offset(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(52)
        end
    headerIncluded_encoding_length(::AbstractBridgeFrameChunk) = begin
            Int(1)
        end
    headerIncluded_encoding_length(::Type{<:AbstractBridgeFrameChunk}) = begin
            Int(1)
        end
    headerIncluded_null_value(::AbstractBridgeFrameChunk) = begin
            UInt8(255)
        end
    headerIncluded_null_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt8(255)
        end
    headerIncluded_min_value(::AbstractBridgeFrameChunk) = begin
            UInt8(0)
        end
    headerIncluded_min_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt8(0)
        end
    headerIncluded_max_value(::AbstractBridgeFrameChunk) = begin
            UInt8(254)
        end
    headerIncluded_max_value(::Type{<:AbstractBridgeFrameChunk}) = begin
            UInt8(254)
        end
end
begin
    function headerIncluded_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerIncluded_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerIncluded(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 52)
        end
    @inline function headerIncluded(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 52)
            return Bool_.SbeEnum(raw)
        end
    @inline function headerIncluded!(m::Encoder, value::Bool_.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 52, UInt8(value))
        end
    export headerIncluded, headerIncluded!
end
begin
    function headerBytes_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerBytes_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const headerBytes_id = UInt16(10)
    const headerBytes_since_version = UInt16(0)
    const headerBytes_header_length = 4
    headerBytes_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function headerBytes_length(m::AbstractBridgeFrameChunk)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function headerBytes_length!(m::Encoder, n)
            @boundscheck n > 256 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_headerBytes!(m::Decoder)
            len = headerBytes_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function headerBytes(m::Decoder)
            len = headerBytes_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function headerBytes_buffer!(m::Encoder, len)
            headerBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function headerBytes!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            headerBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function headerBytes!(m::Encoder, src::NTuple)
            len = sizeof(src)
            headerBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function headerBytes!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            headerBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline headerBytes!(m::Encoder, src::Symbol) = begin
                headerBytes!(m, to_string(src))
            end
    @inline headerBytes!(m::Encoder, src::Real) = begin
                headerBytes!(m, Tuple(src))
            end
    @inline headerBytes!(m::Encoder, ::Nothing) = begin
                headerBytes_buffer!(m, 0)
            end
end
begin
    @inline function headerBytes(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(headerBytes(m))))
        end
    @inline function headerBytes(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(headerBytes(m)))
        end
    @inline function headerBytes(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(headerBytes(m, StringView))
        end
    @inline function headerBytes(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, headerBytes(m)))[]
        end
    @inline function headerBytes(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, headerBytes(m))
        end
    @inline function headerBytes(m::Decoder, ::Type{T}) where T <: NTuple
            Base.isconcretetype(T) || throw(ArgumentError("NTuple type must be concrete"))
            elem_type = Base.tuple_type_head(T)
            elem_type <: Real || throw(ArgumentError("NTuple element type must be Real"))
            x = reinterpret(elem_type, headerBytes(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(fieldcount(T)))
        end
    @inline function headerBytes(m::Decoder, ::Type{T}) where T <: Nothing
            skip_headerBytes!(m)
            return nothing
        end
end
begin
    function payloadBytes_meta_attribute(::AbstractBridgeFrameChunk, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function payloadBytes_meta_attribute(::Type{<:AbstractBridgeFrameChunk}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const payloadBytes_id = UInt16(11)
    const payloadBytes_since_version = UInt16(0)
    const payloadBytes_header_length = 4
    payloadBytes_in_acting_version(m::AbstractBridgeFrameChunk) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function payloadBytes_length(m::AbstractBridgeFrameChunk)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function payloadBytes_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_payloadBytes!(m::Decoder)
            len = payloadBytes_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function payloadBytes(m::Decoder)
            len = payloadBytes_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function payloadBytes_buffer!(m::Encoder, len)
            payloadBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function payloadBytes!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            payloadBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function payloadBytes!(m::Encoder, src::NTuple)
            len = sizeof(src)
            payloadBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function payloadBytes!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            payloadBytes_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline payloadBytes!(m::Encoder, src::Symbol) = begin
                payloadBytes!(m, to_string(src))
            end
    @inline payloadBytes!(m::Encoder, src::Real) = begin
                payloadBytes!(m, Tuple(src))
            end
    @inline payloadBytes!(m::Encoder, ::Nothing) = begin
                payloadBytes_buffer!(m, 0)
            end
end
begin
    @inline function payloadBytes(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(payloadBytes(m))))
        end
    @inline function payloadBytes(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(payloadBytes(m)))
        end
    @inline function payloadBytes(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(payloadBytes(m, StringView))
        end
    @inline function payloadBytes(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, payloadBytes(m)))[]
        end
    @inline function payloadBytes(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, payloadBytes(m))
        end
    @inline function payloadBytes(m::Decoder, ::Type{T}) where T <: NTuple
            Base.isconcretetype(T) || throw(ArgumentError("NTuple type must be concrete"))
            elem_type = Base.tuple_type_head(T)
            elem_type <: Real || throw(ArgumentError("NTuple element type must be Real"))
            x = reinterpret(elem_type, payloadBytes(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(fieldcount(T)))
        end
    @inline function payloadBytes(m::Decoder, ::Type{T}) where T <: Nothing
            skip_payloadBytes!(m)
            return nothing
        end
end
@inline function sbe_decoded_length(m::AbstractBridgeFrameChunk)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_headerBytes!(m)
            skip_payloadBytes!(m)
        end
        return
    end
end
end

const Shm_tensorpool_bridge = ShmTensorpoolBridge