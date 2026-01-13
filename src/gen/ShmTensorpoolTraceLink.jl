module ShmTensorpoolTraceLink
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
        UInt16(904)
    end
sbe_schema_id(::Type{<:AbstractGroupSizeEncoding}) = begin
        UInt16(904)
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
        UInt16(904)
    end
sbe_schema_id(::Type{<:AbstractMessageHeader}) = begin
        UInt16(904)
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
module TraceLinkSet
export AbstractTraceLinkSet, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractTraceLinkSet{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractTraceLinkSet{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractTraceLinkSet{T}
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
        if MessageHeader.templateId(header) != UInt16(1) || MessageHeader.schemaId(header) != UInt16(904)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(28)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(28))
        MessageHeader.templateId!(header, UInt16(1))
        MessageHeader.schemaId!(header, UInt16(904))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractTraceLinkSet) = begin
        m.buffer
    end
sbe_offset(m::AbstractTraceLinkSet) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractTraceLinkSet) = begin
        m.position_ptr
    end
sbe_position(m::AbstractTraceLinkSet) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractTraceLinkSet, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractTraceLinkSet) = begin
        UInt16(28)
    end
sbe_block_length(::Type{<:AbstractTraceLinkSet}) = begin
        UInt16(28)
    end
sbe_template_id(::AbstractTraceLinkSet) = begin
        UInt16(1)
    end
sbe_template_id(::Type{<:AbstractTraceLinkSet}) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractTraceLinkSet) = begin
        UInt16(904)
    end
sbe_schema_id(::Type{<:AbstractTraceLinkSet}) = begin
        UInt16(904)
    end
