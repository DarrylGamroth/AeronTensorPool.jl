module ShmTensorpoolDiscovery
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
@enumx T = SbeEnum DiscoveryStatus::UInt8 begin
        OK = 1
        NOT_FOUND = 2
        ERROR = 3
        NULL_VALUE = UInt8(255)
    end
module GroupSizeEncoding
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
abstract type AbstractGroupSizeEncoding <: AbstractSbeCompositeType end
struct Decoder{T <: AbstractArray{UInt8}} <: AbstractGroupSizeEncoding
    buffer::T
    offset::Int64
    acting_version::UInt16
end
struct Encoder{T <: AbstractArray{UInt8}} <: AbstractGroupSizeEncoding
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
sbe_buffer(m::AbstractGroupSizeEncoding) = begin
        m.buffer
    end
sbe_offset(m::AbstractGroupSizeEncoding) = begin
        m.offset
    end
sbe_encoded_length(::AbstractGroupSizeEncoding) = begin
        UInt16(4)
    end
sbe_encoded_length(::Type{<:AbstractGroupSizeEncoding}) = begin
        UInt16(4)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractGroupSizeEncoding) = begin
        UInt16(910)
    end
sbe_schema_id(::Type{<:AbstractGroupSizeEncoding}) = begin
        UInt16(910)
    end
sbe_schema_version(::AbstractGroupSizeEncoding) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractGroupSizeEncoding}) = begin
        UInt16(1)
    end
Base.sizeof(m::AbstractGroupSizeEncoding) = begin
        sbe_encoded_length(m)
    end
function Base.convert(::Type{<:AbstractArray{UInt8}}, m::AbstractGroupSizeEncoding)
    return view(m.buffer, m.offset + 1:m.offset + sbe_encoded_length(m))
end
function Base.show(io::IO, m::AbstractGroupSizeEncoding)
    print(io, "GroupSizeEncoding", "(offset=", m.offset, ", size=", sbe_encoded_length(m), ")")
