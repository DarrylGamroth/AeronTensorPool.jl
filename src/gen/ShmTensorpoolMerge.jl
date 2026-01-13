module ShmTensorpoolMerge
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
@enumx T = SbeEnum ClockDomain::UInt8 begin
        MONOTONIC = 1
        REALTIME_SYNCED = 2
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum MergeRuleType::UInt8 begin
        OFFSET = 0
        WINDOW = 1
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum MergeTimeRuleType::UInt8 begin
        OFFSET_NS = 0
        WINDOW_NS = 1
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum TimestampSource::UInt8 begin
        FRAME_DESCRIPTOR = 1
        SLOT_HEADER = 2
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
        UInt16(903)
    end
sbe_schema_id(::Type{<:AbstractGroupSizeEncoding}) = begin
        UInt16(903)
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
        UInt16(903)
    end
sbe_schema_id(::Type{<:AbstractMessageHeader}) = begin
        UInt16(903)
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
module TimestampMergeMapRequest
export AbstractTimestampMergeMapRequest, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractTimestampMergeMapRequest{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractTimestampMergeMapRequest{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractTimestampMergeMapRequest{T}
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
        if MessageHeader.templateId(header) != UInt16(4) || MessageHeader.schemaId(header) != UInt16(903)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(12)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(12))
        MessageHeader.templateId!(header, UInt16(4))
        MessageHeader.schemaId!(header, UInt16(903))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractTimestampMergeMapRequest) = begin
        m.buffer
    end
sbe_offset(m::AbstractTimestampMergeMapRequest) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractTimestampMergeMapRequest) = begin
        m.position_ptr
    end
sbe_position(m::AbstractTimestampMergeMapRequest) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractTimestampMergeMapRequest, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractTimestampMergeMapRequest) = begin
        UInt16(12)
    end
sbe_block_length(::Type{<:AbstractTimestampMergeMapRequest}) = begin
        UInt16(12)
    end
sbe_template_id(::AbstractTimestampMergeMapRequest) = begin
        UInt16(4)
    end
sbe_template_id(::Type{<:AbstractTimestampMergeMapRequest}) = begin
        UInt16(4)
    end
sbe_schema_id(::AbstractTimestampMergeMapRequest) = begin
        UInt16(903)
    end
sbe_schema_id(::Type{<:AbstractTimestampMergeMapRequest}) = begin
        UInt16(903)
    end
sbe_schema_version(::AbstractTimestampMergeMapRequest) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractTimestampMergeMapRequest}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractTimestampMergeMapRequest) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(12)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractTimestampMergeMapRequest) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractTimestampMergeMapRequest) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractTimestampMergeMapRequest) = begin
        sbe_encoded_length(m)
    end
begin
    outStreamId_id(::AbstractTimestampMergeMapRequest) = begin
            UInt16(1)
        end
    outStreamId_id(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt16(1)
        end
    outStreamId_since_version(::AbstractTimestampMergeMapRequest) = begin
            UInt16(0)
        end
    outStreamId_since_version(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt16(0)
        end
    outStreamId_in_acting_version(m::AbstractTimestampMergeMapRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    outStreamId_encoding_offset(::AbstractTimestampMergeMapRequest) = begin
            Int(0)
        end
    outStreamId_encoding_offset(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            Int(0)
        end
    outStreamId_encoding_length(::AbstractTimestampMergeMapRequest) = begin
            Int(4)
        end
    outStreamId_encoding_length(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            Int(4)
        end
    outStreamId_null_value(::AbstractTimestampMergeMapRequest) = begin
            UInt32(4294967295)
        end
    outStreamId_null_value(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt32(4294967295)
        end
    outStreamId_min_value(::AbstractTimestampMergeMapRequest) = begin
            UInt32(0)
        end
    outStreamId_min_value(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt32(0)
        end
    outStreamId_max_value(::AbstractTimestampMergeMapRequest) = begin
            UInt32(4294967294)
        end
    outStreamId_max_value(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function outStreamId_meta_attribute(::AbstractTimestampMergeMapRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function outStreamId_meta_attribute(::Type{<:AbstractTimestampMergeMapRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function outStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline outStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export outStreamId, outStreamId!
end
begin
    epoch_id(::AbstractTimestampMergeMapRequest) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractTimestampMergeMapRequest) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractTimestampMergeMapRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractTimestampMergeMapRequest) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractTimestampMergeMapRequest) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractTimestampMergeMapRequest) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractTimestampMergeMapRequest) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractTimestampMergeMapRequest) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractTimestampMergeMapRequest}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractTimestampMergeMapRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractTimestampMergeMapRequest}, meta_attribute)
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
@inline function sbe_decoded_length(m::AbstractTimestampMergeMapRequest)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        return
        return
    end
end
module SequenceMergeMapRequest
export AbstractSequenceMergeMapRequest, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractSequenceMergeMapRequest{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractSequenceMergeMapRequest{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractSequenceMergeMapRequest{T}
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
        if MessageHeader.templateId(header) != UInt16(2) || MessageHeader.schemaId(header) != UInt16(903)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(12)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(12))
        MessageHeader.templateId!(header, UInt16(2))
        MessageHeader.schemaId!(header, UInt16(903))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractSequenceMergeMapRequest) = begin
        m.buffer
    end
sbe_offset(m::AbstractSequenceMergeMapRequest) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractSequenceMergeMapRequest) = begin
        m.position_ptr
    end
sbe_position(m::AbstractSequenceMergeMapRequest) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractSequenceMergeMapRequest, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractSequenceMergeMapRequest) = begin
        UInt16(12)
    end