sbe_schema_version(::AbstractTraceLinkSet) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractTraceLinkSet}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractTraceLinkSet) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(28)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractTraceLinkSet) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractTraceLinkSet) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractTraceLinkSet) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractTraceLinkSet) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractTraceLinkSet) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractTraceLinkSet) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractTraceLinkSet) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractTraceLinkSet}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractTraceLinkSet) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractTraceLinkSet}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractTraceLinkSet) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractTraceLinkSet) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractTraceLinkSet) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractTraceLinkSet, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractTraceLinkSet}, meta_attribute)
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
    epoch_id(::AbstractTraceLinkSet) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractTraceLinkSet) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractTraceLinkSet) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractTraceLinkSet) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractTraceLinkSet}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractTraceLinkSet) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractTraceLinkSet}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractTraceLinkSet) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractTraceLinkSet) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractTraceLinkSet) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractTraceLinkSet, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractTraceLinkSet}, meta_attribute)
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
    seq_id(::AbstractTraceLinkSet) = begin
            UInt16(3)
        end
    seq_id(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(3)
        end
    seq_since_version(::AbstractTraceLinkSet) = begin
            UInt16(0)
        end
    seq_since_version(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(0)
        end
    seq_in_acting_version(m::AbstractTraceLinkSet) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    seq_encoding_offset(::AbstractTraceLinkSet) = begin
            Int(12)
        end
    seq_encoding_offset(::Type{<:AbstractTraceLinkSet}) = begin
            Int(12)
        end
    seq_encoding_length(::AbstractTraceLinkSet) = begin
            Int(8)
        end
    seq_encoding_length(::Type{<:AbstractTraceLinkSet}) = begin
            Int(8)
        end
    seq_null_value(::AbstractTraceLinkSet) = begin
            UInt64(18446744073709551615)
        end
    seq_null_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(18446744073709551615)
        end
    seq_min_value(::AbstractTraceLinkSet) = begin
            UInt64(0)
        end
    seq_min_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(0)
        end
    seq_max_value(::AbstractTraceLinkSet) = begin
            UInt64(18446744073709551614)
        end
    seq_max_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function seq_meta_attribute(::AbstractTraceLinkSet, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function seq_meta_attribute(::Type{<:AbstractTraceLinkSet}, meta_attribute)
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
    traceId_id(::AbstractTraceLinkSet) = begin
            UInt16(4)
        end
    traceId_id(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(4)
        end
    traceId_since_version(::AbstractTraceLinkSet) = begin
            UInt16(0)
        end
    traceId_since_version(::Type{<:AbstractTraceLinkSet}) = begin
            UInt16(0)
        end
    traceId_in_acting_version(m::AbstractTraceLinkSet) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    traceId_encoding_offset(::AbstractTraceLinkSet) = begin
            Int(20)
        end
    traceId_encoding_offset(::Type{<:AbstractTraceLinkSet}) = begin
            Int(20)
        end
    traceId_encoding_length(::AbstractTraceLinkSet) = begin
            Int(8)
        end
    traceId_encoding_length(::Type{<:AbstractTraceLinkSet}) = begin
            Int(8)
        end
    traceId_null_value(::AbstractTraceLinkSet) = begin
            UInt64(18446744073709551615)
        end
    traceId_null_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(18446744073709551615)
        end
    traceId_min_value(::AbstractTraceLinkSet) = begin
            UInt64(0)
        end
    traceId_min_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(0)
        end
    traceId_max_value(::AbstractTraceLinkSet) = begin
            UInt64(18446744073709551614)
        end
    traceId_max_value(::Type{<:AbstractTraceLinkSet}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function traceId_meta_attribute(::AbstractTraceLinkSet, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function traceId_meta_attribute(::Type{<:AbstractTraceLinkSet}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
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
module Parents
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
abstract type AbstractParents{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractParents{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractParents{T}
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
        GroupSizeEncoding.blockLength!(dimensions, UInt16(8))
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
        GroupSizeEncoding.blockLength!(dimensions, UInt16(8))
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
sbe_header_size(::AbstractParents) = begin
        4
    end
sbe_header_size(::Type{<:AbstractParents}) = begin
        4
    end
sbe_block_length(::AbstractParents) = begin
        UInt16(8)
    end
sbe_block_length(::Type{<:AbstractParents}) = begin
        UInt16(8)
    end
sbe_acting_block_length(g::Decoder) = begin
        g.block_length
    end
sbe_acting_block_length(g::Encoder) = begin
        UInt16(8)
    end
sbe_acting_version(g::Decoder) = begin
        g.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_acting_version(::Type{<:AbstractParents}) = begin
        UInt16(1)
    end
sbe_position(g::AbstractParents) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractParents, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractParents) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractParents)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractParents, state = nothing)
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
Base.isdone(g::AbstractParents, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractParents) = begin
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
    traceId_id(::AbstractParents) = begin
            UInt16(6)
        end
    traceId_id(::Type{<:AbstractParents}) = begin
            UInt16(6)
        end
    traceId_since_version(::AbstractParents) = begin
            UInt16(0)
        end
    traceId_since_version(::Type{<:AbstractParents}) = begin
            UInt16(0)
        end
    traceId_in_acting_version(m::AbstractParents) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    traceId_encoding_offset(::AbstractParents) = begin
            Int(0)
        end
    traceId_encoding_offset(::Type{<:AbstractParents}) = begin
            Int(0)
        end
    traceId_encoding_length(::AbstractParents) = begin
            Int(8)
        end
    traceId_encoding_length(::Type{<:AbstractParents}) = begin
            Int(8)
        end
    traceId_null_value(::AbstractParents) = begin
            UInt64(18446744073709551615)
        end
    traceId_null_value(::Type{<:AbstractParents}) = begin
            UInt64(18446744073709551615)
        end
    traceId_min_value(::AbstractParents) = begin
            UInt64(0)
        end
    traceId_min_value(::Type{<:AbstractParents}) = begin
            UInt64(0)
        end
    traceId_max_value(::AbstractParents) = begin
            UInt64(18446744073709551614)
        end
    traceId_max_value(::Type{<:AbstractParents}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function traceId_meta_attribute(::AbstractParents, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function traceId_meta_attribute(::Type{<:AbstractParents}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function traceId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline traceId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export traceId, traceId!
end
@inline function sbe_skip!(m::Decoder)
        return
        return
    end
export AbstractParents, Decoder, Encoder
end
begin
    @inline function parents(m::AbstractTraceLinkSet)
            return Parents.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function parents!(m::AbstractTraceLinkSet, g::Parents.Decoder)
            return Parents.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function parents!(m::AbstractTraceLinkSet, count)
            return Parents.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    parents_group_count!(m::Encoder, count) = begin
            parents!(m, count)
        end
    parents_id(::AbstractTraceLinkSet) = begin
            UInt16(5)
        end
    parents_since_version(::AbstractTraceLinkSet) = begin
            UInt16(0)
        end
    parents_in_acting_version(m::AbstractTraceLinkSet) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export parents, parents!, parents!, Parents
end
@inline function sbe_decoded_length(m::AbstractTraceLinkSet)
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
                for group = parents(m)
                    Parents.sbe_skip!(group)
                end
            end
        end
        return
    end
end
end

const Shm_tensorpool_tracelink = ShmTensorpoolTraceLink