end
begin
    blockLength_id(::AbstractGroupSizeEncoding) = begin
            UInt16(0xffff)
        end
    blockLength_id(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(0xffff)
        end
    blockLength_since_version(::AbstractGroupSizeEncoding) = begin
            UInt16(0)
        end
    blockLength_since_version(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(0)
        end
    blockLength_in_acting_version(m::AbstractGroupSizeEncoding) = begin
            m.acting_version >= UInt16(0)
        end
    blockLength_encoding_offset(::AbstractGroupSizeEncoding) = begin
            Int(0)
        end
    blockLength_encoding_offset(::Type{<:AbstractGroupSizeEncoding}) = begin
            Int(0)
        end
    blockLength_encoding_length(::AbstractGroupSizeEncoding) = begin
            Int(2)
        end
    blockLength_encoding_length(::Type{<:AbstractGroupSizeEncoding}) = begin
            Int(2)
        end
    blockLength_null_value(::AbstractGroupSizeEncoding) = begin
            UInt16(65535)
        end
    blockLength_null_value(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(65535)
        end
    blockLength_min_value(::AbstractGroupSizeEncoding) = begin
            UInt16(0)
        end
    blockLength_min_value(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(0)
        end
    blockLength_max_value(::AbstractGroupSizeEncoding) = begin
            UInt16(65534)
        end
    blockLength_max_value(::Type{<:AbstractGroupSizeEncoding}) = begin
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
    numInGroup_id(::AbstractGroupSizeEncoding) = begin
            UInt16(0xffff)
        end
    numInGroup_id(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(0xffff)
        end
    numInGroup_since_version(::AbstractGroupSizeEncoding) = begin
            UInt16(0)
        end
    numInGroup_since_version(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(0)
        end
    numInGroup_in_acting_version(m::AbstractGroupSizeEncoding) = begin
            m.acting_version >= UInt16(0)
        end
    numInGroup_encoding_offset(::AbstractGroupSizeEncoding) = begin
            Int(2)
        end
    numInGroup_encoding_offset(::Type{<:AbstractGroupSizeEncoding}) = begin
            Int(2)
        end
    numInGroup_encoding_length(::AbstractGroupSizeEncoding) = begin
            Int(2)
        end
    numInGroup_encoding_length(::Type{<:AbstractGroupSizeEncoding}) = begin
            Int(2)
        end
    numInGroup_null_value(::AbstractGroupSizeEncoding) = begin
            UInt16(65535)
        end
    numInGroup_null_value(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(65535)
        end
    numInGroup_min_value(::AbstractGroupSizeEncoding) = begin
            UInt16(0)
        end
    numInGroup_min_value(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(0)
        end
    numInGroup_max_value(::AbstractGroupSizeEncoding) = begin
            UInt16(65534)
        end
    numInGroup_max_value(::Type{<:AbstractGroupSizeEncoding}) = begin
            UInt16(65534)
        end
end
begin
    @inline function numInGroup(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 2)
        end
    @inline numInGroup!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 2, val)
            end
    export numInGroup, numInGroup!
end
export AbstractGroupSizeEncoding, Decoder, Encoder
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
        UInt16(910)
    end
sbe_schema_id(::Type{<:AbstractMessageHeader}) = begin
        UInt16(910)
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
module VarAsciiEncoding
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
abstract type AbstractVarAsciiEncoding <: AbstractSbeCompositeType end
struct Decoder{T <: AbstractArray{UInt8}} <: AbstractVarAsciiEncoding
    buffer::T
    offset::Int64
    acting_version::UInt16
end
struct Encoder{T <: AbstractArray{UInt8}} <: AbstractVarAsciiEncoding
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
sbe_buffer(m::AbstractVarAsciiEncoding) = begin
        m.buffer
    end
sbe_offset(m::AbstractVarAsciiEncoding) = begin
        m.offset
    end
sbe_encoded_length(::AbstractVarAsciiEncoding) = begin
        UInt16(-1)
    end
sbe_encoded_length(::Type{<:AbstractVarAsciiEncoding}) = begin
        UInt16(-1)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractVarAsciiEncoding) = begin
        UInt16(910)
    end
sbe_schema_id(::Type{<:AbstractVarAsciiEncoding}) = begin
        UInt16(910)
    end
sbe_schema_version(::AbstractVarAsciiEncoding) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractVarAsciiEncoding}) = begin
        UInt16(1)
    end
Base.sizeof(m::AbstractVarAsciiEncoding) = begin
        sbe_encoded_length(m)
    end
function Base.convert(::Type{<:AbstractArray{UInt8}}, m::AbstractVarAsciiEncoding)
    return view(m.buffer, m.offset + 1:m.offset + sbe_encoded_length(m))
end
function Base.show(io::IO, m::AbstractVarAsciiEncoding)
    print(io, "VarAsciiEncoding", "(offset=", m.offset, ", size=", sbe_encoded_length(m), ")")
end
begin
    length_id(::AbstractVarAsciiEncoding) = begin
            UInt16(0xffff)
        end
    length_id(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt16(0xffff)
        end
    length_since_version(::AbstractVarAsciiEncoding) = begin
            UInt16(0)
        end
    length_since_version(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt16(0)
        end
    length_in_acting_version(m::AbstractVarAsciiEncoding) = begin
            m.acting_version >= UInt16(0)
        end
    length_encoding_offset(::AbstractVarAsciiEncoding) = begin
            Int(0)
        end
    length_encoding_offset(::Type{<:AbstractVarAsciiEncoding}) = begin
            Int(0)
        end
    length_encoding_length(::AbstractVarAsciiEncoding) = begin
            Int(4)
        end
    length_encoding_length(::Type{<:AbstractVarAsciiEncoding}) = begin
            Int(4)
        end
    length_null_value(::AbstractVarAsciiEncoding) = begin
            UInt32(4294967295)
        end
    length_null_value(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt32(4294967295)
        end
    length_min_value(::AbstractVarAsciiEncoding) = begin
            UInt32(0)
        end
    length_min_value(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt32(0)
        end
    length_max_value(::AbstractVarAsciiEncoding) = begin
            UInt32(1073741824)
        end
    length_max_value(::Type{<:AbstractVarAsciiEncoding}) = begin
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
    varData_id(::AbstractVarAsciiEncoding) = begin
            UInt16(0xffff)
        end
    varData_id(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt16(0xffff)
        end
    varData_since_version(::AbstractVarAsciiEncoding) = begin
            UInt16(0)
        end
    varData_since_version(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt16(0)
        end
    varData_in_acting_version(m::AbstractVarAsciiEncoding) = begin
            m.acting_version >= UInt16(0)
        end
    varData_encoding_offset(::AbstractVarAsciiEncoding) = begin
            Int(4)
        end
    varData_encoding_offset(::Type{<:AbstractVarAsciiEncoding}) = begin
            Int(4)
        end
    varData_encoding_length(::AbstractVarAsciiEncoding) = begin
            Int(-1)
        end
    varData_encoding_length(::Type{<:AbstractVarAsciiEncoding}) = begin
            Int(-1)
        end
    varData_null_value(::AbstractVarAsciiEncoding) = begin
            UInt8(255)
        end
    varData_null_value(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt8(255)
        end
    varData_min_value(::AbstractVarAsciiEncoding) = begin
            UInt8(0)
        end
    varData_min_value(::Type{<:AbstractVarAsciiEncoding}) = begin
            UInt8(0)
        end
    varData_max_value(::AbstractVarAsciiEncoding) = begin
            UInt8(254)
        end
    varData_max_value(::Type{<:AbstractVarAsciiEncoding}) = begin
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
export AbstractVarAsciiEncoding, Decoder, Encoder
end
module DiscoveryResponse
export AbstractDiscoveryResponse, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractDiscoveryResponse{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..DiscoveryStatus
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractDiscoveryResponse{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractDiscoveryResponse{T}
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
        if MessageHeader.templateId(header) != UInt16(2) || MessageHeader.schemaId(header) != UInt16(910)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(9)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(9))
        MessageHeader.templateId!(header, UInt16(2))
        MessageHeader.schemaId!(header, UInt16(910))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractDiscoveryResponse) = begin
        m.buffer
    end
sbe_offset(m::AbstractDiscoveryResponse) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractDiscoveryResponse) = begin
        m.position_ptr
    end
sbe_position(m::AbstractDiscoveryResponse) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractDiscoveryResponse, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractDiscoveryResponse) = begin
        UInt16(9)
    end
sbe_block_length(::Type{<:AbstractDiscoveryResponse}) = begin
        UInt16(9)
    end
sbe_template_id(::AbstractDiscoveryResponse) = begin
        UInt16(2)
    end
sbe_template_id(::Type{<:AbstractDiscoveryResponse}) = begin
        UInt16(2)
    end
sbe_schema_id(::AbstractDiscoveryResponse) = begin
        UInt16(910)
    end
sbe_schema_id(::Type{<:AbstractDiscoveryResponse}) = begin
        UInt16(910)
    end
sbe_schema_version(::AbstractDiscoveryResponse) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractDiscoveryResponse}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractDiscoveryResponse) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(9)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractDiscoveryResponse) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractDiscoveryResponse) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractDiscoveryResponse) = begin
        sbe_encoded_length(m)
    end
begin
    requestId_id(::AbstractDiscoveryResponse) = begin
            UInt16(1)
        end
    requestId_id(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt16(1)
        end
    requestId_since_version(::AbstractDiscoveryResponse) = begin
            UInt16(0)
        end
    requestId_since_version(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt16(0)
        end
    requestId_in_acting_version(m::AbstractDiscoveryResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    requestId_encoding_offset(::AbstractDiscoveryResponse) = begin
            Int(0)
        end
    requestId_encoding_offset(::Type{<:AbstractDiscoveryResponse}) = begin
            Int(0)
        end
    requestId_encoding_length(::AbstractDiscoveryResponse) = begin
            Int(8)
        end
    requestId_encoding_length(::Type{<:AbstractDiscoveryResponse}) = begin
            Int(8)
        end
    requestId_null_value(::AbstractDiscoveryResponse) = begin
            UInt64(18446744073709551615)
        end
    requestId_null_value(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt64(18446744073709551615)
        end
    requestId_min_value(::AbstractDiscoveryResponse) = begin
            UInt64(0)
        end
    requestId_min_value(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt64(0)
        end
    requestId_max_value(::AbstractDiscoveryResponse) = begin
            UInt64(18446744073709551614)
        end
    requestId_max_value(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function requestId_meta_attribute(::AbstractDiscoveryResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function requestId_meta_attribute(::Type{<:AbstractDiscoveryResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function requestId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline requestId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export requestId, requestId!
end
begin
    status_id(::AbstractDiscoveryResponse) = begin
            UInt16(2)
        end
    status_id(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt16(2)
        end
    status_since_version(::AbstractDiscoveryResponse) = begin
            UInt16(0)
        end
    status_since_version(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt16(0)
        end
    status_in_acting_version(m::AbstractDiscoveryResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    status_encoding_offset(::AbstractDiscoveryResponse) = begin
            Int(8)
        end
    status_encoding_offset(::Type{<:AbstractDiscoveryResponse}) = begin
            Int(8)
        end
    status_encoding_length(::AbstractDiscoveryResponse) = begin
            Int(1)
        end
    status_encoding_length(::Type{<:AbstractDiscoveryResponse}) = begin
            Int(1)
        end
    status_null_value(::AbstractDiscoveryResponse) = begin
            UInt8(255)
        end
    status_null_value(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt8(255)
        end
    status_min_value(::AbstractDiscoveryResponse) = begin
            UInt8(0)
        end
    status_min_value(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt8(0)
        end
    status_max_value(::AbstractDiscoveryResponse) = begin
            UInt8(254)
        end
    status_max_value(::Type{<:AbstractDiscoveryResponse}) = begin
            UInt8(254)
        end
end
begin
    function status_meta_attribute(::AbstractDiscoveryResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function status_meta_attribute(::Type{<:AbstractDiscoveryResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function status(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 8)
        end
    @inline function status(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 8)
            return DiscoveryStatus.SbeEnum(raw)
        end
    @inline function status!(m::Encoder, value::DiscoveryStatus.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 8, UInt8(value))
        end
    export status, status!
end
module Results
using SBE: AbstractSbeGroup, PositionPointer, to_string
import SBE: sbe_header_size, sbe_block_length, sbe_acting_block_length, sbe_acting_version
import SBE: sbe_position, sbe_position!, sbe_position_ptr, next!
using StringViews: StringView
using ...GroupSizeEncoding
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
abstract type AbstractResults{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractResults{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    block_length::UInt16
    acting_version::UInt16
    count::UInt16
    index::UInt16
    function Decoder(buffer::T, offset::Integer, position_ptr::PositionPointer, block_length::Integer, acting_version::Integer, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, block_length, acting_version, UInt16(count), UInt16(index))
    end
end
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractResults{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    initial_position::Int64
    count::UInt16
    index::UInt16
    function Encoder(buffer::T, offset::Integer, position_ptr::PositionPointer, initial_position::Int64, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, initial_position, UInt16(count), UInt16(index))
    end
end
@inline function Decoder(buffer, position_ptr::PositionPointer, acting_version)
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        return Decoder(buffer, 0, position_ptr, GroupSizeEncoding.blockLength(dimensions), acting_version, GroupSizeEncoding.numInGroup(dimensions), UInt16(0))
    end
@inline function reset!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = GroupSizeEncoding.blockLength(dimensions)
        g.acting_version = acting_version
        g.count = GroupSizeEncoding.numInGroup(dimensions)
        g.index = UInt16(0)
        return g
    end
@inline function reset_missing!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = UInt16(0)
        g.acting_version = acting_version
        g.count = UInt16(0)
        g.index = UInt16(0)
        return g
    end
@inline function wrap!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        return reset!(g, buffer, position_ptr, acting_version)
    end
@inline function Encoder(buffer, count, position_ptr::PositionPointer)
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(39))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        initial_position = position_ptr[]
        position_ptr[] += 4
        return Encoder(buffer, 0, position_ptr, initial_position, count, UInt16(0))
    end
@inline function wrap!(g::Encoder{T}, buffer::T, count, position_ptr::PositionPointer) where T
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(39))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.initial_position = position_ptr[]
        g.count = UInt16(count)
        g.index = UInt16(0)
        position_ptr[] += 4
        return g
    end
sbe_header_size(::AbstractResults) = begin
        4
    end
sbe_block_length(::AbstractResults) = begin
        UInt16(39)
    end
sbe_acting_block_length(g::Decoder) = begin
        g.block_length
    end
sbe_acting_block_length(g::Encoder) = begin
        UInt16(39)
    end
sbe_acting_version(g::Decoder) = begin
        g.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_position(g::AbstractResults) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractResults, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractResults) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractResults)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractResults, state = nothing)
    if g.index < g.count
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return (g, state)
    else
        return nothing
    end
end
Base.eltype(::Type{<:Decoder}) = begin
        Decoder
    end
Base.eltype(::Type{<:Encoder}) = begin
        Encoder
    end
Base.isdone(g::AbstractResults, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractResults) = begin
        Int(g.count)
    end
function reset_count_to_index!(g::Encoder)
    g.count = g.index
    dimensions = GroupSizeEncoding.Encoder(g.buffer, g.initial_position)
    GroupSizeEncoding.numInGroup!(dimensions, g.count)
    return g.count
end
export reset_count_to_index!
begin
    streamId_id(::AbstractResults) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractResults}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractResults) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractResults) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractResults}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractResults) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractResults) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractResults}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractResults) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
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
    producerId_id(::AbstractResults) = begin
            UInt16(2)
        end
    producerId_id(::Type{<:AbstractResults}) = begin
            UInt16(2)
        end
    producerId_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    producerId_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    producerId_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    producerId_encoding_offset(::AbstractResults) = begin
            Int(4)
        end
    producerId_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(4)
        end
    producerId_encoding_length(::AbstractResults) = begin
            Int(4)
        end
    producerId_encoding_length(::Type{<:AbstractResults}) = begin
            Int(4)
        end
    producerId_null_value(::AbstractResults) = begin
            UInt32(4294967295)
        end
    producerId_null_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967295)
        end
    producerId_min_value(::AbstractResults) = begin
            UInt32(0)
        end
    producerId_min_value(::Type{<:AbstractResults}) = begin
            UInt32(0)
        end
    producerId_max_value(::AbstractResults) = begin
            UInt32(4294967294)
        end
    producerId_max_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967294)
        end
end
begin
    function producerId_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function producerId_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function producerId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 4)
        end
    @inline producerId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 4, val)
            end
    export producerId, producerId!
end
begin
    epoch_id(::AbstractResults) = begin
            UInt16(3)
        end
    epoch_id(::Type{<:AbstractResults}) = begin
            UInt16(3)
        end
    epoch_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractResults) = begin
            Int(8)
        end
    epoch_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(8)
        end
    epoch_encoding_length(::AbstractResults) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractResults}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractResults) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractResults}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractResults) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractResults}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractResults) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractResults}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function epoch(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 8)
        end
    @inline epoch!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 8, val)
            end
    export epoch, epoch!
