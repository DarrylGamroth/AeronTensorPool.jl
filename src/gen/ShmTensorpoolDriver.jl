module ShmTensorpoolDriver
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
@enumx T = SbeEnum HugepagesPolicy::UInt8 begin
        UNSPECIFIED = 0
        STANDARD = 1
        HUGEPAGES = 2
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum LeaseRevokeReason::UInt8 begin
        DETACHED = 1
        EXPIRED = 2
        REVOKED = 3
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum PublishMode::UInt8 begin
        REQUIRE_EXISTING = 1
        EXISTING_OR_CREATE = 2
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum ResponseCode::Int32 begin
        OK = 0
        UNSUPPORTED = 1
        INVALID_PARAMS = 2
        REJECTED = 3
        INTERNAL_ERROR = 4
        NULL_VALUE = Int32(-2147483648)
    end
@enumx T = SbeEnum Role::UInt8 begin
        PRODUCER = 1
        CONSUMER = 2
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum ShutdownReason::UInt8 begin
        NORMAL = 0
        ADMIN = 1
        ERROR = 2
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
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractGroupSizeEncoding}) = begin
        UInt16(901)
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
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractMessageHeader}) = begin
        UInt16(901)
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
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractVarAsciiEncoding}) = begin
        UInt16(901)
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
module ShmLeaseKeepalive
export AbstractShmLeaseKeepalive, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmLeaseKeepalive{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Role
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmLeaseKeepalive{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmLeaseKeepalive{T}
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
        if MessageHeader.templateId(header) != UInt16(5) || MessageHeader.schemaId(header) != UInt16(901)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(25)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(25))
        MessageHeader.templateId!(header, UInt16(5))
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmLeaseKeepalive) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmLeaseKeepalive) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmLeaseKeepalive) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmLeaseKeepalive) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmLeaseKeepalive, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmLeaseKeepalive) = begin
        UInt16(25)
    end
sbe_block_length(::Type{<:AbstractShmLeaseKeepalive}) = begin
        UInt16(25)
    end
sbe_template_id(::AbstractShmLeaseKeepalive) = begin
        UInt16(5)
    end
sbe_template_id(::Type{<:AbstractShmLeaseKeepalive}) = begin
        UInt16(5)
    end
sbe_schema_id(::AbstractShmLeaseKeepalive) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmLeaseKeepalive}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmLeaseKeepalive) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmLeaseKeepalive}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmLeaseKeepalive) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(25)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractShmLeaseKeepalive) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmLeaseKeepalive) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmLeaseKeepalive) = begin
        sbe_encoded_length(m)
    end
begin
    leaseId_id(::AbstractShmLeaseKeepalive) = begin
            UInt16(1)
        end
    leaseId_id(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(1)
        end
    leaseId_since_version(::AbstractShmLeaseKeepalive) = begin
            UInt16(0)
        end
    leaseId_since_version(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(0)
        end
    leaseId_in_acting_version(m::AbstractShmLeaseKeepalive) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    leaseId_encoding_offset(::AbstractShmLeaseKeepalive) = begin
            Int(0)
        end
    leaseId_encoding_offset(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(0)
        end
    leaseId_encoding_length(::AbstractShmLeaseKeepalive) = begin
            Int(8)
        end
    leaseId_encoding_length(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(8)
        end
    leaseId_null_value(::AbstractShmLeaseKeepalive) = begin
            UInt64(18446744073709551615)
        end
    leaseId_null_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt64(18446744073709551615)
        end
    leaseId_min_value(::AbstractShmLeaseKeepalive) = begin
            UInt64(0)
        end
    leaseId_min_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt64(0)
        end
    leaseId_max_value(::AbstractShmLeaseKeepalive) = begin
            UInt64(18446744073709551614)
        end
    leaseId_max_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function leaseId_meta_attribute(::AbstractShmLeaseKeepalive, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function leaseId_meta_attribute(::Type{<:AbstractShmLeaseKeepalive}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function leaseId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline leaseId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export leaseId, leaseId!
end
begin
    streamId_id(::AbstractShmLeaseKeepalive) = begin
            UInt16(2)
        end
    streamId_id(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(2)
        end
    streamId_since_version(::AbstractShmLeaseKeepalive) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractShmLeaseKeepalive) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractShmLeaseKeepalive) = begin
            Int(8)
        end
    streamId_encoding_offset(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(8)
        end
    streamId_encoding_length(::AbstractShmLeaseKeepalive) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractShmLeaseKeepalive) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractShmLeaseKeepalive) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractShmLeaseKeepalive) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractShmLeaseKeepalive, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractShmLeaseKeepalive}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function streamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 8)
        end
    @inline streamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 8, val)
            end
    export streamId, streamId!