sbe_block_length(::Type{<:AbstractSequenceMergeMapRequest}) = begin
        UInt16(12)
    end
sbe_template_id(::AbstractSequenceMergeMapRequest) = begin
        UInt16(2)
    end
sbe_template_id(::Type{<:AbstractSequenceMergeMapRequest}) = begin
        UInt16(2)
    end
sbe_schema_id(::AbstractSequenceMergeMapRequest) = begin
        UInt16(903)
    end
sbe_schema_id(::Type{<:AbstractSequenceMergeMapRequest}) = begin
        UInt16(903)
    end
sbe_schema_version(::AbstractSequenceMergeMapRequest) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractSequenceMergeMapRequest}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractSequenceMergeMapRequest) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(12)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractSequenceMergeMapRequest) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractSequenceMergeMapRequest) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractSequenceMergeMapRequest) = begin
        sbe_encoded_length(m)
    end
begin
    outStreamId_id(::AbstractSequenceMergeMapRequest) = begin
            UInt16(1)
        end
    outStreamId_id(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt16(1)
        end
    outStreamId_since_version(::AbstractSequenceMergeMapRequest) = begin
            UInt16(0)
        end
    outStreamId_since_version(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt16(0)
        end
    outStreamId_in_acting_version(m::AbstractSequenceMergeMapRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    outStreamId_encoding_offset(::AbstractSequenceMergeMapRequest) = begin
            Int(0)
        end
    outStreamId_encoding_offset(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            Int(0)
        end
    outStreamId_encoding_length(::AbstractSequenceMergeMapRequest) = begin
            Int(4)
        end
    outStreamId_encoding_length(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            Int(4)
        end
    outStreamId_null_value(::AbstractSequenceMergeMapRequest) = begin
            UInt32(4294967295)
        end
    outStreamId_null_value(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt32(4294967295)
        end
    outStreamId_min_value(::AbstractSequenceMergeMapRequest) = begin
            UInt32(0)
        end
    outStreamId_min_value(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt32(0)
        end
    outStreamId_max_value(::AbstractSequenceMergeMapRequest) = begin
            UInt32(4294967294)
        end
    outStreamId_max_value(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function outStreamId_meta_attribute(::AbstractSequenceMergeMapRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function outStreamId_meta_attribute(::Type{<:AbstractSequenceMergeMapRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function outStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline outStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export outStreamId, outStreamId!
end
begin
    epoch_id(::AbstractSequenceMergeMapRequest) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractSequenceMergeMapRequest) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractSequenceMergeMapRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractSequenceMergeMapRequest) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractSequenceMergeMapRequest) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractSequenceMergeMapRequest) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractSequenceMergeMapRequest) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractSequenceMergeMapRequest) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractSequenceMergeMapRequest}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractSequenceMergeMapRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractSequenceMergeMapRequest}, meta_attribute)
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
@inline function sbe_decoded_length(m::AbstractSequenceMergeMapRequest)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        return
        return
    end
end
module TimestampMergeMapAnnounce
export AbstractTimestampMergeMapAnnounce, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractTimestampMergeMapAnnounce{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..ClockDomain
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractTimestampMergeMapAnnounce{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractTimestampMergeMapAnnounce{T}
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
        if MessageHeader.templateId(header) != UInt16(3) || MessageHeader.schemaId(header) != UInt16(903)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(29)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(29))
        MessageHeader.templateId!(header, UInt16(3))
        MessageHeader.schemaId!(header, UInt16(903))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractTimestampMergeMapAnnounce) = begin
        m.buffer
    end
sbe_offset(m::AbstractTimestampMergeMapAnnounce) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractTimestampMergeMapAnnounce) = begin
        m.position_ptr
    end
sbe_position(m::AbstractTimestampMergeMapAnnounce) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractTimestampMergeMapAnnounce, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractTimestampMergeMapAnnounce) = begin
        UInt16(29)
    end