end
begin
    layoutVersion_id(::AbstractResults) = begin
            UInt16(4)
        end
    layoutVersion_id(::Type{<:AbstractResults}) = begin
            UInt16(4)
        end
    layoutVersion_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    layoutVersion_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    layoutVersion_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    layoutVersion_encoding_offset(::AbstractResults) = begin
            Int(16)
        end
    layoutVersion_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(16)
        end
    layoutVersion_encoding_length(::AbstractResults) = begin
            Int(4)
        end
    layoutVersion_encoding_length(::Type{<:AbstractResults}) = begin
            Int(4)
        end
    layoutVersion_null_value(::AbstractResults) = begin
            UInt32(4294967295)
        end
    layoutVersion_null_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967295)
        end
    layoutVersion_min_value(::AbstractResults) = begin
            UInt32(0)
        end
    layoutVersion_min_value(::Type{<:AbstractResults}) = begin
            UInt32(0)
        end
    layoutVersion_max_value(::AbstractResults) = begin
            UInt32(4294967294)
        end
    layoutVersion_max_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967294)
        end
end
begin
    function layoutVersion_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function layoutVersion_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function layoutVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 16)
        end
    @inline layoutVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 16, val)
            end
    export layoutVersion, layoutVersion!
end
begin
    headerNslots_id(::AbstractResults) = begin
            UInt16(5)
        end
    headerNslots_id(::Type{<:AbstractResults}) = begin
            UInt16(5)
        end
    headerNslots_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    headerNslots_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    headerNslots_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerNslots_encoding_offset(::AbstractResults) = begin
            Int(20)
        end
    headerNslots_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(20)
        end
    headerNslots_encoding_length(::AbstractResults) = begin
            Int(4)
        end
    headerNslots_encoding_length(::Type{<:AbstractResults}) = begin
            Int(4)
        end
    headerNslots_null_value(::AbstractResults) = begin
            UInt32(4294967295)
        end
    headerNslots_null_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967295)
        end
    headerNslots_min_value(::AbstractResults) = begin
            UInt32(0)
        end
    headerNslots_min_value(::Type{<:AbstractResults}) = begin
            UInt32(0)
        end
    headerNslots_max_value(::AbstractResults) = begin
            UInt32(4294967294)
        end
    headerNslots_max_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967294)
        end
end
begin
    function headerNslots_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerNslots_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerNslots(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 20)
        end
    @inline headerNslots!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 20, val)
            end
    export headerNslots, headerNslots!
end
begin
    headerSlotBytes_id(::AbstractResults) = begin
            UInt16(6)
        end
    headerSlotBytes_id(::Type{<:AbstractResults}) = begin
            UInt16(6)
        end
    headerSlotBytes_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    headerSlotBytes_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    headerSlotBytes_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerSlotBytes_encoding_offset(::AbstractResults) = begin
            Int(24)
        end
    headerSlotBytes_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(24)
        end
    headerSlotBytes_encoding_length(::AbstractResults) = begin
            Int(2)
        end
    headerSlotBytes_encoding_length(::Type{<:AbstractResults}) = begin
            Int(2)
        end
    headerSlotBytes_null_value(::AbstractResults) = begin
            UInt16(65535)
        end
    headerSlotBytes_null_value(::Type{<:AbstractResults}) = begin
            UInt16(65535)
        end
    headerSlotBytes_min_value(::AbstractResults) = begin
            UInt16(0)
        end
    headerSlotBytes_min_value(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    headerSlotBytes_max_value(::AbstractResults) = begin
            UInt16(65534)
        end
    headerSlotBytes_max_value(::Type{<:AbstractResults}) = begin
            UInt16(65534)
        end
end
begin
    function headerSlotBytes_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerSlotBytes_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerSlotBytes(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 24)
        end
    @inline headerSlotBytes!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 24, val)
            end
    export headerSlotBytes, headerSlotBytes!
end
begin
    maxDims_id(::AbstractResults) = begin
            UInt16(7)
        end
    maxDims_id(::Type{<:AbstractResults}) = begin
            UInt16(7)
        end
    maxDims_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    maxDims_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    maxDims_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    maxDims_encoding_offset(::AbstractResults) = begin
            Int(26)
        end
    maxDims_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(26)
        end
    maxDims_encoding_length(::AbstractResults) = begin
            Int(1)
        end
    maxDims_encoding_length(::Type{<:AbstractResults}) = begin
            Int(1)
        end
    maxDims_null_value(::AbstractResults) = begin
            UInt8(255)
        end
    maxDims_null_value(::Type{<:AbstractResults}) = begin
            UInt8(255)
        end
    maxDims_min_value(::AbstractResults) = begin
            UInt8(0)
        end
    maxDims_min_value(::Type{<:AbstractResults}) = begin
            UInt8(0)
        end
    maxDims_max_value(::AbstractResults) = begin
            UInt8(254)
        end
    maxDims_max_value(::Type{<:AbstractResults}) = begin
            UInt8(254)
        end
end
begin
    function maxDims_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function maxDims_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function maxDims(m::Decoder)
            return decode_value(UInt8, m.buffer, m.offset + 26)
        end
    @inline maxDims!(m::Encoder, val) = begin
                encode_value(UInt8, m.buffer, m.offset + 26, val)
            end
    export maxDims, maxDims!
end
begin
    dataSourceId_id(::AbstractResults) = begin
            UInt16(8)
        end
    dataSourceId_id(::Type{<:AbstractResults}) = begin
            UInt16(8)
        end
    dataSourceId_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    dataSourceId_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    dataSourceId_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    dataSourceId_encoding_offset(::AbstractResults) = begin
            Int(27)
        end
    dataSourceId_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(27)
        end
    dataSourceId_encoding_length(::AbstractResults) = begin
            Int(8)
        end
    dataSourceId_encoding_length(::Type{<:AbstractResults}) = begin
            Int(8)
        end
    dataSourceId_null_value(::AbstractResults) = begin
            UInt64(18446744073709551615)
        end
    dataSourceId_null_value(::Type{<:AbstractResults}) = begin
            UInt64(18446744073709551615)
        end
    dataSourceId_min_value(::AbstractResults) = begin
            UInt64(0)
        end
    dataSourceId_min_value(::Type{<:AbstractResults}) = begin
            UInt64(0)
        end
    dataSourceId_max_value(::AbstractResults) = begin
            UInt64(18446744073709551614)
        end
    dataSourceId_max_value(::Type{<:AbstractResults}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function dataSourceId_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dataSourceId_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function dataSourceId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 27)
        end
    @inline dataSourceId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 27, val)
            end
    export dataSourceId, dataSourceId!
end
begin
    driverControlStreamId_id(::AbstractResults) = begin
            UInt16(9)
        end
    driverControlStreamId_id(::Type{<:AbstractResults}) = begin
            UInt16(9)
        end
    driverControlStreamId_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    driverControlStreamId_since_version(::Type{<:AbstractResults}) = begin
            UInt16(0)
        end
    driverControlStreamId_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    driverControlStreamId_encoding_offset(::AbstractResults) = begin
            Int(35)
        end
    driverControlStreamId_encoding_offset(::Type{<:AbstractResults}) = begin
            Int(35)
        end
    driverControlStreamId_encoding_length(::AbstractResults) = begin
            Int(4)
        end
    driverControlStreamId_encoding_length(::Type{<:AbstractResults}) = begin
            Int(4)
        end
    driverControlStreamId_null_value(::AbstractResults) = begin
            UInt32(4294967295)
        end
    driverControlStreamId_null_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967295)
        end
    driverControlStreamId_min_value(::AbstractResults) = begin
            UInt32(0)
        end
    driverControlStreamId_min_value(::Type{<:AbstractResults}) = begin
            UInt32(0)
        end
    driverControlStreamId_max_value(::AbstractResults) = begin
            UInt32(4294967294)
        end
    driverControlStreamId_max_value(::Type{<:AbstractResults}) = begin
            UInt32(4294967294)
        end