end
begin
    clientId_id(::AbstractShmLeaseKeepalive) = begin
            UInt16(3)
        end
    clientId_id(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(3)
        end
    clientId_since_version(::AbstractShmLeaseKeepalive) = begin
            UInt16(0)
        end
    clientId_since_version(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(0)
        end
    clientId_in_acting_version(m::AbstractShmLeaseKeepalive) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    clientId_encoding_offset(::AbstractShmLeaseKeepalive) = begin
            Int(12)
        end
    clientId_encoding_offset(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(12)
        end
    clientId_encoding_length(::AbstractShmLeaseKeepalive) = begin
            Int(4)
        end
    clientId_encoding_length(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(4)
        end
    clientId_null_value(::AbstractShmLeaseKeepalive) = begin
            UInt32(4294967295)
        end
    clientId_null_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt32(4294967295)
        end
    clientId_min_value(::AbstractShmLeaseKeepalive) = begin
            UInt32(0)
        end
    clientId_min_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt32(0)
        end
    clientId_max_value(::AbstractShmLeaseKeepalive) = begin
            UInt32(4294967294)
        end
    clientId_max_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt32(4294967294)
        end
end
begin
    function clientId_meta_attribute(::AbstractShmLeaseKeepalive, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function clientId_meta_attribute(::Type{<:AbstractShmLeaseKeepalive}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function clientId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 12)
        end
    @inline clientId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 12, val)
            end
    export clientId, clientId!
end
begin
    role_id(::AbstractShmLeaseKeepalive) = begin
            UInt16(4)
        end
    role_id(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(4)
        end
    role_since_version(::AbstractShmLeaseKeepalive) = begin
            UInt16(0)
        end
    role_since_version(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(0)
        end
    role_in_acting_version(m::AbstractShmLeaseKeepalive) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    role_encoding_offset(::AbstractShmLeaseKeepalive) = begin
            Int(16)
        end
    role_encoding_offset(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(16)
        end
    role_encoding_length(::AbstractShmLeaseKeepalive) = begin
            Int(1)
        end
    role_encoding_length(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(1)
        end
    role_null_value(::AbstractShmLeaseKeepalive) = begin
            UInt8(255)
        end
    role_null_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt8(255)
        end
    role_min_value(::AbstractShmLeaseKeepalive) = begin
            UInt8(0)
        end
    role_min_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt8(0)
        end
    role_max_value(::AbstractShmLeaseKeepalive) = begin
            UInt8(254)
        end
    role_max_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt8(254)
        end
end
begin
    function role_meta_attribute(::AbstractShmLeaseKeepalive, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function role_meta_attribute(::Type{<:AbstractShmLeaseKeepalive}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function role(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 16)
        end
    @inline function role(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 16)
            return Role.SbeEnum(raw)
        end
    @inline function role!(m::Encoder, value::Role.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 16, UInt8(value))
        end
    export role, role!
end
begin
    clientTimestampNs_id(::AbstractShmLeaseKeepalive) = begin
            UInt16(5)
        end
    clientTimestampNs_id(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(5)
        end
    clientTimestampNs_since_version(::AbstractShmLeaseKeepalive) = begin
            UInt16(0)
        end
    clientTimestampNs_since_version(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt16(0)
        end
    clientTimestampNs_in_acting_version(m::AbstractShmLeaseKeepalive) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    clientTimestampNs_encoding_offset(::AbstractShmLeaseKeepalive) = begin
            Int(17)
        end
    clientTimestampNs_encoding_offset(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(17)
        end
    clientTimestampNs_encoding_length(::AbstractShmLeaseKeepalive) = begin
            Int(8)
        end
    clientTimestampNs_encoding_length(::Type{<:AbstractShmLeaseKeepalive}) = begin
            Int(8)
        end
    clientTimestampNs_null_value(::AbstractShmLeaseKeepalive) = begin
            UInt64(18446744073709551615)
        end
    clientTimestampNs_null_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt64(18446744073709551615)
        end
    clientTimestampNs_min_value(::AbstractShmLeaseKeepalive) = begin
            UInt64(0)
        end
    clientTimestampNs_min_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt64(0)
        end
    clientTimestampNs_max_value(::AbstractShmLeaseKeepalive) = begin
            UInt64(18446744073709551614)
        end
    clientTimestampNs_max_value(::Type{<:AbstractShmLeaseKeepalive}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function clientTimestampNs_meta_attribute(::AbstractShmLeaseKeepalive, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function clientTimestampNs_meta_attribute(::Type{<:AbstractShmLeaseKeepalive}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function clientTimestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 17)
        end
    @inline clientTimestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 17, val)
            end
    export clientTimestampNs, clientTimestampNs!
end
@inline function sbe_decoded_length(m::AbstractShmLeaseKeepalive)
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
module ShmDetachResponse
export AbstractShmDetachResponse, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmDetachResponse{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..ResponseCode
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmDetachResponse{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmDetachResponse{T}
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
        if MessageHeader.templateId(header) != UInt16(4) || MessageHeader.schemaId(header) != UInt16(901)
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
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmDetachResponse) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmDetachResponse) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmDetachResponse) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmDetachResponse) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmDetachResponse, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmDetachResponse) = begin
        UInt16(12)
    end
sbe_block_length(::Type{<:AbstractShmDetachResponse}) = begin
        UInt16(12)
    end
sbe_template_id(::AbstractShmDetachResponse) = begin
        UInt16(4)
    end
sbe_template_id(::Type{<:AbstractShmDetachResponse}) = begin
        UInt16(4)
    end
sbe_schema_id(::AbstractShmDetachResponse) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmDetachResponse}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmDetachResponse) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmDetachResponse}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmDetachResponse) = begin
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
sbe_rewind!(m::AbstractShmDetachResponse) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmDetachResponse) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmDetachResponse) = begin
        sbe_encoded_length(m)
    end
begin
    correlationId_id(::AbstractShmDetachResponse) = begin
            UInt16(1)
        end
    correlationId_id(::Type{<:AbstractShmDetachResponse}) = begin
            UInt16(1)
        end
    correlationId_since_version(::AbstractShmDetachResponse) = begin
            UInt16(0)
        end
    correlationId_since_version(::Type{<:AbstractShmDetachResponse}) = begin
            UInt16(0)
        end
    correlationId_in_acting_version(m::AbstractShmDetachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    correlationId_encoding_offset(::AbstractShmDetachResponse) = begin
            Int(0)
        end
    correlationId_encoding_offset(::Type{<:AbstractShmDetachResponse}) = begin
            Int(0)
        end
    correlationId_encoding_length(::AbstractShmDetachResponse) = begin
            Int(8)
        end
    correlationId_encoding_length(::Type{<:AbstractShmDetachResponse}) = begin
            Int(8)
        end
    correlationId_null_value(::AbstractShmDetachResponse) = begin
            Int64(-9223372036854775808)
        end
    correlationId_null_value(::Type{<:AbstractShmDetachResponse}) = begin
            Int64(-9223372036854775808)
        end
    correlationId_min_value(::AbstractShmDetachResponse) = begin
            Int64(-9223372036854775807)
        end
    correlationId_min_value(::Type{<:AbstractShmDetachResponse}) = begin
            Int64(-9223372036854775807)
        end
    correlationId_max_value(::AbstractShmDetachResponse) = begin
            Int64(9223372036854775807)
        end
    correlationId_max_value(::Type{<:AbstractShmDetachResponse}) = begin
            Int64(9223372036854775807)
        end
end
begin
    function correlationId_meta_attribute(::AbstractShmDetachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function correlationId_meta_attribute(::Type{<:AbstractShmDetachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function correlationId(m::Decoder)
            return decode_value(Int64, m.buffer, m.offset + 0)
        end
    @inline correlationId!(m::Encoder, val) = begin
                encode_value(Int64, m.buffer, m.offset + 0, val)
            end
    export correlationId, correlationId!
end
begin
    code_id(::AbstractShmDetachResponse) = begin
            UInt16(2)
        end
    code_id(::Type{<:AbstractShmDetachResponse}) = begin
            UInt16(2)
        end
    code_since_version(::AbstractShmDetachResponse) = begin
            UInt16(0)
        end
    code_since_version(::Type{<:AbstractShmDetachResponse}) = begin
            UInt16(0)
        end
    code_in_acting_version(m::AbstractShmDetachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    code_encoding_offset(::AbstractShmDetachResponse) = begin
            Int(8)
        end
    code_encoding_offset(::Type{<:AbstractShmDetachResponse}) = begin
            Int(8)
        end
    code_encoding_length(::AbstractShmDetachResponse) = begin
            Int(4)
        end
    code_encoding_length(::Type{<:AbstractShmDetachResponse}) = begin
            Int(4)
        end
    code_null_value(::AbstractShmDetachResponse) = begin
            Int32(-2147483648)
        end
    code_null_value(::Type{<:AbstractShmDetachResponse}) = begin
            Int32(-2147483648)
        end
    code_min_value(::AbstractShmDetachResponse) = begin
            Int32(-2147483647)
        end
    code_min_value(::Type{<:AbstractShmDetachResponse}) = begin
            Int32(-2147483647)
        end
    code_max_value(::AbstractShmDetachResponse) = begin
            Int32(2147483647)
        end
    code_max_value(::Type{<:AbstractShmDetachResponse}) = begin
            Int32(2147483647)
        end
end
begin
    function code_meta_attribute(::AbstractShmDetachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function code_meta_attribute(::Type{<:AbstractShmDetachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function code(m::Decoder, ::Type{Integer})
            return decode_value(Int32, m.buffer, m.offset + 8)
        end
    @inline function code(m::Decoder)
            raw = decode_value(Int32, m.buffer, m.offset + 8)
            return ResponseCode.SbeEnum(raw)
        end
    @inline function code!(m::Encoder, value::ResponseCode.SbeEnum)
            encode_value(Int32, m.buffer, m.offset + 8, Int32(value))
        end
    export code, code!
end
begin
    function errorMessage_meta_attribute(::AbstractShmDetachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function errorMessage_meta_attribute(::Type{<:AbstractShmDetachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const errorMessage_id = UInt16(3)
    const errorMessage_since_version = UInt16(0)
    const errorMessage_header_length = 4
    errorMessage_in_acting_version(m::AbstractShmDetachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function errorMessage_length(m::AbstractShmDetachResponse)
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
@inline function sbe_decoded_length(m::AbstractShmDetachResponse)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_errorMessage!(m)
        end
        return
    end
end
module ShmDriverShutdown
export AbstractShmDriverShutdown, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmDriverShutdown{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..ShutdownReason
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmDriverShutdown{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmDriverShutdown{T}
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
        if MessageHeader.templateId(header) != UInt16(6) || MessageHeader.schemaId(header) != UInt16(901)
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
        MessageHeader.templateId!(header, UInt16(6))
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmDriverShutdown) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmDriverShutdown) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmDriverShutdown) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmDriverShutdown) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmDriverShutdown, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmDriverShutdown) = begin
        UInt16(9)
    end
sbe_block_length(::Type{<:AbstractShmDriverShutdown}) = begin
        UInt16(9)
    end
sbe_template_id(::AbstractShmDriverShutdown) = begin
        UInt16(6)
    end
sbe_template_id(::Type{<:AbstractShmDriverShutdown}) = begin
        UInt16(6)
    end
sbe_schema_id(::AbstractShmDriverShutdown) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmDriverShutdown}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmDriverShutdown) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmDriverShutdown}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmDriverShutdown) = begin
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
sbe_rewind!(m::AbstractShmDriverShutdown) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmDriverShutdown) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmDriverShutdown) = begin
        sbe_encoded_length(m)
    end
begin
    timestampNs_id(::AbstractShmDriverShutdown) = begin
            UInt16(1)
        end
    timestampNs_id(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt16(1)
        end
    timestampNs_since_version(::AbstractShmDriverShutdown) = begin
            UInt16(0)
        end
    timestampNs_since_version(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt16(0)
        end
    timestampNs_in_acting_version(m::AbstractShmDriverShutdown) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    timestampNs_encoding_offset(::AbstractShmDriverShutdown) = begin
            Int(0)
        end
    timestampNs_encoding_offset(::Type{<:AbstractShmDriverShutdown}) = begin
            Int(0)
        end
    timestampNs_encoding_length(::AbstractShmDriverShutdown) = begin
            Int(8)
        end
    timestampNs_encoding_length(::Type{<:AbstractShmDriverShutdown}) = begin
            Int(8)
        end
    timestampNs_null_value(::AbstractShmDriverShutdown) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_null_value(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_min_value(::AbstractShmDriverShutdown) = begin
            UInt64(0)
        end
    timestampNs_min_value(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt64(0)
        end
    timestampNs_max_value(::AbstractShmDriverShutdown) = begin
            UInt64(18446744073709551614)
        end
    timestampNs_max_value(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function timestampNs_meta_attribute(::AbstractShmDriverShutdown, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function timestampNs_meta_attribute(::Type{<:AbstractShmDriverShutdown}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function timestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline timestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export timestampNs, timestampNs!
end
begin
    reason_id(::AbstractShmDriverShutdown) = begin
            UInt16(2)
        end
    reason_id(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt16(2)
        end
    reason_since_version(::AbstractShmDriverShutdown) = begin
            UInt16(0)
        end
    reason_since_version(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt16(0)
        end
    reason_in_acting_version(m::AbstractShmDriverShutdown) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    reason_encoding_offset(::AbstractShmDriverShutdown) = begin
            Int(8)
        end
    reason_encoding_offset(::Type{<:AbstractShmDriverShutdown}) = begin
            Int(8)
        end
    reason_encoding_length(::AbstractShmDriverShutdown) = begin
            Int(1)
        end
    reason_encoding_length(::Type{<:AbstractShmDriverShutdown}) = begin
            Int(1)
        end
    reason_null_value(::AbstractShmDriverShutdown) = begin
            UInt8(255)
        end
    reason_null_value(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt8(255)
        end
    reason_min_value(::AbstractShmDriverShutdown) = begin
            UInt8(0)
        end
    reason_min_value(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt8(0)
        end
    reason_max_value(::AbstractShmDriverShutdown) = begin
            UInt8(254)
        end
    reason_max_value(::Type{<:AbstractShmDriverShutdown}) = begin
            UInt8(254)
        end
end
begin
    function reason_meta_attribute(::AbstractShmDriverShutdown, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function reason_meta_attribute(::Type{<:AbstractShmDriverShutdown}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function reason(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 8)
        end
    @inline function reason(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 8)
            return ShutdownReason.SbeEnum(raw)
        end
    @inline function reason!(m::Encoder, value::ShutdownReason.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 8, UInt8(value))
        end
    export reason, reason!
end
begin
    function errorMessage_meta_attribute(::AbstractShmDriverShutdown, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function errorMessage_meta_attribute(::Type{<:AbstractShmDriverShutdown}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const errorMessage_id = UInt16(3)
    const errorMessage_since_version = UInt16(0)
    const errorMessage_header_length = 4
    errorMessage_in_acting_version(m::AbstractShmDriverShutdown) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function errorMessage_length(m::AbstractShmDriverShutdown)
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
@inline function sbe_decoded_length(m::AbstractShmDriverShutdown)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_errorMessage!(m)
        end
        return
    end
end
module ShmLeaseRevoked
export AbstractShmLeaseRevoked, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmLeaseRevoked{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..LeaseRevokeReason
using ..Role
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmLeaseRevoked{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmLeaseRevoked{T}
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
        if MessageHeader.templateId(header) != UInt16(7) || MessageHeader.schemaId(header) != UInt16(901)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(26)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(26))
        MessageHeader.templateId!(header, UInt16(7))
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmLeaseRevoked) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmLeaseRevoked) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmLeaseRevoked) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmLeaseRevoked) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmLeaseRevoked, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmLeaseRevoked) = begin
        UInt16(26)
    end
sbe_block_length(::Type{<:AbstractShmLeaseRevoked}) = begin
        UInt16(26)
    end
sbe_template_id(::AbstractShmLeaseRevoked) = begin
        UInt16(7)
    end
sbe_template_id(::Type{<:AbstractShmLeaseRevoked}) = begin
        UInt16(7)
    end
sbe_schema_id(::AbstractShmLeaseRevoked) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmLeaseRevoked}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmLeaseRevoked) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmLeaseRevoked}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmLeaseRevoked) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(26)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractShmLeaseRevoked) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmLeaseRevoked) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmLeaseRevoked) = begin
        sbe_encoded_length(m)
    end
begin
    timestampNs_id(::AbstractShmLeaseRevoked) = begin
            UInt16(1)
        end
    timestampNs_id(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(1)
        end
    timestampNs_since_version(::AbstractShmLeaseRevoked) = begin
            UInt16(0)
        end
    timestampNs_since_version(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(0)
        end
    timestampNs_in_acting_version(m::AbstractShmLeaseRevoked) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    timestampNs_encoding_offset(::AbstractShmLeaseRevoked) = begin
            Int(0)
        end
    timestampNs_encoding_offset(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(0)
        end
    timestampNs_encoding_length(::AbstractShmLeaseRevoked) = begin
            Int(8)
        end
    timestampNs_encoding_length(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(8)
        end
    timestampNs_null_value(::AbstractShmLeaseRevoked) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_null_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_min_value(::AbstractShmLeaseRevoked) = begin
            UInt64(0)
        end
    timestampNs_min_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt64(0)
        end
    timestampNs_max_value(::AbstractShmLeaseRevoked) = begin
            UInt64(18446744073709551614)
        end
    timestampNs_max_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function timestampNs_meta_attribute(::AbstractShmLeaseRevoked, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function timestampNs_meta_attribute(::Type{<:AbstractShmLeaseRevoked}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function timestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline timestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export timestampNs, timestampNs!
end
begin
    leaseId_id(::AbstractShmLeaseRevoked) = begin
            UInt16(2)
        end
    leaseId_id(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(2)
        end
    leaseId_since_version(::AbstractShmLeaseRevoked) = begin
            UInt16(0)
        end
    leaseId_since_version(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(0)
        end
    leaseId_in_acting_version(m::AbstractShmLeaseRevoked) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    leaseId_encoding_offset(::AbstractShmLeaseRevoked) = begin
            Int(8)
        end
    leaseId_encoding_offset(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(8)
        end
    leaseId_encoding_length(::AbstractShmLeaseRevoked) = begin
            Int(8)
        end
    leaseId_encoding_length(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(8)
        end
    leaseId_null_value(::AbstractShmLeaseRevoked) = begin
            UInt64(18446744073709551615)
        end
    leaseId_null_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt64(18446744073709551615)
        end
    leaseId_min_value(::AbstractShmLeaseRevoked) = begin
            UInt64(0)
        end
    leaseId_min_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt64(0)
        end
    leaseId_max_value(::AbstractShmLeaseRevoked) = begin
            UInt64(18446744073709551614)
        end
    leaseId_max_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function leaseId_meta_attribute(::AbstractShmLeaseRevoked, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function leaseId_meta_attribute(::Type{<:AbstractShmLeaseRevoked}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function leaseId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 8)
        end
    @inline leaseId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 8, val)
            end
    export leaseId, leaseId!
end
begin
    streamId_id(::AbstractShmLeaseRevoked) = begin
            UInt16(3)
        end
    streamId_id(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(3)
        end
    streamId_since_version(::AbstractShmLeaseRevoked) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractShmLeaseRevoked) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractShmLeaseRevoked) = begin
            Int(16)
        end
    streamId_encoding_offset(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(16)
        end
    streamId_encoding_length(::AbstractShmLeaseRevoked) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractShmLeaseRevoked) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractShmLeaseRevoked) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractShmLeaseRevoked) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractShmLeaseRevoked, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractShmLeaseRevoked}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
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
    clientId_id(::AbstractShmLeaseRevoked) = begin
            UInt16(4)
        end
    clientId_id(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(4)
        end
    clientId_since_version(::AbstractShmLeaseRevoked) = begin
            UInt16(0)
        end
    clientId_since_version(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(0)
        end
    clientId_in_acting_version(m::AbstractShmLeaseRevoked) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    clientId_encoding_offset(::AbstractShmLeaseRevoked) = begin
            Int(20)
        end
    clientId_encoding_offset(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(20)
        end
    clientId_encoding_length(::AbstractShmLeaseRevoked) = begin
            Int(4)
        end
    clientId_encoding_length(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(4)
        end
    clientId_null_value(::AbstractShmLeaseRevoked) = begin
            UInt32(4294967295)
        end
    clientId_null_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt32(4294967295)
        end
    clientId_min_value(::AbstractShmLeaseRevoked) = begin
            UInt32(0)
        end
    clientId_min_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt32(0)
        end
    clientId_max_value(::AbstractShmLeaseRevoked) = begin
            UInt32(4294967294)
        end
    clientId_max_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt32(4294967294)
        end
end
begin
    function clientId_meta_attribute(::AbstractShmLeaseRevoked, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function clientId_meta_attribute(::Type{<:AbstractShmLeaseRevoked}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function clientId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 20)
        end
    @inline clientId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 20, val)
            end
    export clientId, clientId!
end
begin
    role_id(::AbstractShmLeaseRevoked) = begin
            UInt16(5)
        end
    role_id(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(5)
        end
    role_since_version(::AbstractShmLeaseRevoked) = begin
            UInt16(0)
        end
    role_since_version(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(0)
        end
    role_in_acting_version(m::AbstractShmLeaseRevoked) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    role_encoding_offset(::AbstractShmLeaseRevoked) = begin
            Int(24)
        end
    role_encoding_offset(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(24)
        end
    role_encoding_length(::AbstractShmLeaseRevoked) = begin
            Int(1)
        end
    role_encoding_length(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(1)
        end
    role_null_value(::AbstractShmLeaseRevoked) = begin
            UInt8(255)
        end
    role_null_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt8(255)
        end
    role_min_value(::AbstractShmLeaseRevoked) = begin
            UInt8(0)
        end
    role_min_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt8(0)
        end
    role_max_value(::AbstractShmLeaseRevoked) = begin
            UInt8(254)
        end
    role_max_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt8(254)
        end
end
begin
    function role_meta_attribute(::AbstractShmLeaseRevoked, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function role_meta_attribute(::Type{<:AbstractShmLeaseRevoked}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function role(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 24)
        end
    @inline function role(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 24)
            return Role.SbeEnum(raw)
        end
    @inline function role!(m::Encoder, value::Role.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 24, UInt8(value))
        end
    export role, role!
end
begin
    reason_id(::AbstractShmLeaseRevoked) = begin
            UInt16(6)
        end
    reason_id(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(6)
        end
    reason_since_version(::AbstractShmLeaseRevoked) = begin
            UInt16(0)
        end
    reason_since_version(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt16(0)
        end
    reason_in_acting_version(m::AbstractShmLeaseRevoked) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    reason_encoding_offset(::AbstractShmLeaseRevoked) = begin
            Int(25)
        end
    reason_encoding_offset(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(25)
        end
    reason_encoding_length(::AbstractShmLeaseRevoked) = begin
            Int(1)
        end
    reason_encoding_length(::Type{<:AbstractShmLeaseRevoked}) = begin
            Int(1)
        end
    reason_null_value(::AbstractShmLeaseRevoked) = begin
            UInt8(255)
        end
    reason_null_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt8(255)
        end
    reason_min_value(::AbstractShmLeaseRevoked) = begin
            UInt8(0)
        end
    reason_min_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt8(0)
        end
    reason_max_value(::AbstractShmLeaseRevoked) = begin
            UInt8(254)
        end
    reason_max_value(::Type{<:AbstractShmLeaseRevoked}) = begin
            UInt8(254)
        end
end
begin
    function reason_meta_attribute(::AbstractShmLeaseRevoked, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function reason_meta_attribute(::Type{<:AbstractShmLeaseRevoked}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function reason(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 25)
        end
    @inline function reason(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 25)
            return LeaseRevokeReason.SbeEnum(raw)
        end
    @inline function reason!(m::Encoder, value::LeaseRevokeReason.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 25, UInt8(value))
        end
    export reason, reason!
end
begin
    function errorMessage_meta_attribute(::AbstractShmLeaseRevoked, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function errorMessage_meta_attribute(::Type{<:AbstractShmLeaseRevoked}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const errorMessage_id = UInt16(7)
    const errorMessage_since_version = UInt16(0)
    const errorMessage_header_length = 4
    errorMessage_in_acting_version(m::AbstractShmLeaseRevoked) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function errorMessage_length(m::AbstractShmLeaseRevoked)
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
@inline function sbe_decoded_length(m::AbstractShmLeaseRevoked)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_errorMessage!(m)
        end
        return
    end
end
module ShmAttachResponse
export AbstractShmAttachResponse, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmAttachResponse{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..ResponseCode
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmAttachResponse{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmAttachResponse{T}
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
        if MessageHeader.templateId(header) != UInt16(2) || MessageHeader.schemaId(header) != UInt16(901)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(54)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(54))
        MessageHeader.templateId!(header, UInt16(2))
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmAttachResponse) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmAttachResponse) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmAttachResponse) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmAttachResponse) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmAttachResponse, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmAttachResponse) = begin
        UInt16(54)
    end
sbe_block_length(::Type{<:AbstractShmAttachResponse}) = begin
        UInt16(54)
    end
sbe_template_id(::AbstractShmAttachResponse) = begin
        UInt16(2)
    end
sbe_template_id(::Type{<:AbstractShmAttachResponse}) = begin
        UInt16(2)
    end
sbe_schema_id(::AbstractShmAttachResponse) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmAttachResponse}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmAttachResponse) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmAttachResponse}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmAttachResponse) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(54)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractShmAttachResponse) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmAttachResponse) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmAttachResponse) = begin
        sbe_encoded_length(m)
    end
begin
    correlationId_id(::AbstractShmAttachResponse) = begin
            UInt16(1)
        end
    correlationId_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(1)
        end
    correlationId_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    correlationId_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    correlationId_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    correlationId_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(0)
        end
    correlationId_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(0)
        end
    correlationId_encoding_length(::AbstractShmAttachResponse) = begin
            Int(8)
        end
    correlationId_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(8)
        end
    correlationId_null_value(::AbstractShmAttachResponse) = begin
            Int64(-9223372036854775808)
        end
    correlationId_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            Int64(-9223372036854775808)
        end
    correlationId_min_value(::AbstractShmAttachResponse) = begin
            Int64(-9223372036854775807)
        end
    correlationId_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            Int64(-9223372036854775807)
        end
    correlationId_max_value(::AbstractShmAttachResponse) = begin
            Int64(9223372036854775807)
        end
    correlationId_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            Int64(9223372036854775807)
        end
end
begin
    function correlationId_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function correlationId_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function correlationId(m::Decoder)
            return decode_value(Int64, m.buffer, m.offset + 0)
        end
    @inline correlationId!(m::Encoder, val) = begin
                encode_value(Int64, m.buffer, m.offset + 0, val)
            end
    export correlationId, correlationId!
end
begin
    code_id(::AbstractShmAttachResponse) = begin
            UInt16(2)
        end
    code_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(2)
        end
    code_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    code_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    code_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    code_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(8)
        end
    code_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(8)
        end
    code_encoding_length(::AbstractShmAttachResponse) = begin
            Int(4)
        end
    code_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(4)
        end
    code_null_value(::AbstractShmAttachResponse) = begin
            Int32(-2147483648)
        end
    code_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            Int32(-2147483648)
        end
    code_min_value(::AbstractShmAttachResponse) = begin
            Int32(-2147483647)
        end
    code_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            Int32(-2147483647)
        end
    code_max_value(::AbstractShmAttachResponse) = begin
            Int32(2147483647)
        end
    code_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            Int32(2147483647)
        end
end
begin
    function code_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function code_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function code(m::Decoder, ::Type{Integer})
            return decode_value(Int32, m.buffer, m.offset + 8)
        end
    @inline function code(m::Decoder)
            raw = decode_value(Int32, m.buffer, m.offset + 8)
            return ResponseCode.SbeEnum(raw)
        end
    @inline function code!(m::Encoder, value::ResponseCode.SbeEnum)
            encode_value(Int32, m.buffer, m.offset + 8, Int32(value))
        end
    export code, code!
end
begin
    leaseId_id(::AbstractShmAttachResponse) = begin
            UInt16(3)
        end
    leaseId_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(3)
        end
    leaseId_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    leaseId_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    leaseId_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    leaseId_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(12)
        end
    leaseId_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(12)
        end
    leaseId_encoding_length(::AbstractShmAttachResponse) = begin
            Int(8)
        end
    leaseId_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(8)
        end
    leaseId_null_value(::AbstractShmAttachResponse) = begin
            UInt64(18446744073709551615)
        end
    leaseId_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(18446744073709551615)
        end
    leaseId_min_value(::AbstractShmAttachResponse) = begin
            UInt64(0)
        end
    leaseId_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(0)
        end
    leaseId_max_value(::AbstractShmAttachResponse) = begin
            UInt64(18446744073709551614)
        end
    leaseId_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function leaseId_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function leaseId_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function leaseId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 12)
        end
    @inline leaseId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 12, val)
            end
    export leaseId, leaseId!
end
begin
    leaseExpiryTimestampNs_id(::AbstractShmAttachResponse) = begin
            UInt16(4)
        end
    leaseExpiryTimestampNs_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(4)
        end
    leaseExpiryTimestampNs_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    leaseExpiryTimestampNs_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    leaseExpiryTimestampNs_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    leaseExpiryTimestampNs_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(20)
        end
    leaseExpiryTimestampNs_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(20)
        end
    leaseExpiryTimestampNs_encoding_length(::AbstractShmAttachResponse) = begin
            Int(8)
        end
    leaseExpiryTimestampNs_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(8)
        end
    leaseExpiryTimestampNs_null_value(::AbstractShmAttachResponse) = begin
            UInt64(18446744073709551615)
        end
    leaseExpiryTimestampNs_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(18446744073709551615)
        end
    leaseExpiryTimestampNs_min_value(::AbstractShmAttachResponse) = begin
            UInt64(0)
        end
    leaseExpiryTimestampNs_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(0)
        end
    leaseExpiryTimestampNs_max_value(::AbstractShmAttachResponse) = begin
            UInt64(18446744073709551614)
        end
    leaseExpiryTimestampNs_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function leaseExpiryTimestampNs_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function leaseExpiryTimestampNs_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function leaseExpiryTimestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 20)
        end
    @inline leaseExpiryTimestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 20, val)
            end
    export leaseExpiryTimestampNs, leaseExpiryTimestampNs!
end
begin
    streamId_id(::AbstractShmAttachResponse) = begin
            UInt16(5)
        end
    streamId_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(5)
        end
    streamId_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(28)
        end
    streamId_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(28)
        end
    streamId_encoding_length(::AbstractShmAttachResponse) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractShmAttachResponse) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function streamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 28)
        end
    @inline streamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 28, val)
            end
    export streamId, streamId!
end
begin
    epoch_id(::AbstractShmAttachResponse) = begin
            UInt16(6)
        end
    epoch_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(6)
        end
    epoch_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(32)
        end
    epoch_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(32)
        end
    epoch_encoding_length(::AbstractShmAttachResponse) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractShmAttachResponse) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractShmAttachResponse) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractShmAttachResponse) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function epoch(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 32)
        end
    @inline epoch!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 32, val)
            end
    export epoch, epoch!
end
begin
    layoutVersion_id(::AbstractShmAttachResponse) = begin
            UInt16(7)
        end
    layoutVersion_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(7)
        end
    layoutVersion_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    layoutVersion_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    layoutVersion_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    layoutVersion_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(40)
        end
    layoutVersion_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(40)
        end
    layoutVersion_encoding_length(::AbstractShmAttachResponse) = begin
            Int(4)
        end
    layoutVersion_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(4)
        end
    layoutVersion_null_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967295)
        end
    layoutVersion_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967295)
        end
    layoutVersion_min_value(::AbstractShmAttachResponse) = begin
            UInt32(0)
        end
    layoutVersion_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(0)
        end
    layoutVersion_max_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967294)
        end
    layoutVersion_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967294)
        end
end
begin
    function layoutVersion_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function layoutVersion_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function layoutVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 40)
        end
    @inline layoutVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 40, val)
            end
    export layoutVersion, layoutVersion!
end
begin
    headerNslots_id(::AbstractShmAttachResponse) = begin
            UInt16(8)
        end
    headerNslots_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(8)
        end
    headerNslots_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    headerNslots_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    headerNslots_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerNslots_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(44)
        end
    headerNslots_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(44)
        end
    headerNslots_encoding_length(::AbstractShmAttachResponse) = begin
            Int(4)
        end
    headerNslots_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(4)
        end
    headerNslots_null_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967295)
        end
    headerNslots_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967295)
        end
    headerNslots_min_value(::AbstractShmAttachResponse) = begin
            UInt32(0)
        end
    headerNslots_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(0)
        end
    headerNslots_max_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967294)
        end
    headerNslots_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967294)
        end
end
begin
    function headerNslots_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerNslots_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerNslots(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 44)
        end
    @inline headerNslots!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 44, val)
            end
    export headerNslots, headerNslots!
end
begin
    headerSlotBytes_id(::AbstractShmAttachResponse) = begin
            UInt16(9)
        end
    headerSlotBytes_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(9)
        end
    headerSlotBytes_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    headerSlotBytes_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    headerSlotBytes_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerSlotBytes_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(48)
        end
    headerSlotBytes_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(48)
        end
    headerSlotBytes_encoding_length(::AbstractShmAttachResponse) = begin
            Int(2)
        end
    headerSlotBytes_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(2)
        end
    headerSlotBytes_null_value(::AbstractShmAttachResponse) = begin
            UInt16(65535)
        end
    headerSlotBytes_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(65535)
        end
    headerSlotBytes_min_value(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    headerSlotBytes_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    headerSlotBytes_max_value(::AbstractShmAttachResponse) = begin
            UInt16(65534)
        end
    headerSlotBytes_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(65534)
        end
end
begin
    function headerSlotBytes_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerSlotBytes_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerSlotBytes(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 48)
        end
    @inline headerSlotBytes!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 48, val)
            end
    export headerSlotBytes, headerSlotBytes!
end
begin
    nodeId_id(::AbstractShmAttachResponse) = begin
            UInt16(10)
        end
    nodeId_id(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(10)
        end
    nodeId_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    nodeId_since_version(::Type{<:AbstractShmAttachResponse}) = begin
            UInt16(0)
        end
    nodeId_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    nodeId_encoding_offset(::AbstractShmAttachResponse) = begin
            Int(50)
        end
    nodeId_encoding_offset(::Type{<:AbstractShmAttachResponse}) = begin
            Int(50)
        end
    nodeId_encoding_length(::AbstractShmAttachResponse) = begin
            Int(4)
        end
    nodeId_encoding_length(::Type{<:AbstractShmAttachResponse}) = begin
            Int(4)
        end
    nodeId_null_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967295)
        end
    nodeId_null_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967295)
        end
    nodeId_min_value(::AbstractShmAttachResponse) = begin
            UInt32(0)
        end
    nodeId_min_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(0)
        end
    nodeId_max_value(::AbstractShmAttachResponse) = begin
            UInt32(4294967294)
        end
    nodeId_max_value(::Type{<:AbstractShmAttachResponse}) = begin
            UInt32(4294967294)
        end
end
begin
    function nodeId_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function nodeId_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function nodeId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 50)
        end
    @inline nodeId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 50, val)
            end
    export nodeId, nodeId!