sbe_block_length(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
        UInt16(29)
    end
sbe_template_id(::AbstractTimestampMergeMapAnnounce) = begin
        UInt16(3)
    end
sbe_template_id(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
        UInt16(3)
    end
sbe_schema_id(::AbstractTimestampMergeMapAnnounce) = begin
        UInt16(903)
    end
sbe_schema_id(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
        UInt16(903)
    end
sbe_schema_version(::AbstractTimestampMergeMapAnnounce) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractTimestampMergeMapAnnounce) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(29)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractTimestampMergeMapAnnounce) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractTimestampMergeMapAnnounce) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractTimestampMergeMapAnnounce) = begin
        sbe_encoded_length(m)
    end
begin
    outStreamId_id(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(1)
        end
    outStreamId_id(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(1)
        end
    outStreamId_since_version(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(0)
        end
    outStreamId_since_version(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(0)
        end
    outStreamId_in_acting_version(m::AbstractTimestampMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    outStreamId_encoding_offset(::AbstractTimestampMergeMapAnnounce) = begin
            Int(0)
        end
    outStreamId_encoding_offset(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(0)
        end
    outStreamId_encoding_length(::AbstractTimestampMergeMapAnnounce) = begin
            Int(4)
        end
    outStreamId_encoding_length(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(4)
        end
    outStreamId_null_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt32(4294967295)
        end
    outStreamId_null_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt32(4294967295)
        end
    outStreamId_min_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt32(0)
        end
    outStreamId_min_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt32(0)
        end
    outStreamId_max_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt32(4294967294)
        end
    outStreamId_max_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function outStreamId_meta_attribute(::AbstractTimestampMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function outStreamId_meta_attribute(::Type{<:AbstractTimestampMergeMapAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function outStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline outStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export outStreamId, outStreamId!
end
begin
    epoch_id(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractTimestampMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractTimestampMergeMapAnnounce) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractTimestampMergeMapAnnounce) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractTimestampMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractTimestampMergeMapAnnounce}, meta_attribute)
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
    staleTimeoutNs_id(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(3)
        end
    staleTimeoutNs_id(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(3)
        end
    staleTimeoutNs_since_version(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(0)
        end
    staleTimeoutNs_since_version(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(0)
        end
    staleTimeoutNs_in_acting_version(m::AbstractTimestampMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    staleTimeoutNs_encoding_offset(::AbstractTimestampMergeMapAnnounce) = begin
            Int(12)
        end
    staleTimeoutNs_encoding_offset(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(12)
        end
    staleTimeoutNs_encoding_length(::AbstractTimestampMergeMapAnnounce) = begin
            Int(8)
        end
    staleTimeoutNs_encoding_length(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(8)
        end
    staleTimeoutNs_null_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(18446744073709551615)
        end
    staleTimeoutNs_null_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    staleTimeoutNs_min_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(0)
        end
    staleTimeoutNs_min_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(0)
        end
    staleTimeoutNs_max_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(18446744073709551614)
        end
    staleTimeoutNs_max_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function staleTimeoutNs_meta_attribute(::AbstractTimestampMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function staleTimeoutNs_meta_attribute(::Type{<:AbstractTimestampMergeMapAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function staleTimeoutNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 12)
        end
    @inline staleTimeoutNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 12, val)
            end
    export staleTimeoutNs, staleTimeoutNs!
end
begin
    clockDomain_id(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(4)
        end
    clockDomain_id(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(4)
        end
    clockDomain_since_version(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(0)
        end
    clockDomain_since_version(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(0)
        end
    clockDomain_in_acting_version(m::AbstractTimestampMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    clockDomain_encoding_offset(::AbstractTimestampMergeMapAnnounce) = begin
            Int(20)
        end
    clockDomain_encoding_offset(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(20)
        end
    clockDomain_encoding_length(::AbstractTimestampMergeMapAnnounce) = begin
            Int(1)
        end
    clockDomain_encoding_length(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(1)
        end
    clockDomain_null_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt8(255)
        end
    clockDomain_null_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt8(255)
        end
    clockDomain_min_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt8(0)
        end
    clockDomain_min_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt8(0)
        end
    clockDomain_max_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt8(254)
        end
    clockDomain_max_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt8(254)
        end
end
begin
    function clockDomain_meta_attribute(::AbstractTimestampMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function clockDomain_meta_attribute(::Type{<:AbstractTimestampMergeMapAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function clockDomain(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 20)
        end
    @inline function clockDomain(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 20)
            return ClockDomain.SbeEnum(raw)
        end
    @inline function clockDomain!(m::Encoder, value::ClockDomain.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 20, UInt8(value))
        end
    export clockDomain, clockDomain!
end
begin
    latenessNs_id(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(5)
        end
    latenessNs_id(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(5)
        end
    latenessNs_since_version(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(0)
        end
    latenessNs_since_version(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt16(0)
        end
    latenessNs_in_acting_version(m::AbstractTimestampMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    latenessNs_encoding_offset(::AbstractTimestampMergeMapAnnounce) = begin
            Int(21)
        end
    latenessNs_encoding_offset(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(21)
        end
    latenessNs_encoding_length(::AbstractTimestampMergeMapAnnounce) = begin
            Int(8)
        end
    latenessNs_encoding_length(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            Int(8)
        end
    latenessNs_null_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(18446744073709551615)
        end
    latenessNs_null_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    latenessNs_min_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(0)
        end
    latenessNs_min_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(0)
        end
    latenessNs_max_value(::AbstractTimestampMergeMapAnnounce) = begin
            UInt64(18446744073709551614)
        end
    latenessNs_max_value(::Type{<:AbstractTimestampMergeMapAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function latenessNs_meta_attribute(::AbstractTimestampMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function latenessNs_meta_attribute(::Type{<:AbstractTimestampMergeMapAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function latenessNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 21)
        end
    @inline latenessNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 21, val)
            end
    export latenessNs, latenessNs!
end
module Rules
using SBE: AbstractSbeGroup, PositionPointer, to_string
import SBE: sbe_header_size, sbe_block_length, sbe_acting_block_length, sbe_acting_version
import SBE: sbe_position, sbe_position!, sbe_position_ptr, next!
using StringViews: StringView
using ...TimestampSource
using ...MergeTimeRuleType
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
abstract type AbstractRules{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractRules{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractRules{T}
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
        GroupSizeEncoding.blockLength!(dimensions, UInt16(22))
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
        GroupSizeEncoding.blockLength!(dimensions, UInt16(22))
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
sbe_header_size(::AbstractRules) = begin
        4
    end
sbe_header_size(::Type{<:AbstractRules}) = begin
        4
    end
sbe_block_length(::AbstractRules) = begin
        UInt16(22)
    end
sbe_block_length(::Type{<:AbstractRules}) = begin
        UInt16(22)
    end
sbe_acting_block_length(g::Decoder) = begin
        g.block_length
    end
sbe_acting_block_length(g::Encoder) = begin
        UInt16(22)
    end
sbe_acting_version(g::Decoder) = begin
        g.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_acting_version(::Type{<:AbstractRules}) = begin
        UInt16(1)
    end
sbe_position(g::AbstractRules) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractRules, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractRules) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractRules)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractRules, state = nothing)
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
Base.isdone(g::AbstractRules, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractRules) = begin
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
    inputStreamId_id(::AbstractRules) = begin
            UInt16(7)
        end
    inputStreamId_id(::Type{<:AbstractRules}) = begin
            UInt16(7)
        end
    inputStreamId_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    inputStreamId_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    inputStreamId_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    inputStreamId_encoding_offset(::AbstractRules) = begin
            Int(0)
        end
    inputStreamId_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(0)
        end
    inputStreamId_encoding_length(::AbstractRules) = begin
            Int(4)
        end
    inputStreamId_encoding_length(::Type{<:AbstractRules}) = begin
            Int(4)
        end
    inputStreamId_null_value(::AbstractRules) = begin
            UInt32(4294967295)
        end
    inputStreamId_null_value(::Type{<:AbstractRules}) = begin
            UInt32(4294967295)
        end
    inputStreamId_min_value(::AbstractRules) = begin
            UInt32(0)
        end
    inputStreamId_min_value(::Type{<:AbstractRules}) = begin
            UInt32(0)
        end
    inputStreamId_max_value(::AbstractRules) = begin
            UInt32(4294967294)
        end
    inputStreamId_max_value(::Type{<:AbstractRules}) = begin
            UInt32(4294967294)
        end
end
begin
    function inputStreamId_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function inputStreamId_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function inputStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline inputStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export inputStreamId, inputStreamId!
end
begin
    ruleType_id(::AbstractRules) = begin
            UInt16(8)
        end
    ruleType_id(::Type{<:AbstractRules}) = begin
            UInt16(8)
        end
    ruleType_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    ruleType_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    ruleType_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    ruleType_encoding_offset(::AbstractRules) = begin
            Int(4)
        end
    ruleType_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(4)
        end
    ruleType_encoding_length(::AbstractRules) = begin
            Int(1)
        end
    ruleType_encoding_length(::Type{<:AbstractRules}) = begin
            Int(1)
        end
    ruleType_null_value(::AbstractRules) = begin
            UInt8(255)
        end
    ruleType_null_value(::Type{<:AbstractRules}) = begin
            UInt8(255)
        end
    ruleType_min_value(::AbstractRules) = begin
            UInt8(0)
        end
    ruleType_min_value(::Type{<:AbstractRules}) = begin
            UInt8(0)
        end
    ruleType_max_value(::AbstractRules) = begin
            UInt8(254)
        end
    ruleType_max_value(::Type{<:AbstractRules}) = begin
            UInt8(254)
        end
end
begin
    function ruleType_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function ruleType_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function ruleType(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 4)
        end
    @inline function ruleType(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 4)
            return MergeTimeRuleType.SbeEnum(raw)
        end
    @inline function ruleType!(m::Encoder, value::MergeTimeRuleType.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 4, UInt8(value))
        end
    export ruleType, ruleType!
end
begin
    timestampSource_id(::AbstractRules) = begin
            UInt16(9)
        end
    timestampSource_id(::Type{<:AbstractRules}) = begin
            UInt16(9)
        end
    timestampSource_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    timestampSource_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    timestampSource_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    timestampSource_encoding_offset(::AbstractRules) = begin
            Int(5)
        end
    timestampSource_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(5)
        end
    timestampSource_encoding_length(::AbstractRules) = begin
            Int(1)
        end
    timestampSource_encoding_length(::Type{<:AbstractRules}) = begin
            Int(1)
        end
    timestampSource_null_value(::AbstractRules) = begin
            UInt8(255)
        end
    timestampSource_null_value(::Type{<:AbstractRules}) = begin
            UInt8(255)
        end
    timestampSource_min_value(::AbstractRules) = begin
            UInt8(0)
        end
    timestampSource_min_value(::Type{<:AbstractRules}) = begin
            UInt8(0)
        end
    timestampSource_max_value(::AbstractRules) = begin
            UInt8(254)
        end
    timestampSource_max_value(::Type{<:AbstractRules}) = begin
            UInt8(254)
        end
end
begin
    function timestampSource_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function timestampSource_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function timestampSource(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 5)
        end
    @inline function timestampSource(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 5)
            return TimestampSource.SbeEnum(raw)
        end
    @inline function timestampSource!(m::Encoder, value::TimestampSource.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 5, UInt8(value))
        end
    export timestampSource, timestampSource!
end
begin
    offsetNs_id(::AbstractRules) = begin
            UInt16(10)
        end
    offsetNs_id(::Type{<:AbstractRules}) = begin
            UInt16(10)
        end
    offsetNs_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    offsetNs_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    offsetNs_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    offsetNs_encoding_offset(::AbstractRules) = begin
            Int(6)
        end
    offsetNs_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(6)
        end
    offsetNs_encoding_length(::AbstractRules) = begin
            Int(8)
        end
    offsetNs_encoding_length(::Type{<:AbstractRules}) = begin
            Int(8)
        end
    offsetNs_null_value(::AbstractRules) = begin
            Int64(-9223372036854775808)
        end
    offsetNs_null_value(::Type{<:AbstractRules}) = begin
            Int64(-9223372036854775808)
        end
    offsetNs_min_value(::AbstractRules) = begin
            Int64(-9223372036854775807)
        end
    offsetNs_min_value(::Type{<:AbstractRules}) = begin
            Int64(-9223372036854775807)
        end
    offsetNs_max_value(::AbstractRules) = begin
            Int64(9223372036854775807)
        end
    offsetNs_max_value(::Type{<:AbstractRules}) = begin
            Int64(9223372036854775807)
        end
end
begin
    function offsetNs_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function offsetNs_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function offsetNs(m::Decoder)
            return decode_value(Int64, m.buffer, m.offset + 6)
        end
    @inline offsetNs!(m::Encoder, val) = begin
                encode_value(Int64, m.buffer, m.offset + 6, val)
            end
    export offsetNs, offsetNs!
end
begin
    windowNs_id(::AbstractRules) = begin
            UInt16(11)
        end
    windowNs_id(::Type{<:AbstractRules}) = begin
            UInt16(11)
        end
    windowNs_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    windowNs_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    windowNs_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    windowNs_encoding_offset(::AbstractRules) = begin
            Int(14)
        end
    windowNs_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(14)
        end
    windowNs_encoding_length(::AbstractRules) = begin
            Int(8)
        end
    windowNs_encoding_length(::Type{<:AbstractRules}) = begin
            Int(8)
        end
    windowNs_null_value(::AbstractRules) = begin
            UInt64(18446744073709551615)
        end
    windowNs_null_value(::Type{<:AbstractRules}) = begin
            UInt64(18446744073709551615)
        end
    windowNs_min_value(::AbstractRules) = begin
            UInt64(0)
        end
    windowNs_min_value(::Type{<:AbstractRules}) = begin
            UInt64(0)
        end
    windowNs_max_value(::AbstractRules) = begin
            UInt64(18446744073709551614)
        end
    windowNs_max_value(::Type{<:AbstractRules}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function windowNs_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function windowNs_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function windowNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 14)
        end
    @inline windowNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 14, val)
            end
    export windowNs, windowNs!
end
@inline function sbe_skip!(m::Decoder)
        return
        return
    end
export AbstractRules, Decoder, Encoder
end
begin
    @inline function rules(m::AbstractTimestampMergeMapAnnounce)
            return Rules.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function rules!(m::AbstractTimestampMergeMapAnnounce, g::Rules.Decoder)
            return Rules.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function rules!(m::AbstractTimestampMergeMapAnnounce, count)
            return Rules.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    rules_group_count!(m::Encoder, count) = begin
            rules!(m, count)
        end
    rules_id(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(6)
        end
    rules_since_version(::AbstractTimestampMergeMapAnnounce) = begin
            UInt16(0)
        end
    rules_in_acting_version(m::AbstractTimestampMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export rules, rules!, rules!, Rules
end
@inline function sbe_decoded_length(m::AbstractTimestampMergeMapAnnounce)
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
                for group = rules(m)
                    Rules.sbe_skip!(group)
                end
            end
        end
        return
    end
end
module SequenceMergeMapAnnounce
export AbstractSequenceMergeMapAnnounce, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractSequenceMergeMapAnnounce{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractSequenceMergeMapAnnounce{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractSequenceMergeMapAnnounce{T}
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
        if MessageHeader.templateId(header) != UInt16(1) || MessageHeader.schemaId(header) != UInt16(903)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(20)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(20))
        MessageHeader.templateId!(header, UInt16(1))
        MessageHeader.schemaId!(header, UInt16(903))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractSequenceMergeMapAnnounce) = begin
        m.buffer
    end
sbe_offset(m::AbstractSequenceMergeMapAnnounce) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractSequenceMergeMapAnnounce) = begin
        m.position_ptr
    end
sbe_position(m::AbstractSequenceMergeMapAnnounce) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractSequenceMergeMapAnnounce, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractSequenceMergeMapAnnounce) = begin
        UInt16(20)
    end
sbe_block_length(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
        UInt16(20)
    end
sbe_template_id(::AbstractSequenceMergeMapAnnounce) = begin
        UInt16(1)
    end
sbe_template_id(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractSequenceMergeMapAnnounce) = begin
        UInt16(903)
    end
sbe_schema_id(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
        UInt16(903)
    end
sbe_schema_version(::AbstractSequenceMergeMapAnnounce) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractSequenceMergeMapAnnounce) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(20)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractSequenceMergeMapAnnounce) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractSequenceMergeMapAnnounce) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractSequenceMergeMapAnnounce) = begin
        sbe_encoded_length(m)
    end
begin
    outStreamId_id(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(1)
        end
    outStreamId_id(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt16(1)
        end
    outStreamId_since_version(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(0)
        end
    outStreamId_since_version(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt16(0)
        end
    outStreamId_in_acting_version(m::AbstractSequenceMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    outStreamId_encoding_offset(::AbstractSequenceMergeMapAnnounce) = begin
            Int(0)
        end
    outStreamId_encoding_offset(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            Int(0)
        end
    outStreamId_encoding_length(::AbstractSequenceMergeMapAnnounce) = begin
            Int(4)
        end
    outStreamId_encoding_length(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            Int(4)
        end
    outStreamId_null_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt32(4294967295)
        end
    outStreamId_null_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt32(4294967295)
        end
    outStreamId_min_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt32(0)
        end
    outStreamId_min_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt32(0)
        end
    outStreamId_max_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt32(4294967294)
        end
    outStreamId_max_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function outStreamId_meta_attribute(::AbstractSequenceMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function outStreamId_meta_attribute(::Type{<:AbstractSequenceMergeMapAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function outStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline outStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export outStreamId, outStreamId!
end
begin
    epoch_id(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractSequenceMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractSequenceMergeMapAnnounce) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractSequenceMergeMapAnnounce) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractSequenceMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractSequenceMergeMapAnnounce}, meta_attribute)
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
    staleTimeoutNs_id(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(3)
        end
    staleTimeoutNs_id(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt16(3)
        end
    staleTimeoutNs_since_version(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(0)
        end
    staleTimeoutNs_since_version(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt16(0)
        end
    staleTimeoutNs_in_acting_version(m::AbstractSequenceMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    staleTimeoutNs_encoding_offset(::AbstractSequenceMergeMapAnnounce) = begin
            Int(12)
        end
    staleTimeoutNs_encoding_offset(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            Int(12)
        end
    staleTimeoutNs_encoding_length(::AbstractSequenceMergeMapAnnounce) = begin
            Int(8)
        end
    staleTimeoutNs_encoding_length(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            Int(8)
        end
    staleTimeoutNs_null_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt64(18446744073709551615)
        end
    staleTimeoutNs_null_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    staleTimeoutNs_min_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt64(0)
        end
    staleTimeoutNs_min_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt64(0)
        end
    staleTimeoutNs_max_value(::AbstractSequenceMergeMapAnnounce) = begin
            UInt64(18446744073709551614)
        end
    staleTimeoutNs_max_value(::Type{<:AbstractSequenceMergeMapAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function staleTimeoutNs_meta_attribute(::AbstractSequenceMergeMapAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function staleTimeoutNs_meta_attribute(::Type{<:AbstractSequenceMergeMapAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function staleTimeoutNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 12)
        end
    @inline staleTimeoutNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 12, val)
            end
    export staleTimeoutNs, staleTimeoutNs!
end
module Rules
using SBE: AbstractSbeGroup, PositionPointer, to_string
import SBE: sbe_header_size, sbe_block_length, sbe_acting_block_length, sbe_acting_version
import SBE: sbe_position, sbe_position!, sbe_position_ptr, next!
using StringViews: StringView
using ...MergeRuleType
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
abstract type AbstractRules{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractRules{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractRules{T}
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
        GroupSizeEncoding.blockLength!(dimensions, UInt16(13))
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
        GroupSizeEncoding.blockLength!(dimensions, UInt16(13))
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
sbe_header_size(::AbstractRules) = begin
        4
    end
sbe_header_size(::Type{<:AbstractRules}) = begin
        4
    end
sbe_block_length(::AbstractRules) = begin
        UInt16(13)
    end
sbe_block_length(::Type{<:AbstractRules}) = begin
        UInt16(13)
    end
sbe_acting_block_length(g::Decoder) = begin
        g.block_length
    end
sbe_acting_block_length(g::Encoder) = begin
        UInt16(13)
    end
sbe_acting_version(g::Decoder) = begin
        g.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_acting_version(::Type{<:AbstractRules}) = begin
        UInt16(1)
    end
sbe_position(g::AbstractRules) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractRules, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractRules) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractRules)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractRules, state = nothing)
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
Base.isdone(g::AbstractRules, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractRules) = begin
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
    inputStreamId_id(::AbstractRules) = begin
            UInt16(5)
        end
    inputStreamId_id(::Type{<:AbstractRules}) = begin
            UInt16(5)
        end
    inputStreamId_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    inputStreamId_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    inputStreamId_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    inputStreamId_encoding_offset(::AbstractRules) = begin
            Int(0)
        end
    inputStreamId_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(0)
        end
    inputStreamId_encoding_length(::AbstractRules) = begin
            Int(4)
        end
    inputStreamId_encoding_length(::Type{<:AbstractRules}) = begin
            Int(4)
        end
    inputStreamId_null_value(::AbstractRules) = begin
            UInt32(4294967295)
        end
    inputStreamId_null_value(::Type{<:AbstractRules}) = begin
            UInt32(4294967295)
        end
    inputStreamId_min_value(::AbstractRules) = begin
            UInt32(0)
        end
    inputStreamId_min_value(::Type{<:AbstractRules}) = begin
            UInt32(0)
        end
    inputStreamId_max_value(::AbstractRules) = begin
            UInt32(4294967294)
        end
    inputStreamId_max_value(::Type{<:AbstractRules}) = begin
            UInt32(4294967294)
        end
end
begin
    function inputStreamId_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function inputStreamId_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function inputStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 0)
        end
    @inline inputStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 0, val)
            end
    export inputStreamId, inputStreamId!
end
begin
    ruleType_id(::AbstractRules) = begin
            UInt16(6)
        end
    ruleType_id(::Type{<:AbstractRules}) = begin
            UInt16(6)
        end
    ruleType_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    ruleType_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    ruleType_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    ruleType_encoding_offset(::AbstractRules) = begin
            Int(4)
        end
    ruleType_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(4)
        end
    ruleType_encoding_length(::AbstractRules) = begin
            Int(1)
        end
    ruleType_encoding_length(::Type{<:AbstractRules}) = begin
            Int(1)
        end
    ruleType_null_value(::AbstractRules) = begin
            UInt8(255)
        end
    ruleType_null_value(::Type{<:AbstractRules}) = begin
            UInt8(255)
        end
    ruleType_min_value(::AbstractRules) = begin
            UInt8(0)
        end
    ruleType_min_value(::Type{<:AbstractRules}) = begin
            UInt8(0)
        end
    ruleType_max_value(::AbstractRules) = begin
            UInt8(254)
        end
    ruleType_max_value(::Type{<:AbstractRules}) = begin
            UInt8(254)
        end
end
begin
    function ruleType_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function ruleType_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function ruleType(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 4)
        end
    @inline function ruleType(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 4)
            return MergeRuleType.SbeEnum(raw)
        end
    @inline function ruleType!(m::Encoder, value::MergeRuleType.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 4, UInt8(value))
        end
    export ruleType, ruleType!
end
begin
    offset_id(::AbstractRules) = begin
            UInt16(7)
        end
    offset_id(::Type{<:AbstractRules}) = begin
            UInt16(7)
        end
    offset_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    offset_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    offset_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    offset_encoding_offset(::AbstractRules) = begin
            Int(5)
        end
    offset_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(5)
        end
    offset_encoding_length(::AbstractRules) = begin
            Int(4)
        end
    offset_encoding_length(::Type{<:AbstractRules}) = begin
            Int(4)
        end
    offset_null_value(::AbstractRules) = begin
            Int32(-2147483648)
        end
    offset_null_value(::Type{<:AbstractRules}) = begin
            Int32(-2147483648)
        end
    offset_min_value(::AbstractRules) = begin
            Int32(-2147483647)
        end
    offset_min_value(::Type{<:AbstractRules}) = begin
            Int32(-2147483647)
        end
    offset_max_value(::AbstractRules) = begin
            Int32(2147483647)
        end
    offset_max_value(::Type{<:AbstractRules}) = begin
            Int32(2147483647)
        end
end
begin
    function offset_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function offset_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function offset(m::Decoder)
            return decode_value(Int32, m.buffer, m.offset + 5)
        end
    @inline offset!(m::Encoder, val) = begin
                encode_value(Int32, m.buffer, m.offset + 5, val)
            end
    export offset, offset!
end
begin
    windowSize_id(::AbstractRules) = begin
            UInt16(8)
        end
    windowSize_id(::Type{<:AbstractRules}) = begin
            UInt16(8)
        end
    windowSize_since_version(::AbstractRules) = begin
            UInt16(0)
        end
    windowSize_since_version(::Type{<:AbstractRules}) = begin
            UInt16(0)
        end
    windowSize_in_acting_version(m::AbstractRules) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    windowSize_encoding_offset(::AbstractRules) = begin
            Int(9)
        end
    windowSize_encoding_offset(::Type{<:AbstractRules}) = begin
            Int(9)
        end
    windowSize_encoding_length(::AbstractRules) = begin
            Int(4)
        end
    windowSize_encoding_length(::Type{<:AbstractRules}) = begin
            Int(4)
        end
    windowSize_null_value(::AbstractRules) = begin
            UInt32(4294967295)
        end
    windowSize_null_value(::Type{<:AbstractRules}) = begin
            UInt32(4294967295)
        end
    windowSize_min_value(::AbstractRules) = begin
            UInt32(0)
        end
    windowSize_min_value(::Type{<:AbstractRules}) = begin
            UInt32(0)
        end
    windowSize_max_value(::AbstractRules) = begin
            UInt32(4294967294)
        end
    windowSize_max_value(::Type{<:AbstractRules}) = begin
            UInt32(4294967294)
        end
end
begin
    function windowSize_meta_attribute(::AbstractRules, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function windowSize_meta_attribute(::Type{<:AbstractRules}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function windowSize(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 9)
        end
    @inline windowSize!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 9, val)
            end
    export windowSize, windowSize!
end
@inline function sbe_skip!(m::Decoder)
        return
        return
    end
export AbstractRules, Decoder, Encoder
end
begin
    @inline function rules(m::AbstractSequenceMergeMapAnnounce)
            return Rules.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function rules!(m::AbstractSequenceMergeMapAnnounce, g::Rules.Decoder)
            return Rules.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function rules!(m::AbstractSequenceMergeMapAnnounce, count)
            return Rules.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    rules_group_count!(m::Encoder, count) = begin
            rules!(m, count)
        end
    rules_id(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(4)
        end
    rules_since_version(::AbstractSequenceMergeMapAnnounce) = begin
            UInt16(0)
        end
    rules_in_acting_version(m::AbstractSequenceMergeMapAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export rules, rules!, rules!, Rules
end
@inline function sbe_decoded_length(m::AbstractSequenceMergeMapAnnounce)
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
                for group = rules(m)
                    Rules.sbe_skip!(group)
                end
            end
        end
        return
    end
end
end

const Shm_tensorpool_merge = ShmTensorpoolMerge