end
begin
    function driverControlStreamId_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function driverControlStreamId_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function driverControlStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 35)
        end
    @inline driverControlStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 35, val)
            end
    export driverControlStreamId, driverControlStreamId!
end
begin
    function headerRegionUri_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerRegionUri_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    headerRegionUri_character_encoding(::AbstractResults) = begin
            "US-ASCII"
        end
    headerRegionUri_character_encoding(::Type{<:AbstractResults}) = begin
            "US-ASCII"
        end
end
begin
    const headerRegionUri_id = UInt16(12)
    const headerRegionUri_since_version = UInt16(0)
    const headerRegionUri_header_length = 4
    headerRegionUri_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function headerRegionUri_length(m::AbstractResults)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function headerRegionUri_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_headerRegionUri!(m::Decoder)
            len = headerRegionUri_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function headerRegionUri(m::Decoder)
            len = headerRegionUri_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function headerRegionUri_buffer!(m::Encoder, len)
            headerRegionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function headerRegionUri!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            headerRegionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function headerRegionUri!(m::Encoder, src::NTuple)
            len = sizeof(src)
            headerRegionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function headerRegionUri!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            headerRegionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline headerRegionUri!(m::Encoder, src::Symbol) = begin
                headerRegionUri!(m, to_string(src))
            end
    @inline headerRegionUri!(m::Encoder, src::Real) = begin
                headerRegionUri!(m, Tuple(src))
            end
    @inline headerRegionUri!(m::Encoder, ::Nothing) = begin
                headerRegionUri_buffer!(m, 0)
            end