end
module PayloadPools
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
sbe_header_size(::Type{<:AbstractPayloadPools}) = begin
        4
    end
sbe_block_length(::AbstractPayloadPools) = begin
        UInt16(10)
    end
sbe_block_length(::Type{<:AbstractPayloadPools}) = begin
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
sbe_acting_version(::Type{<:AbstractPayloadPools}) = begin
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
    @inline function payloadPools(m::AbstractShmAttachResponse)
            return PayloadPools.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function payloadPools!(m::AbstractShmAttachResponse, g::PayloadPools.Decoder)
            return PayloadPools.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function payloadPools!(m::AbstractShmAttachResponse, count)
            return PayloadPools.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    payloadPools_group_count!(m::Encoder, count) = begin
            payloadPools!(m, count)
        end
    payloadPools_id(::AbstractShmAttachResponse) = begin
            UInt16(20)
        end
    payloadPools_since_version(::AbstractShmAttachResponse) = begin
            UInt16(0)
        end
    payloadPools_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export payloadPools, payloadPools!, payloadPools!, PayloadPools
end
begin
    function headerRegionUri_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerRegionUri_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const headerRegionUri_id = UInt16(11)
    const headerRegionUri_since_version = UInt16(0)
    const headerRegionUri_header_length = 4
    headerRegionUri_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function headerRegionUri_length(m::AbstractShmAttachResponse)
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
    function errorMessage_meta_attribute(::AbstractShmAttachResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function errorMessage_meta_attribute(::Type{<:AbstractShmAttachResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const errorMessage_id = UInt16(30)
    const errorMessage_since_version = UInt16(0)
    const errorMessage_header_length = 4
    errorMessage_in_acting_version(m::AbstractShmAttachResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function errorMessage_length(m::AbstractShmAttachResponse)
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
@inline function sbe_decoded_length(m::AbstractShmAttachResponse)
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
                for group = payloadPools(m)
                    PayloadPools.sbe_skip!(group)
                end
            end
            skip_headerRegionUri!(m)
            skip_errorMessage!(m)
        end
        return
    end
end
module ShmDriverShutdownRequest
export AbstractShmDriverShutdownRequest, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmDriverShutdownRequest{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..ShutdownReason
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmDriverShutdownRequest{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmDriverShutdownRequest{T}
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
        if MessageHeader.templateId(header) != UInt16(8) || MessageHeader.schemaId(header) != UInt16(901)
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
        MessageHeader.templateId!(header, UInt16(8))
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmDriverShutdownRequest) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmDriverShutdownRequest) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmDriverShutdownRequest) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmDriverShutdownRequest) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmDriverShutdownRequest, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmDriverShutdownRequest) = begin
        UInt16(9)
    end
sbe_block_length(::Type{<:AbstractShmDriverShutdownRequest}) = begin
        UInt16(9)
    end
sbe_template_id(::AbstractShmDriverShutdownRequest) = begin
        UInt16(8)
    end
sbe_template_id(::Type{<:AbstractShmDriverShutdownRequest}) = begin
        UInt16(8)
    end
sbe_schema_id(::AbstractShmDriverShutdownRequest) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmDriverShutdownRequest}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmDriverShutdownRequest) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmDriverShutdownRequest}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmDriverShutdownRequest) = begin
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
sbe_rewind!(m::AbstractShmDriverShutdownRequest) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmDriverShutdownRequest) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmDriverShutdownRequest) = begin
        sbe_encoded_length(m)
    end