end
begin
    @inline function headerRegionUri(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(headerRegionUri(m))))
        end
    @inline function headerRegionUri(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(headerRegionUri(m)))
        end
    @inline function headerRegionUri(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(headerRegionUri(m, StringView))
        end
    @inline function headerRegionUri(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, headerRegionUri(m)))[]
        end
    @inline function headerRegionUri(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, headerRegionUri(m))
        end
    @inline function headerRegionUri(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, headerRegionUri(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function headerRegionUri(m::Decoder, ::Type{T}) where T <: Nothing
            skip_headerRegionUri!(m)
            return nothing
        end
end
begin
    function dataSourceName_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dataSourceName_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    dataSourceName_character_encoding(::AbstractResults) = begin
            "US-ASCII"
        end
    dataSourceName_character_encoding(::Type{<:AbstractResults}) = begin
            "US-ASCII"
        end
end
begin
    const dataSourceName_id = UInt16(13)
    const dataSourceName_since_version = UInt16(0)
    const dataSourceName_header_length = 4
    dataSourceName_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function dataSourceName_length(m::AbstractResults)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function dataSourceName_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_dataSourceName!(m::Decoder)
            len = dataSourceName_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function dataSourceName(m::Decoder)
            len = dataSourceName_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function dataSourceName_buffer!(m::Encoder, len)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function dataSourceName!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function dataSourceName!(m::Encoder, src::NTuple)
            len = sizeof(src)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function dataSourceName!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline dataSourceName!(m::Encoder, src::Symbol) = begin
                dataSourceName!(m, to_string(src))
            end
    @inline dataSourceName!(m::Encoder, src::Real) = begin
                dataSourceName!(m, Tuple(src))
            end
    @inline dataSourceName!(m::Encoder, ::Nothing) = begin
                dataSourceName_buffer!(m, 0)
            end
end
begin
    @inline function dataSourceName(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(dataSourceName(m))))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(dataSourceName(m)))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(dataSourceName(m, StringView))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, dataSourceName(m)))[]
        end
    @inline function dataSourceName(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, dataSourceName(m))
        end
    @inline function dataSourceName(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, dataSourceName(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: Nothing
            skip_dataSourceName!(m)
            return nothing
        end
end
begin
    function driverInstanceId_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function driverInstanceId_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    driverInstanceId_character_encoding(::AbstractResults) = begin
            "US-ASCII"
        end
    driverInstanceId_character_encoding(::Type{<:AbstractResults}) = begin
            "US-ASCII"
        end
end
begin
    const driverInstanceId_id = UInt16(14)
    const driverInstanceId_since_version = UInt16(0)
    const driverInstanceId_header_length = 4
    driverInstanceId_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function driverInstanceId_length(m::AbstractResults)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function driverInstanceId_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_driverInstanceId!(m::Decoder)
            len = driverInstanceId_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function driverInstanceId(m::Decoder)
            len = driverInstanceId_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function driverInstanceId_buffer!(m::Encoder, len)
            driverInstanceId_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function driverInstanceId!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            driverInstanceId_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function driverInstanceId!(m::Encoder, src::NTuple)
            len = sizeof(src)
            driverInstanceId_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function driverInstanceId!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            driverInstanceId_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline driverInstanceId!(m::Encoder, src::Symbol) = begin
                driverInstanceId!(m, to_string(src))
            end
    @inline driverInstanceId!(m::Encoder, src::Real) = begin
                driverInstanceId!(m, Tuple(src))
            end
    @inline driverInstanceId!(m::Encoder, ::Nothing) = begin
                driverInstanceId_buffer!(m, 0)
            end
end
begin
    @inline function driverInstanceId(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(driverInstanceId(m))))
        end
    @inline function driverInstanceId(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(driverInstanceId(m)))
        end
    @inline function driverInstanceId(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(driverInstanceId(m, StringView))
        end
    @inline function driverInstanceId(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, driverInstanceId(m)))[]
        end
    @inline function driverInstanceId(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, driverInstanceId(m))
        end
    @inline function driverInstanceId(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, driverInstanceId(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function driverInstanceId(m::Decoder, ::Type{T}) where T <: Nothing
            skip_driverInstanceId!(m)
            return nothing
        end
end
begin
    function driverControlChannel_meta_attribute(::AbstractResults, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function driverControlChannel_meta_attribute(::Type{<:AbstractResults}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    driverControlChannel_character_encoding(::AbstractResults) = begin
            "US-ASCII"
        end
    driverControlChannel_character_encoding(::Type{<:AbstractResults}) = begin
            "US-ASCII"
        end
end
begin
    const driverControlChannel_id = UInt16(15)
    const driverControlChannel_since_version = UInt16(0)
    const driverControlChannel_header_length = 4
    driverControlChannel_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function driverControlChannel_length(m::AbstractResults)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function driverControlChannel_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_driverControlChannel!(m::Decoder)
            len = driverControlChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function driverControlChannel(m::Decoder)
            len = driverControlChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function driverControlChannel_buffer!(m::Encoder, len)
            driverControlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function driverControlChannel!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            driverControlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function driverControlChannel!(m::Encoder, src::NTuple)
            len = sizeof(src)
            driverControlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function driverControlChannel!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            driverControlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline driverControlChannel!(m::Encoder, src::Symbol) = begin
                driverControlChannel!(m, to_string(src))
            end
    @inline driverControlChannel!(m::Encoder, src::Real) = begin
                driverControlChannel!(m, Tuple(src))
            end
    @inline driverControlChannel!(m::Encoder, ::Nothing) = begin
                driverControlChannel_buffer!(m, 0)
            end
end
begin
    @inline function driverControlChannel(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(driverControlChannel(m))))
        end
    @inline function driverControlChannel(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(driverControlChannel(m)))
        end
    @inline function driverControlChannel(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(driverControlChannel(m, StringView))
        end
    @inline function driverControlChannel(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, driverControlChannel(m)))[]
        end
    @inline function driverControlChannel(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, driverControlChannel(m))
        end
    @inline function driverControlChannel(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, driverControlChannel(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function driverControlChannel(m::Decoder, ::Type{T}) where T <: Nothing
            skip_driverControlChannel!(m)
            return nothing
        end
end
module PayloadPools
using SBE: AbstractSbeGroup, PositionPointer, to_string
import SBE: sbe_header_size, sbe_block_length, sbe_acting_block_length, sbe_acting_version
import SBE: sbe_position, sbe_position!, sbe_position_ptr, next!
using StringViews: StringView
using ....GroupSizeEncoding
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
abstract type AbstractPayloadPools{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractPayloadPools{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    block_length::UInt16
    acting_version::UInt16
    count::UInt16
    index::UInt16
    function Decoder(buffer::T, offset::Integer, position_ptr::PositionPointer, block_length::Integer, acting_version::Integer, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, block_length, acting_version, UInt16(count), UInt16(index))
    end
end
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractPayloadPools{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    initial_position::Int64
    count::UInt16
    index::UInt16
    function Encoder(buffer::T, offset::Integer, position_ptr::PositionPointer, initial_position::Int64, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, initial_position, UInt16(count), UInt16(index))
    end
end
@inline function Decoder(buffer, position_ptr::PositionPointer, acting_version)
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        return Decoder(buffer, 0, position_ptr, GroupSizeEncoding.blockLength(dimensions), acting_version, GroupSizeEncoding.numInGroup(dimensions), UInt16(0))
    end
@inline function reset!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = GroupSizeEncoding.blockLength(dimensions)
        g.acting_version = acting_version
        g.count = GroupSizeEncoding.numInGroup(dimensions)
        g.index = UInt16(0)
        return g
    end
@inline function reset_missing!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = UInt16(0)
        g.acting_version = acting_version
        g.count = UInt16(0)
        g.index = UInt16(0)
        return g
    end
@inline function wrap!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        return reset!(g, buffer, position_ptr, acting_version)
    end
@inline function Encoder(buffer, count, position_ptr::PositionPointer)
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(10))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        initial_position = position_ptr[]
        position_ptr[] += 4
        return Encoder(buffer, 0, position_ptr, initial_position, count, UInt16(0))
    end
@inline function wrap!(g::Encoder{T}, buffer::T, count, position_ptr::PositionPointer) where T
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(10))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.initial_position = position_ptr[]
        g.count = UInt16(count)
        g.index = UInt16(0)
        position_ptr[] += 4
        return g
    end
sbe_header_size(::AbstractPayloadPools) = begin
        4
    end
sbe_block_length(::AbstractPayloadPools) = begin
        UInt16(10)
    end
sbe_acting_block_length(g::Decoder) = begin
        g.block_length
    end
sbe_acting_block_length(g::Encoder) = begin
        UInt16(10)
    end
sbe_acting_version(g::Decoder) = begin
        g.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_position(g::AbstractPayloadPools) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractPayloadPools, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractPayloadPools) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractPayloadPools)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractPayloadPools, state = nothing)
    if g.index < g.count
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return (g, state)
    else
        return nothing
    end
end
Base.eltype(::Type{<:Decoder}) = begin
        Decoder
    end
Base.eltype(::Type{<:Encoder}) = begin
        Encoder
    end
Base.isdone(g::AbstractPayloadPools, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractPayloadPools) = begin
        Int(g.count)
    end
function reset_count_to_index!(g::Encoder)
    g.count = g.index
    dimensions = GroupSizeEncoding.Encoder(g.buffer, g.initial_position)
    GroupSizeEncoding.numInGroup!(dimensions, g.count)
    return g.count
end
export reset_count_to_index!
begin
    poolId_id(::AbstractPayloadPools) = begin
            UInt16(1)
        end
    poolId_id(::Type{<:AbstractPayloadPools}) = begin
            UInt16(1)
        end
    poolId_since_version(::AbstractPayloadPools) = begin
            UInt16(0)
        end
    poolId_since_version(::Type{<:AbstractPayloadPools}) = begin
            UInt16(0)
        end
    poolId_in_acting_version(m::AbstractPayloadPools) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    poolId_encoding_offset(::AbstractPayloadPools) = begin
            Int(0)
        end
    poolId_encoding_offset(::Type{<:AbstractPayloadPools}) = begin
            Int(0)
        end
    poolId_encoding_length(::AbstractPayloadPools) = begin
            Int(2)
        end
    poolId_encoding_length(::Type{<:AbstractPayloadPools}) = begin
            Int(2)
        end
    poolId_null_value(::AbstractPayloadPools) = begin
            UInt16(65535)
        end
    poolId_null_value(::Type{<:AbstractPayloadPools}) = begin
            UInt16(65535)
        end
    poolId_min_value(::AbstractPayloadPools) = begin
            UInt16(0)
        end
    poolId_min_value(::Type{<:AbstractPayloadPools}) = begin
            UInt16(0)
        end
    poolId_max_value(::AbstractPayloadPools) = begin
            UInt16(65534)
        end
    poolId_max_value(::Type{<:AbstractPayloadPools}) = begin
            UInt16(65534)
        end
end
begin
    function poolId_meta_attribute(::AbstractPayloadPools, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function poolId_meta_attribute(::Type{<:AbstractPayloadPools}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function poolId(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 0)
        end
    @inline poolId!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 0, val)
            end
    export poolId, poolId!
end
begin
    poolNslots_id(::AbstractPayloadPools) = begin
            UInt16(2)
        end
    poolNslots_id(::Type{<:AbstractPayloadPools}) = begin
            UInt16(2)
        end
    poolNslots_since_version(::AbstractPayloadPools) = begin
            UInt16(0)
        end
    poolNslots_since_version(::Type{<:AbstractPayloadPools}) = begin
            UInt16(0)
        end
    poolNslots_in_acting_version(m::AbstractPayloadPools) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    poolNslots_encoding_offset(::AbstractPayloadPools) = begin
            Int(2)
        end
    poolNslots_encoding_offset(::Type{<:AbstractPayloadPools}) = begin
            Int(2)
        end
    poolNslots_encoding_length(::AbstractPayloadPools) = begin
            Int(4)
        end
    poolNslots_encoding_length(::Type{<:AbstractPayloadPools}) = begin
            Int(4)
        end
    poolNslots_null_value(::AbstractPayloadPools) = begin
            UInt32(4294967295)
        end
    poolNslots_null_value(::Type{<:AbstractPayloadPools}) = begin
            UInt32(4294967295)
        end
    poolNslots_min_value(::AbstractPayloadPools) = begin
            UInt32(0)
        end
    poolNslots_min_value(::Type{<:AbstractPayloadPools}) = begin
            UInt32(0)
        end
    poolNslots_max_value(::AbstractPayloadPools) = begin
            UInt32(4294967294)
        end
    poolNslots_max_value(::Type{<:AbstractPayloadPools}) = begin
            UInt32(4294967294)
        end
end
begin
    function poolNslots_meta_attribute(::AbstractPayloadPools, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function poolNslots_meta_attribute(::Type{<:AbstractPayloadPools}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function poolNslots(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 2)
        end
    @inline poolNslots!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 2, val)
            end
    export poolNslots, poolNslots!
end
begin
    strideBytes_id(::AbstractPayloadPools) = begin
            UInt16(3)
        end
    strideBytes_id(::Type{<:AbstractPayloadPools}) = begin
            UInt16(3)
        end
    strideBytes_since_version(::AbstractPayloadPools) = begin
            UInt16(0)
        end
    strideBytes_since_version(::Type{<:AbstractPayloadPools}) = begin
            UInt16(0)
        end
    strideBytes_in_acting_version(m::AbstractPayloadPools) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    strideBytes_encoding_offset(::AbstractPayloadPools) = begin
            Int(6)
        end
    strideBytes_encoding_offset(::Type{<:AbstractPayloadPools}) = begin
            Int(6)
        end
    strideBytes_encoding_length(::AbstractPayloadPools) = begin
            Int(4)
        end
    strideBytes_encoding_length(::Type{<:AbstractPayloadPools}) = begin
            Int(4)
        end
    strideBytes_null_value(::AbstractPayloadPools) = begin
            UInt32(4294967295)
        end
    strideBytes_null_value(::Type{<:AbstractPayloadPools}) = begin
            UInt32(4294967295)
        end
    strideBytes_min_value(::AbstractPayloadPools) = begin
            UInt32(0)
        end
    strideBytes_min_value(::Type{<:AbstractPayloadPools}) = begin
            UInt32(0)
        end
    strideBytes_max_value(::AbstractPayloadPools) = begin
            UInt32(4294967294)
        end
    strideBytes_max_value(::Type{<:AbstractPayloadPools}) = begin
            UInt32(4294967294)
        end
end
begin
    function strideBytes_meta_attribute(::AbstractPayloadPools, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function strideBytes_meta_attribute(::Type{<:AbstractPayloadPools}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function strideBytes(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 6)
        end
    @inline strideBytes!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 6, val)
            end
    export strideBytes, strideBytes!
end
begin
    function regionUri_meta_attribute(::AbstractPayloadPools, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function regionUri_meta_attribute(::Type{<:AbstractPayloadPools}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    regionUri_character_encoding(::AbstractPayloadPools) = begin
            "US-ASCII"
        end
    regionUri_character_encoding(::Type{<:AbstractPayloadPools}) = begin
            "US-ASCII"
        end
end
begin
    const regionUri_id = UInt16(4)
    const regionUri_since_version = UInt16(0)
    const regionUri_header_length = 4
    regionUri_in_acting_version(m::AbstractPayloadPools) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function regionUri_length(m::AbstractPayloadPools)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function regionUri_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_regionUri!(m::Decoder)
            len = regionUri_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function regionUri(m::Decoder)
            len = regionUri_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function regionUri_buffer!(m::Encoder, len)
            regionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function regionUri!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            regionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function regionUri!(m::Encoder, src::NTuple)
            len = sizeof(src)
            regionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function regionUri!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            regionUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline regionUri!(m::Encoder, src::Symbol) = begin
                regionUri!(m, to_string(src))
            end
    @inline regionUri!(m::Encoder, src::Real) = begin
                regionUri!(m, Tuple(src))
            end
    @inline regionUri!(m::Encoder, ::Nothing) = begin
                regionUri_buffer!(m, 0)
            end
end
begin
    @inline function regionUri(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(regionUri(m))))
        end
    @inline function regionUri(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(regionUri(m)))
        end
    @inline function regionUri(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(regionUri(m, StringView))
        end
    @inline function regionUri(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, regionUri(m)))[]
        end
    @inline function regionUri(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, regionUri(m))
        end
    @inline function regionUri(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, regionUri(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function regionUri(m::Decoder, ::Type{T}) where T <: Nothing
            skip_regionUri!(m)
            return nothing
        end
end
@inline function sbe_skip!(m::Decoder)
        begin
            skip_regionUri!(m)
        end
        return
    end
export AbstractPayloadPools, Decoder, Encoder
end
begin
    @inline function payloadPools(m::AbstractResults)
            return PayloadPools.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function payloadPools!(m::AbstractResults, g::PayloadPools.Decoder)
            return PayloadPools.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function payloadPools!(m::AbstractResults, count)
            return PayloadPools.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    payloadPools_group_count!(m::Encoder, count) = begin
            payloadPools!(m, count)
        end
    payloadPools_id(::AbstractResults) = begin
            UInt16(10)
        end
    payloadPools_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    payloadPools_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export payloadPools, payloadPools!, payloadPools!, PayloadPools
end
module Tags
using SBE: AbstractSbeGroup, PositionPointer, to_string
import SBE: sbe_header_size, sbe_block_length, sbe_acting_block_length, sbe_acting_version
import SBE: sbe_position, sbe_position!, sbe_position_ptr, next!
using StringViews: StringView
using ....VarAsciiEncoding
using ....GroupSizeEncoding
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
abstract type AbstractTags{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractTags{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    block_length::UInt16
    acting_version::UInt16
    count::UInt16
    index::UInt16
    function Decoder(buffer::T, offset::Integer, position_ptr::PositionPointer, block_length::Integer, acting_version::Integer, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, block_length, acting_version, UInt16(count), UInt16(index))
    end
end
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractTags{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    initial_position::Int64
    count::UInt16
    index::UInt16
    function Encoder(buffer::T, offset::Integer, position_ptr::PositionPointer, initial_position::Int64, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, initial_position, UInt16(count), UInt16(index))
    end
end
@inline function Decoder(buffer, position_ptr::PositionPointer, acting_version)
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        return Decoder(buffer, 0, position_ptr, GroupSizeEncoding.blockLength(dimensions), acting_version, GroupSizeEncoding.numInGroup(dimensions), UInt16(0))
    end
@inline function reset!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = GroupSizeEncoding.blockLength(dimensions)
        g.acting_version = acting_version
        g.count = GroupSizeEncoding.numInGroup(dimensions)
        g.index = UInt16(0)
        return g
    end
@inline function reset_missing!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = UInt16(0)
        g.acting_version = acting_version
        g.count = UInt16(0)
        g.index = UInt16(0)
        return g
    end
@inline function wrap!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        return reset!(g, buffer, position_ptr, acting_version)
    end
@inline function Encoder(buffer, count, position_ptr::PositionPointer)
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(0))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        initial_position = position_ptr[]
        position_ptr[] += 4
        return Encoder(buffer, 0, position_ptr, initial_position, count, UInt16(0))
    end
@inline function wrap!(g::Encoder{T}, buffer::T, count, position_ptr::PositionPointer) where T
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(0))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.initial_position = position_ptr[]
        g.count = UInt16(count)
        g.index = UInt16(0)
        position_ptr[] += 4
        return g
    end
sbe_header_size(::AbstractTags) = begin
        4
    end
sbe_block_length(::AbstractTags) = begin
        UInt16(0)
    end
sbe_acting_block_length(g::Decoder) = begin
        g.block_length
    end
sbe_acting_block_length(g::Encoder) = begin
        UInt16(0)
    end
sbe_acting_version(g::Decoder) = begin
        g.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_position(g::AbstractTags) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractTags, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractTags) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractTags)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractTags, state = nothing)
    if g.index < g.count
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return (g, state)
    else
        return nothing
    end
end
Base.eltype(::Type{<:Decoder}) = begin
        Decoder
    end
Base.eltype(::Type{<:Encoder}) = begin
        Encoder
    end
Base.isdone(g::AbstractTags, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractTags) = begin
        Int(g.count)
    end
function reset_count_to_index!(g::Encoder)
    g.count = g.index
    dimensions = GroupSizeEncoding.Encoder(g.buffer, g.initial_position)
    GroupSizeEncoding.numInGroup!(dimensions, g.count)
    return g.count
end
export reset_count_to_index!
begin
    tag_id(::AbstractTags) = begin
            UInt16(1)
        end
    tag_id(::Type{<:AbstractTags}) = begin
            UInt16(1)
        end
    tag_since_version(::AbstractTags) = begin
            UInt16(0)
        end
    tag_since_version(::Type{<:AbstractTags}) = begin
            UInt16(0)
        end
    tag_in_acting_version(m::AbstractTags) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    tag_encoding_offset(::AbstractTags) = begin
            0
        end
    tag_encoding_offset(::Type{<:AbstractTags}) = begin
            0
        end
    tag_encoding_length(::AbstractTags) = begin
            -1
        end
    tag_encoding_length(::Type{<:AbstractTags}) = begin
            -1
        end
end
begin
    function tag_meta_attribute(::AbstractTags, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function tag_meta_attribute(::Type{<:AbstractTags}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function tag(m::Decoder)
            return VarAsciiEncoding.Decoder(m.buffer, m.offset + 0, m.acting_version)
        end
    @inline function tag(m::Encoder)
            return VarAsciiEncoding.Encoder(m.buffer, m.offset + 0)
        end
    export tag
end
@inline function sbe_skip!(m::Decoder)
        return
        return
    end
export AbstractTags, Decoder, Encoder
end
begin
    @inline function tags(m::AbstractResults)
            return Tags.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function tags!(m::AbstractResults, g::Tags.Decoder)
            return Tags.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function tags!(m::AbstractResults, count)
            return Tags.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    tags_group_count!(m::Encoder, count) = begin
            tags!(m, count)
        end
    tags_id(::AbstractResults) = begin
            UInt16(11)
        end
    tags_since_version(::AbstractResults) = begin
            UInt16(0)
        end
    tags_in_acting_version(m::AbstractResults) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export tags, tags!, tags!, Tags
end
@inline function sbe_skip!(m::Decoder)
        begin
            begin
                for group = payloadPools(m)
                    PayloadPools.sbe_skip!(group)
                end
            end
            begin
                for group = tags(m)
                    Tags.sbe_skip!(group)
                end
            end
            skip_headerRegionUri!(m)
            skip_dataSourceName!(m)
            skip_driverInstanceId!(m)
            skip_driverControlChannel!(m)
        end
        return
    end
export AbstractResults, Decoder, Encoder
end
begin
    @inline function results(m::AbstractDiscoveryResponse)
            return Results.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function results!(m::AbstractDiscoveryResponse, g::Results.Decoder)
            return Results.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function results!(m::AbstractDiscoveryResponse, count)
            return Results.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    results_group_count!(m::Encoder, count) = begin
            results!(m, count)
        end
    results_id(::AbstractDiscoveryResponse) = begin
            UInt16(3)
        end
    results_since_version(::AbstractDiscoveryResponse) = begin
            UInt16(0)
        end
    results_in_acting_version(m::AbstractDiscoveryResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export results, results!, results!, Results
end
begin
    function errorMessage_meta_attribute(::AbstractDiscoveryResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function errorMessage_meta_attribute(::Type{<:AbstractDiscoveryResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    errorMessage_character_encoding(::AbstractDiscoveryResponse) = begin
            "US-ASCII"
        end
    errorMessage_character_encoding(::Type{<:AbstractDiscoveryResponse}) = begin
            "US-ASCII"
        end
end
begin
    const errorMessage_id = UInt16(4)
    const errorMessage_since_version = UInt16(0)
    const errorMessage_header_length = 4
    errorMessage_in_acting_version(m::AbstractDiscoveryResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function errorMessage_length(m::AbstractDiscoveryResponse)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function errorMessage_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_errorMessage!(m::Decoder)
            len = errorMessage_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function errorMessage(m::Decoder)
            len = errorMessage_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function errorMessage_buffer!(m::Encoder, len)
            errorMessage_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function errorMessage!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            errorMessage_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function errorMessage!(m::Encoder, src::NTuple)
            len = sizeof(src)
            errorMessage_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function errorMessage!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            errorMessage_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline errorMessage!(m::Encoder, src::Symbol) = begin
                errorMessage!(m, to_string(src))
            end
    @inline errorMessage!(m::Encoder, src::Real) = begin
                errorMessage!(m, Tuple(src))
            end
    @inline errorMessage!(m::Encoder, ::Nothing) = begin
                errorMessage_buffer!(m, 0)
            end
end
begin
    @inline function errorMessage(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(errorMessage(m))))
        end
    @inline function errorMessage(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(errorMessage(m)))
        end
    @inline function errorMessage(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(errorMessage(m, StringView))
        end
    @inline function errorMessage(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, errorMessage(m)))[]
        end
    @inline function errorMessage(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, errorMessage(m))
        end
    @inline function errorMessage(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, errorMessage(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function errorMessage(m::Decoder, ::Type{T}) where T <: Nothing
            skip_errorMessage!(m)
            return nothing
        end
end
@inline function sbe_decoded_length(m::AbstractDiscoveryResponse)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            begin
                for group = results(m)
                    Results.sbe_skip!(group)
                end
            end
            skip_errorMessage!(m)
        end
        return
    end
end
module DiscoveryRequest
export AbstractDiscoveryRequest, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractDiscoveryRequest{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractDiscoveryRequest{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractDiscoveryRequest{T}
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
        if MessageHeader.templateId(header) != UInt16(1) || MessageHeader.schemaId(header) != UInt16(910)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(32)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(32))
        MessageHeader.templateId!(header, UInt16(1))
        MessageHeader.schemaId!(header, UInt16(910))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractDiscoveryRequest) = begin
        m.buffer
    end
sbe_offset(m::AbstractDiscoveryRequest) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractDiscoveryRequest) = begin
        m.position_ptr
    end
sbe_position(m::AbstractDiscoveryRequest) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractDiscoveryRequest, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractDiscoveryRequest) = begin
        UInt16(32)
    end
sbe_block_length(::Type{<:AbstractDiscoveryRequest}) = begin
        UInt16(32)
    end
sbe_template_id(::AbstractDiscoveryRequest) = begin
        UInt16(1)
    end
sbe_template_id(::Type{<:AbstractDiscoveryRequest}) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractDiscoveryRequest) = begin
        UInt16(910)
    end
sbe_schema_id(::Type{<:AbstractDiscoveryRequest}) = begin
        UInt16(910)
    end
sbe_schema_version(::AbstractDiscoveryRequest) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractDiscoveryRequest}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractDiscoveryRequest) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(32)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractDiscoveryRequest) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractDiscoveryRequest) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractDiscoveryRequest) = begin
        sbe_encoded_length(m)
    end
begin
    requestId_id(::AbstractDiscoveryRequest) = begin
            UInt16(1)
        end
    requestId_id(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(1)
        end
    requestId_since_version(::AbstractDiscoveryRequest) = begin
            UInt16(0)
        end
    requestId_since_version(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(0)
        end
    requestId_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    requestId_encoding_offset(::AbstractDiscoveryRequest) = begin
            Int(0)
        end
    requestId_encoding_offset(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(0)
        end
    requestId_encoding_length(::AbstractDiscoveryRequest) = begin
            Int(8)
        end
    requestId_encoding_length(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(8)
        end
    requestId_null_value(::AbstractDiscoveryRequest) = begin
            UInt64(18446744073709551615)
        end
    requestId_null_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt64(18446744073709551615)
        end
    requestId_min_value(::AbstractDiscoveryRequest) = begin
            UInt64(0)
        end
    requestId_min_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt64(0)
        end
    requestId_max_value(::AbstractDiscoveryRequest) = begin
            UInt64(18446744073709551614)
        end
    requestId_max_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function requestId_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function requestId_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function requestId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline requestId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export requestId, requestId!
end
begin
    clientId_id(::AbstractDiscoveryRequest) = begin
            UInt16(2)
        end
    clientId_id(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(2)
        end
    clientId_since_version(::AbstractDiscoveryRequest) = begin
            UInt16(0)
        end
    clientId_since_version(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(0)
        end
    clientId_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    clientId_encoding_offset(::AbstractDiscoveryRequest) = begin
            Int(8)
        end
    clientId_encoding_offset(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(8)
        end
    clientId_encoding_length(::AbstractDiscoveryRequest) = begin
            Int(4)
        end
    clientId_encoding_length(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(4)
        end
    clientId_null_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967295)
        end
    clientId_null_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967295)
        end
    clientId_min_value(::AbstractDiscoveryRequest) = begin
            UInt32(0)
        end
    clientId_min_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(0)
        end
    clientId_max_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967294)
        end
    clientId_max_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function clientId_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function clientId_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function clientId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 8)
        end
    @inline clientId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 8, val)
            end
    export clientId, clientId!
end
begin
    responseStreamId_id(::AbstractDiscoveryRequest) = begin
            UInt16(3)
        end
    responseStreamId_id(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(3)
        end
    responseStreamId_since_version(::AbstractDiscoveryRequest) = begin
            UInt16(0)
        end
    responseStreamId_since_version(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(0)
        end
    responseStreamId_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    responseStreamId_encoding_offset(::AbstractDiscoveryRequest) = begin
            Int(12)
        end
    responseStreamId_encoding_offset(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(12)
        end
    responseStreamId_encoding_length(::AbstractDiscoveryRequest) = begin
            Int(4)
        end
    responseStreamId_encoding_length(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(4)
        end
    responseStreamId_null_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967295)
        end
    responseStreamId_null_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967295)
        end
    responseStreamId_min_value(::AbstractDiscoveryRequest) = begin
            UInt32(0)
        end
    responseStreamId_min_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(0)
        end
    responseStreamId_max_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967294)
        end
    responseStreamId_max_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function responseStreamId_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function responseStreamId_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function responseStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 12)
        end
    @inline responseStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 12, val)
            end
    export responseStreamId, responseStreamId!
end
begin
    streamId_id(::AbstractDiscoveryRequest) = begin
            UInt16(4)
        end
    streamId_id(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(4)
        end
    streamId_since_version(::AbstractDiscoveryRequest) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractDiscoveryRequest) = begin
            Int(16)
        end
    streamId_encoding_offset(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(16)
        end
    streamId_encoding_length(::AbstractDiscoveryRequest) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractDiscoveryRequest) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function streamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 16)
        end
    @inline streamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 16, val)
            end
    export streamId, streamId!
end
begin
    producerId_id(::AbstractDiscoveryRequest) = begin
            UInt16(5)
        end
    producerId_id(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(5)
        end
    producerId_since_version(::AbstractDiscoveryRequest) = begin
            UInt16(0)
        end
    producerId_since_version(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(0)
        end
    producerId_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    producerId_encoding_offset(::AbstractDiscoveryRequest) = begin
            Int(20)
        end
    producerId_encoding_offset(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(20)
        end
    producerId_encoding_length(::AbstractDiscoveryRequest) = begin
            Int(4)
        end
    producerId_encoding_length(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(4)
        end
    producerId_null_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967295)
        end
    producerId_null_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967295)
        end
    producerId_min_value(::AbstractDiscoveryRequest) = begin
            UInt32(0)
        end
    producerId_min_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(0)
        end
    producerId_max_value(::AbstractDiscoveryRequest) = begin
            UInt32(4294967294)
        end
    producerId_max_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function producerId_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function producerId_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function producerId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 20)
        end
    @inline producerId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 20, val)
            end
    export producerId, producerId!
end
begin
    dataSourceId_id(::AbstractDiscoveryRequest) = begin
            UInt16(6)
        end
    dataSourceId_id(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(6)
        end
    dataSourceId_since_version(::AbstractDiscoveryRequest) = begin
            UInt16(0)
        end
    dataSourceId_since_version(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt16(0)
        end
    dataSourceId_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    dataSourceId_encoding_offset(::AbstractDiscoveryRequest) = begin
            Int(24)
        end
    dataSourceId_encoding_offset(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(24)
        end
    dataSourceId_encoding_length(::AbstractDiscoveryRequest) = begin
            Int(8)
        end
    dataSourceId_encoding_length(::Type{<:AbstractDiscoveryRequest}) = begin
            Int(8)
        end
    dataSourceId_null_value(::AbstractDiscoveryRequest) = begin
            UInt64(18446744073709551615)
        end
    dataSourceId_null_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt64(18446744073709551615)
        end
    dataSourceId_min_value(::AbstractDiscoveryRequest) = begin
            UInt64(0)
        end
    dataSourceId_min_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt64(0)
        end
    dataSourceId_max_value(::AbstractDiscoveryRequest) = begin
            UInt64(18446744073709551614)
        end
    dataSourceId_max_value(::Type{<:AbstractDiscoveryRequest}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function dataSourceId_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dataSourceId_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function dataSourceId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 24)
        end
    @inline dataSourceId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 24, val)
            end
    export dataSourceId, dataSourceId!
end
module Tags
using SBE: AbstractSbeGroup, PositionPointer, to_string
import SBE: sbe_header_size, sbe_block_length, sbe_acting_block_length, sbe_acting_version
import SBE: sbe_position, sbe_position!, sbe_position_ptr, next!
using StringViews: StringView
using ...VarAsciiEncoding
using ...GroupSizeEncoding
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
abstract type AbstractTags{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractTags{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    block_length::UInt16
    acting_version::UInt16
    count::UInt16
    index::UInt16
    function Decoder(buffer::T, offset::Integer, position_ptr::PositionPointer, block_length::Integer, acting_version::Integer, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, block_length, acting_version, UInt16(count), UInt16(index))
    end
end
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractTags{T}
    buffer::T
    offset::Int64
    position_ptr::PositionPointer
    initial_position::Int64
    count::UInt16
    index::UInt16
    function Encoder(buffer::T, offset::Integer, position_ptr::PositionPointer, initial_position::Int64, count::Integer, index::Integer) where T
        new{T}(buffer, offset, position_ptr, initial_position, UInt16(count), UInt16(index))
    end
end
@inline function Decoder(buffer, position_ptr::PositionPointer, acting_version)
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        return Decoder(buffer, 0, position_ptr, GroupSizeEncoding.blockLength(dimensions), acting_version, GroupSizeEncoding.numInGroup(dimensions), UInt16(0))
    end
@inline function reset!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        dimensions = GroupSizeEncoding.Decoder(buffer, position_ptr[])
        position_ptr[] += 4
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = GroupSizeEncoding.blockLength(dimensions)
        g.acting_version = acting_version
        g.count = GroupSizeEncoding.numInGroup(dimensions)
        g.index = UInt16(0)
        return g
    end
@inline function reset_missing!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.block_length = UInt16(0)
        g.acting_version = acting_version
        g.count = UInt16(0)
        g.index = UInt16(0)
        return g
    end
@inline function wrap!(g::Decoder{T}, buffer::T, position_ptr::PositionPointer, acting_version) where T
        return reset!(g, buffer, position_ptr, acting_version)
    end
@inline function Encoder(buffer, count, position_ptr::PositionPointer)
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(0))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        initial_position = position_ptr[]
        position_ptr[] += 4
        return Encoder(buffer, 0, position_ptr, initial_position, count, UInt16(0))
    end
@inline function wrap!(g::Encoder{T}, buffer::T, count, position_ptr::PositionPointer) where T
        if count > 65534
            error("count outside of allowed range")
        end
        dimensions = GroupSizeEncoding.Encoder(buffer, position_ptr[])
        GroupSizeEncoding.blockLength!(dimensions, UInt16(0))
        GroupSizeEncoding.numInGroup!(dimensions, count)
        g.buffer = buffer
        g.offset = 0
        g.position_ptr = position_ptr
        g.initial_position = position_ptr[]
        g.count = UInt16(count)
        g.index = UInt16(0)
        position_ptr[] += 4
        return g
    end
sbe_header_size(::AbstractTags) = begin
        4
    end
sbe_block_length(::AbstractTags) = begin
        UInt16(0)
    end
sbe_acting_block_length(g::Decoder) = begin
        g.block_length
    end
sbe_acting_block_length(g::Encoder) = begin
        UInt16(0)
    end
sbe_acting_version(g::Decoder) = begin
        g.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_position(g::AbstractTags) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractTags, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractTags) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractTags)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractTags, state = nothing)
    if g.index < g.count
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return (g, state)
    else
        return nothing
    end
end
Base.eltype(::Type{<:Decoder}) = begin
        Decoder
    end
Base.eltype(::Type{<:Encoder}) = begin
        Encoder
    end
Base.isdone(g::AbstractTags, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractTags) = begin
        Int(g.count)
    end
function reset_count_to_index!(g::Encoder)
    g.count = g.index
    dimensions = GroupSizeEncoding.Encoder(g.buffer, g.initial_position)
    GroupSizeEncoding.numInGroup!(dimensions, g.count)
    return g.count
end
export reset_count_to_index!
begin
    tag_id(::AbstractTags) = begin
            UInt16(1)
        end
    tag_id(::Type{<:AbstractTags}) = begin
            UInt16(1)
        end
    tag_since_version(::AbstractTags) = begin
            UInt16(0)
        end
    tag_since_version(::Type{<:AbstractTags}) = begin
            UInt16(0)
        end
    tag_in_acting_version(m::AbstractTags) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    tag_encoding_offset(::AbstractTags) = begin
            0
        end
    tag_encoding_offset(::Type{<:AbstractTags}) = begin
            0
        end
    tag_encoding_length(::AbstractTags) = begin
            -1
        end
    tag_encoding_length(::Type{<:AbstractTags}) = begin
            -1
        end
end
begin
    function tag_meta_attribute(::AbstractTags, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function tag_meta_attribute(::Type{<:AbstractTags}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function tag(m::Decoder)
            return VarAsciiEncoding.Decoder(m.buffer, m.offset + 0, m.acting_version)
        end
    @inline function tag(m::Encoder)
            return VarAsciiEncoding.Encoder(m.buffer, m.offset + 0)
        end
    export tag
end
@inline function sbe_skip!(m::Decoder)
        return
        return
    end
export AbstractTags, Decoder, Encoder
end
begin
    @inline function tags(m::AbstractDiscoveryRequest)
            return Tags.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function tags!(m::AbstractDiscoveryRequest, g::Tags.Decoder)
            return Tags.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function tags!(m::AbstractDiscoveryRequest, count)
            return Tags.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    tags_group_count!(m::Encoder, count) = begin
            tags!(m, count)
        end
    tags_id(::AbstractDiscoveryRequest) = begin
            UInt16(7)
        end
    tags_since_version(::AbstractDiscoveryRequest) = begin
            UInt16(0)
        end
    tags_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export tags, tags!, tags!, Tags
end
begin
    function responseChannel_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function responseChannel_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    responseChannel_character_encoding(::AbstractDiscoveryRequest) = begin
            "US-ASCII"
        end
    responseChannel_character_encoding(::Type{<:AbstractDiscoveryRequest}) = begin
            "US-ASCII"
        end
end
begin
    const responseChannel_id = UInt16(8)
    const responseChannel_since_version = UInt16(0)
    const responseChannel_header_length = 4
    responseChannel_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function responseChannel_length(m::AbstractDiscoveryRequest)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function responseChannel_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_responseChannel!(m::Decoder)
            len = responseChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function responseChannel(m::Decoder)
            len = responseChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function responseChannel_buffer!(m::Encoder, len)
            responseChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function responseChannel!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            responseChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function responseChannel!(m::Encoder, src::NTuple)
            len = sizeof(src)
            responseChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function responseChannel!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            responseChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline responseChannel!(m::Encoder, src::Symbol) = begin
                responseChannel!(m, to_string(src))
            end
    @inline responseChannel!(m::Encoder, src::Real) = begin
                responseChannel!(m, Tuple(src))
            end
    @inline responseChannel!(m::Encoder, ::Nothing) = begin
                responseChannel_buffer!(m, 0)
            end
end
begin
    @inline function responseChannel(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(responseChannel(m))))
        end
    @inline function responseChannel(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(responseChannel(m)))
        end
    @inline function responseChannel(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(responseChannel(m, StringView))
        end
    @inline function responseChannel(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, responseChannel(m)))[]
        end
    @inline function responseChannel(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, responseChannel(m))
        end
    @inline function responseChannel(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, responseChannel(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function responseChannel(m::Decoder, ::Type{T}) where T <: Nothing
            skip_responseChannel!(m)
            return nothing
        end
end
begin
    function dataSourceName_meta_attribute(::AbstractDiscoveryRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dataSourceName_meta_attribute(::Type{<:AbstractDiscoveryRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    dataSourceName_character_encoding(::AbstractDiscoveryRequest) = begin
            "US-ASCII"
        end
    dataSourceName_character_encoding(::Type{<:AbstractDiscoveryRequest}) = begin
            "US-ASCII"
        end
end
begin
    const dataSourceName_id = UInt16(9)
    const dataSourceName_since_version = UInt16(0)
    const dataSourceName_header_length = 4
    dataSourceName_in_acting_version(m::AbstractDiscoveryRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function dataSourceName_length(m::AbstractDiscoveryRequest)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function dataSourceName_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_dataSourceName!(m::Decoder)
            len = dataSourceName_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function dataSourceName(m::Decoder)
            len = dataSourceName_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function dataSourceName_buffer!(m::Encoder, len)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function dataSourceName!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function dataSourceName!(m::Encoder, src::NTuple)
            len = sizeof(src)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function dataSourceName!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            dataSourceName_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline dataSourceName!(m::Encoder, src::Symbol) = begin
                dataSourceName!(m, to_string(src))
            end
    @inline dataSourceName!(m::Encoder, src::Real) = begin
                dataSourceName!(m, Tuple(src))
            end
    @inline dataSourceName!(m::Encoder, ::Nothing) = begin
                dataSourceName_buffer!(m, 0)
            end
end
begin
    @inline function dataSourceName(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(dataSourceName(m))))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(dataSourceName(m)))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(dataSourceName(m, StringView))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, dataSourceName(m)))[]
        end
    @inline function dataSourceName(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, dataSourceName(m))
        end
    @inline function dataSourceName(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, dataSourceName(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function dataSourceName(m::Decoder, ::Type{T}) where T <: Nothing
            skip_dataSourceName!(m)
            return nothing
        end
end
@inline function sbe_decoded_length(m::AbstractDiscoveryRequest)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            begin
                for group = tags(m)
                    Tags.sbe_skip!(group)
                end
            end
            skip_responseChannel!(m)
            skip_dataSourceName!(m)
        end
        return
    end
end
end

const Shm_tensorpool_discovery = ShmTensorpoolDiscovery