begin
    correlationId_id(::AbstractShmDriverShutdownRequest) = begin
            UInt16(1)
        end
    correlationId_id(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            UInt16(1)
        end
    correlationId_since_version(::AbstractShmDriverShutdownRequest) = begin
            UInt16(0)
        end
    correlationId_since_version(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            UInt16(0)
        end
    correlationId_in_acting_version(m::AbstractShmDriverShutdownRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    correlationId_encoding_offset(::AbstractShmDriverShutdownRequest) = begin
            Int(0)
        end
    correlationId_encoding_offset(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            Int(0)
        end
    correlationId_encoding_length(::AbstractShmDriverShutdownRequest) = begin
            Int(8)
        end
    correlationId_encoding_length(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            Int(8)
        end
    correlationId_null_value(::AbstractShmDriverShutdownRequest) = begin
            Int64(-9223372036854775808)
        end
    correlationId_null_value(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            Int64(-9223372036854775808)
        end
    correlationId_min_value(::AbstractShmDriverShutdownRequest) = begin
            Int64(-9223372036854775807)
        end
    correlationId_min_value(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            Int64(-9223372036854775807)
        end
    correlationId_max_value(::AbstractShmDriverShutdownRequest) = begin
            Int64(9223372036854775807)
        end
    correlationId_max_value(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            Int64(9223372036854775807)
        end
end
begin
    function correlationId_meta_attribute(::AbstractShmDriverShutdownRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function correlationId_meta_attribute(::Type{<:AbstractShmDriverShutdownRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function correlationId(m::Decoder)
            return decode_value(Int64, m.buffer, m.offset + 0)
        end
    @inline correlationId!(m::Encoder, val) = begin
                encode_value(Int64, m.buffer, m.offset + 0, val)
            end
    export correlationId, correlationId!
end
begin
    reason_id(::AbstractShmDriverShutdownRequest) = begin
            UInt16(2)
        end
    reason_id(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            UInt16(2)
        end
    reason_since_version(::AbstractShmDriverShutdownRequest) = begin
            UInt16(0)
        end
    reason_since_version(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            UInt16(0)
        end
    reason_in_acting_version(m::AbstractShmDriverShutdownRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    reason_encoding_offset(::AbstractShmDriverShutdownRequest) = begin
            Int(8)
        end
    reason_encoding_offset(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            Int(8)
        end
    reason_encoding_length(::AbstractShmDriverShutdownRequest) = begin
            Int(1)
        end
    reason_encoding_length(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            Int(1)
        end
    reason_null_value(::AbstractShmDriverShutdownRequest) = begin
            UInt8(255)
        end
    reason_null_value(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            UInt8(255)
        end
    reason_min_value(::AbstractShmDriverShutdownRequest) = begin
            UInt8(0)
        end
    reason_min_value(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            UInt8(0)
        end
    reason_max_value(::AbstractShmDriverShutdownRequest) = begin
            UInt8(254)
        end
    reason_max_value(::Type{<:AbstractShmDriverShutdownRequest}) = begin
            UInt8(254)
        end
end
begin
    function reason_meta_attribute(::AbstractShmDriverShutdownRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function reason_meta_attribute(::Type{<:AbstractShmDriverShutdownRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function reason(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 8)
        end
    @inline function reason(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 8)
            return ShutdownReason.SbeEnum(raw)
        end
    @inline function reason!(m::Encoder, value::ShutdownReason.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 8, UInt8(value))
        end
    export reason, reason!
end
begin
    function token_meta_attribute(::AbstractShmDriverShutdownRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function token_meta_attribute(::Type{<:AbstractShmDriverShutdownRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const token_id = UInt16(3)
    const token_since_version = UInt16(0)
    const token_header_length = 4
    token_in_acting_version(m::AbstractShmDriverShutdownRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function token_length(m::AbstractShmDriverShutdownRequest)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function token_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_token!(m::Decoder)
            len = token_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function token(m::Decoder)
            len = token_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function token_buffer!(m::Encoder, len)
            token_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function token!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            token_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function token!(m::Encoder, src::NTuple)
            len = sizeof(src)
            token_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function token!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            token_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline token!(m::Encoder, src::Symbol) = begin
                token!(m, to_string(src))
            end
    @inline token!(m::Encoder, src::Real) = begin
                token!(m, Tuple(src))
            end
    @inline token!(m::Encoder, ::Nothing) = begin
                token_buffer!(m, 0)
            end
end
begin
    @inline function token(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(token(m))))
        end
    @inline function token(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(token(m)))
        end
    @inline function token(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(token(m, StringView))
        end
    @inline function token(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, token(m)))[]
        end
    @inline function token(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, token(m))
        end
    @inline function token(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, token(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function token(m::Decoder, ::Type{T}) where T <: Nothing
            skip_token!(m)
            return nothing
        end
end
begin
    function errorMessage_meta_attribute(::AbstractShmDriverShutdownRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function errorMessage_meta_attribute(::Type{<:AbstractShmDriverShutdownRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const errorMessage_id = UInt16(4)
    const errorMessage_since_version = UInt16(0)
    const errorMessage_header_length = 4
    errorMessage_in_acting_version(m::AbstractShmDriverShutdownRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function errorMessage_length(m::AbstractShmDriverShutdownRequest)
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
@inline function sbe_decoded_length(m::AbstractShmDriverShutdownRequest)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_token!(m)
            skip_errorMessage!(m)
        end
        return
    end
end
module ShmDetachRequest
export AbstractShmDetachRequest, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmDetachRequest{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Role
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmDetachRequest{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmDetachRequest{T}
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
        if MessageHeader.templateId(header) != UInt16(3) || MessageHeader.schemaId(header) != UInt16(901)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(25)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(25))
        MessageHeader.templateId!(header, UInt16(3))
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmDetachRequest) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmDetachRequest) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmDetachRequest) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmDetachRequest) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmDetachRequest, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmDetachRequest) = begin
        UInt16(25)
    end
sbe_block_length(::Type{<:AbstractShmDetachRequest}) = begin
        UInt16(25)
    end
sbe_template_id(::AbstractShmDetachRequest) = begin
        UInt16(3)
    end
sbe_template_id(::Type{<:AbstractShmDetachRequest}) = begin
        UInt16(3)
    end
sbe_schema_id(::AbstractShmDetachRequest) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmDetachRequest}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmDetachRequest) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmDetachRequest}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmDetachRequest) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(25)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractShmDetachRequest) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmDetachRequest) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmDetachRequest) = begin
        sbe_encoded_length(m)
    end
begin
    correlationId_id(::AbstractShmDetachRequest) = begin
            UInt16(1)
        end
    correlationId_id(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(1)
        end
    correlationId_since_version(::AbstractShmDetachRequest) = begin
            UInt16(0)
        end
    correlationId_since_version(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(0)
        end
    correlationId_in_acting_version(m::AbstractShmDetachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    correlationId_encoding_offset(::AbstractShmDetachRequest) = begin
            Int(0)
        end
    correlationId_encoding_offset(::Type{<:AbstractShmDetachRequest}) = begin
            Int(0)
        end
    correlationId_encoding_length(::AbstractShmDetachRequest) = begin
            Int(8)
        end
    correlationId_encoding_length(::Type{<:AbstractShmDetachRequest}) = begin
            Int(8)
        end
    correlationId_null_value(::AbstractShmDetachRequest) = begin
            Int64(-9223372036854775808)
        end
    correlationId_null_value(::Type{<:AbstractShmDetachRequest}) = begin
            Int64(-9223372036854775808)
        end
    correlationId_min_value(::AbstractShmDetachRequest) = begin
            Int64(-9223372036854775807)
        end
    correlationId_min_value(::Type{<:AbstractShmDetachRequest}) = begin
            Int64(-9223372036854775807)
        end
    correlationId_max_value(::AbstractShmDetachRequest) = begin
            Int64(9223372036854775807)
        end
    correlationId_max_value(::Type{<:AbstractShmDetachRequest}) = begin
            Int64(9223372036854775807)
        end
end
begin
    function correlationId_meta_attribute(::AbstractShmDetachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function correlationId_meta_attribute(::Type{<:AbstractShmDetachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function correlationId(m::Decoder)
            return decode_value(Int64, m.buffer, m.offset + 0)
        end
    @inline correlationId!(m::Encoder, val) = begin
                encode_value(Int64, m.buffer, m.offset + 0, val)
            end
    export correlationId, correlationId!
end
begin
    leaseId_id(::AbstractShmDetachRequest) = begin
            UInt16(2)
        end
    leaseId_id(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(2)
        end
    leaseId_since_version(::AbstractShmDetachRequest) = begin
            UInt16(0)
        end
    leaseId_since_version(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(0)
        end
    leaseId_in_acting_version(m::AbstractShmDetachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    leaseId_encoding_offset(::AbstractShmDetachRequest) = begin
            Int(8)
        end
    leaseId_encoding_offset(::Type{<:AbstractShmDetachRequest}) = begin
            Int(8)
        end
    leaseId_encoding_length(::AbstractShmDetachRequest) = begin
            Int(8)
        end
    leaseId_encoding_length(::Type{<:AbstractShmDetachRequest}) = begin
            Int(8)
        end
    leaseId_null_value(::AbstractShmDetachRequest) = begin
            UInt64(18446744073709551615)
        end
    leaseId_null_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt64(18446744073709551615)
        end
    leaseId_min_value(::AbstractShmDetachRequest) = begin
            UInt64(0)
        end
    leaseId_min_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt64(0)
        end
    leaseId_max_value(::AbstractShmDetachRequest) = begin
            UInt64(18446744073709551614)
        end
    leaseId_max_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function leaseId_meta_attribute(::AbstractShmDetachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function leaseId_meta_attribute(::Type{<:AbstractShmDetachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function leaseId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 8)
        end
    @inline leaseId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 8, val)
            end
    export leaseId, leaseId!
end
begin
    streamId_id(::AbstractShmDetachRequest) = begin
            UInt16(3)
        end
    streamId_id(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(3)
        end
    streamId_since_version(::AbstractShmDetachRequest) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractShmDetachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractShmDetachRequest) = begin
            Int(16)
        end
    streamId_encoding_offset(::Type{<:AbstractShmDetachRequest}) = begin
            Int(16)
        end
    streamId_encoding_length(::AbstractShmDetachRequest) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractShmDetachRequest}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractShmDetachRequest) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractShmDetachRequest) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractShmDetachRequest) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractShmDetachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractShmDetachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
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
    clientId_id(::AbstractShmDetachRequest) = begin
            UInt16(4)
        end
    clientId_id(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(4)
        end
    clientId_since_version(::AbstractShmDetachRequest) = begin
            UInt16(0)
        end
    clientId_since_version(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(0)
        end
    clientId_in_acting_version(m::AbstractShmDetachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    clientId_encoding_offset(::AbstractShmDetachRequest) = begin
            Int(20)
        end
    clientId_encoding_offset(::Type{<:AbstractShmDetachRequest}) = begin
            Int(20)
        end
    clientId_encoding_length(::AbstractShmDetachRequest) = begin
            Int(4)
        end
    clientId_encoding_length(::Type{<:AbstractShmDetachRequest}) = begin
            Int(4)
        end
    clientId_null_value(::AbstractShmDetachRequest) = begin
            UInt32(4294967295)
        end
    clientId_null_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt32(4294967295)
        end
    clientId_min_value(::AbstractShmDetachRequest) = begin
            UInt32(0)
        end
    clientId_min_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt32(0)
        end
    clientId_max_value(::AbstractShmDetachRequest) = begin
            UInt32(4294967294)
        end
    clientId_max_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function clientId_meta_attribute(::AbstractShmDetachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function clientId_meta_attribute(::Type{<:AbstractShmDetachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function clientId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 20)
        end
    @inline clientId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 20, val)
            end
    export clientId, clientId!
end
begin
    role_id(::AbstractShmDetachRequest) = begin
            UInt16(5)
        end
    role_id(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(5)
        end
    role_since_version(::AbstractShmDetachRequest) = begin
            UInt16(0)
        end
    role_since_version(::Type{<:AbstractShmDetachRequest}) = begin
            UInt16(0)
        end
    role_in_acting_version(m::AbstractShmDetachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    role_encoding_offset(::AbstractShmDetachRequest) = begin
            Int(24)
        end
    role_encoding_offset(::Type{<:AbstractShmDetachRequest}) = begin
            Int(24)
        end
    role_encoding_length(::AbstractShmDetachRequest) = begin
            Int(1)
        end
    role_encoding_length(::Type{<:AbstractShmDetachRequest}) = begin
            Int(1)
        end
    role_null_value(::AbstractShmDetachRequest) = begin
            UInt8(255)
        end
    role_null_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt8(255)
        end
    role_min_value(::AbstractShmDetachRequest) = begin
            UInt8(0)
        end
    role_min_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt8(0)
        end
    role_max_value(::AbstractShmDetachRequest) = begin
            UInt8(254)
        end
    role_max_value(::Type{<:AbstractShmDetachRequest}) = begin
            UInt8(254)
        end
end
begin
    function role_meta_attribute(::AbstractShmDetachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function role_meta_attribute(::Type{<:AbstractShmDetachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function role(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 24)
        end
    @inline function role(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 24)
            return Role.SbeEnum(raw)
        end
    @inline function role!(m::Encoder, value::Role.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 24, UInt8(value))
        end
    export role, role!
end
@inline function sbe_decoded_length(m::AbstractShmDetachRequest)
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
module ShmAttachRequest
export AbstractShmAttachRequest, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmAttachRequest{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Role
using ..PublishMode
using ..HugepagesPolicy
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmAttachRequest{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmAttachRequest{T}
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
        if MessageHeader.templateId(header) != UInt16(1) || MessageHeader.schemaId(header) != UInt16(901)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(27)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(27))
        MessageHeader.templateId!(header, UInt16(1))
        MessageHeader.schemaId!(header, UInt16(901))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmAttachRequest) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmAttachRequest) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmAttachRequest) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmAttachRequest) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmAttachRequest, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmAttachRequest) = begin
        UInt16(27)
    end
sbe_block_length(::Type{<:AbstractShmAttachRequest}) = begin
        UInt16(27)
    end
sbe_template_id(::AbstractShmAttachRequest) = begin
        UInt16(1)
    end
sbe_template_id(::Type{<:AbstractShmAttachRequest}) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractShmAttachRequest) = begin
        UInt16(901)
    end
sbe_schema_id(::Type{<:AbstractShmAttachRequest}) = begin
        UInt16(901)
    end
sbe_schema_version(::AbstractShmAttachRequest) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmAttachRequest}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmAttachRequest) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(27)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractShmAttachRequest) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmAttachRequest) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmAttachRequest) = begin
        sbe_encoded_length(m)
    end
begin
    correlationId_id(::AbstractShmAttachRequest) = begin
            UInt16(1)
        end
    correlationId_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(1)
        end
    correlationId_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    correlationId_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    correlationId_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    correlationId_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(0)
        end
    correlationId_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(0)
        end
    correlationId_encoding_length(::AbstractShmAttachRequest) = begin
            Int(8)
        end
    correlationId_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(8)
        end
    correlationId_null_value(::AbstractShmAttachRequest) = begin
            Int64(-9223372036854775808)
        end
    correlationId_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            Int64(-9223372036854775808)
        end
    correlationId_min_value(::AbstractShmAttachRequest) = begin
            Int64(-9223372036854775807)
        end
    correlationId_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            Int64(-9223372036854775807)
        end
    correlationId_max_value(::AbstractShmAttachRequest) = begin
            Int64(9223372036854775807)
        end
    correlationId_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            Int64(9223372036854775807)
        end
end
begin
    function correlationId_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function correlationId_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function correlationId(m::Decoder)
            return decode_value(Int64, m.buffer, m.offset + 0)
        end
    @inline correlationId!(m::Encoder, val) = begin
                encode_value(Int64, m.buffer, m.offset + 0, val)
            end
    export correlationId, correlationId!
end
begin
    streamId_id(::AbstractShmAttachRequest) = begin
            UInt16(2)
        end
    streamId_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(2)
        end
    streamId_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(8)
        end
    streamId_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(8)
        end
    streamId_encoding_length(::AbstractShmAttachRequest) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractShmAttachRequest) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function streamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 8)
        end
    @inline streamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 8, val)
            end
    export streamId, streamId!
end
begin
    clientId_id(::AbstractShmAttachRequest) = begin
            UInt16(3)
        end
    clientId_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(3)
        end
    clientId_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    clientId_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    clientId_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    clientId_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(12)
        end
    clientId_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(12)
        end
    clientId_encoding_length(::AbstractShmAttachRequest) = begin
            Int(4)
        end
    clientId_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(4)
        end
    clientId_null_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967295)
        end
    clientId_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967295)
        end
    clientId_min_value(::AbstractShmAttachRequest) = begin
            UInt32(0)
        end
    clientId_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(0)
        end
    clientId_max_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967294)
        end
    clientId_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function clientId_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function clientId_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function clientId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 12)
        end
    @inline clientId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 12, val)
            end
    export clientId, clientId!
end
begin
    role_id(::AbstractShmAttachRequest) = begin
            UInt16(4)
        end
    role_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(4)
        end
    role_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    role_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    role_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    role_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(16)
        end
    role_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(16)
        end
    role_encoding_length(::AbstractShmAttachRequest) = begin
            Int(1)
        end
    role_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(1)
        end
    role_null_value(::AbstractShmAttachRequest) = begin
            UInt8(255)
        end
    role_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(255)
        end
    role_min_value(::AbstractShmAttachRequest) = begin
            UInt8(0)
        end
    role_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(0)
        end
    role_max_value(::AbstractShmAttachRequest) = begin
            UInt8(254)
        end
    role_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(254)
        end
end
begin
    function role_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function role_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function role(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 16)
        end
    @inline function role(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 16)
            return Role.SbeEnum(raw)
        end
    @inline function role!(m::Encoder, value::Role.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 16, UInt8(value))
        end
    export role, role!
end
begin
    expectedLayoutVersion_id(::AbstractShmAttachRequest) = begin
            UInt16(5)
        end
    expectedLayoutVersion_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(5)
        end
    expectedLayoutVersion_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    expectedLayoutVersion_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    expectedLayoutVersion_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    expectedLayoutVersion_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(17)
        end
    expectedLayoutVersion_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(17)
        end
    expectedLayoutVersion_encoding_length(::AbstractShmAttachRequest) = begin
            Int(4)
        end
    expectedLayoutVersion_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(4)
        end
    expectedLayoutVersion_null_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967295)
        end
    expectedLayoutVersion_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967295)
        end
    expectedLayoutVersion_min_value(::AbstractShmAttachRequest) = begin
            UInt32(0)
        end
    expectedLayoutVersion_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(0)
        end
    expectedLayoutVersion_max_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967294)
        end
    expectedLayoutVersion_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function expectedLayoutVersion_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function expectedLayoutVersion_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function expectedLayoutVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 17)
        end
    @inline expectedLayoutVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 17, val)
            end
    export expectedLayoutVersion, expectedLayoutVersion!
end
begin
    publishMode_id(::AbstractShmAttachRequest) = begin
            UInt16(6)
        end
    publishMode_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(6)
        end
    publishMode_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    publishMode_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    publishMode_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    publishMode_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(21)
        end
    publishMode_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(21)
        end
    publishMode_encoding_length(::AbstractShmAttachRequest) = begin
            Int(1)
        end
    publishMode_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(1)
        end
    publishMode_null_value(::AbstractShmAttachRequest) = begin
            UInt8(255)
        end
    publishMode_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(255)
        end
    publishMode_min_value(::AbstractShmAttachRequest) = begin
            UInt8(0)
        end
    publishMode_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(0)
        end
    publishMode_max_value(::AbstractShmAttachRequest) = begin
            UInt8(254)
        end
    publishMode_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(254)
        end
end
begin
    function publishMode_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function publishMode_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function publishMode(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 21)
        end
    @inline function publishMode(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 21)
            return PublishMode.SbeEnum(raw)
        end
    @inline function publishMode!(m::Encoder, value::PublishMode.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 21, UInt8(value))
        end
    export publishMode, publishMode!
end
begin
    requireHugepages_id(::AbstractShmAttachRequest) = begin
            UInt16(7)
        end
    requireHugepages_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(7)
        end
    requireHugepages_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    requireHugepages_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    requireHugepages_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    requireHugepages_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(22)
        end
    requireHugepages_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(22)
        end
    requireHugepages_encoding_length(::AbstractShmAttachRequest) = begin
            Int(1)
        end
    requireHugepages_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(1)
        end
    requireHugepages_null_value(::AbstractShmAttachRequest) = begin
            UInt8(255)
        end
    requireHugepages_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(255)
        end
    requireHugepages_min_value(::AbstractShmAttachRequest) = begin
            UInt8(0)
        end
    requireHugepages_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(0)
        end
    requireHugepages_max_value(::AbstractShmAttachRequest) = begin
            UInt8(254)
        end
    requireHugepages_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt8(254)
        end
end
begin
    function requireHugepages_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function requireHugepages_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function requireHugepages(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 22)
        end
    @inline function requireHugepages(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 22)
            return HugepagesPolicy.SbeEnum(raw)
        end
    @inline function requireHugepages!(m::Encoder, value::HugepagesPolicy.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 22, UInt8(value))
        end
    export requireHugepages, requireHugepages!
end
begin
    desiredNodeId_id(::AbstractShmAttachRequest) = begin
            UInt16(8)
        end
    desiredNodeId_id(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(8)
        end
    desiredNodeId_since_version(::AbstractShmAttachRequest) = begin
            UInt16(0)
        end
    desiredNodeId_since_version(::Type{<:AbstractShmAttachRequest}) = begin
            UInt16(0)
        end
    desiredNodeId_in_acting_version(m::AbstractShmAttachRequest) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    desiredNodeId_encoding_offset(::AbstractShmAttachRequest) = begin
            Int(23)
        end
    desiredNodeId_encoding_offset(::Type{<:AbstractShmAttachRequest}) = begin
            Int(23)
        end
    desiredNodeId_encoding_length(::AbstractShmAttachRequest) = begin
            Int(4)
        end
    desiredNodeId_encoding_length(::Type{<:AbstractShmAttachRequest}) = begin
            Int(4)
        end
    desiredNodeId_null_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967295)
        end
    desiredNodeId_null_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967295)
        end
    desiredNodeId_min_value(::AbstractShmAttachRequest) = begin
            UInt32(0)
        end
    desiredNodeId_min_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(0)
        end
    desiredNodeId_max_value(::AbstractShmAttachRequest) = begin
            UInt32(4294967294)
        end
    desiredNodeId_max_value(::Type{<:AbstractShmAttachRequest}) = begin
            UInt32(4294967294)
        end
end
begin
    function desiredNodeId_meta_attribute(::AbstractShmAttachRequest, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function desiredNodeId_meta_attribute(::Type{<:AbstractShmAttachRequest}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function desiredNodeId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 23)
        end
    @inline desiredNodeId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 23, val)
            end
    export desiredNodeId, desiredNodeId!
end
@inline function sbe_decoded_length(m::AbstractShmAttachRequest)
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
end

const Shm_tensorpool_driver = ShmTensorpoolDriver