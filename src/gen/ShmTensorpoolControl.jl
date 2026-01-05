module ShmTensorpoolControl
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
@enumx T = SbeEnum Dtype::Int16 begin
        UNKNOWN = 0
        UINT8 = 1
        INT8 = 2
        UINT16 = 3
        INT16 = 4
        UINT32 = 5
        INT32 = 6
        UINT64 = 7
        INT64 = 8
        FLOAT32 = 9
        FLOAT64 = 10
        BOOLEAN = 11
        BYTES = 13
        BIT = 14
        NULL_VALUE = Int16(-32768)
    end
@enumx T = SbeEnum FrameProgressState::UInt8 begin
        UNKNOWN = 0
        STARTED = 1
        PROGRESS = 2
        COMPLETE = 3
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum MajorOrder::Int16 begin
        UNKNOWN = 0
        ROW = 1
        COLUMN = 2
        NULL_VALUE = Int16(-32768)
    end
@enumx T = SbeEnum Mode::UInt8 begin
        STREAM = 1
        RATE_LIMITED = 2
        NULL_VALUE = UInt8(255)
    end
@enumx T = SbeEnum RegionType::Int16 begin
        HEADER_RING = 1
        PAYLOAD_POOL = 2
        NULL_VALUE = Int16(-32768)
    end
@enumx T = SbeEnum ResponseCode::Int32 begin
        OK = 0
        UNSUPPORTED = 1
        INVALID_PARAMS = 2
        REJECTED = 3
        INTERNAL_ERROR = 4
        NULL_VALUE = Int32(-2147483648)
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
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractGroupSizeEncoding}) = begin
        UInt16(900)
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
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractMessageHeader}) = begin
        UInt16(900)
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
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractVarAsciiEncoding}) = begin
        UInt16(900)
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
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractVarDataEncoding}) = begin
        UInt16(900)
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
module QosConsumer
export AbstractQosConsumer, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractQosConsumer{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Mode
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractQosConsumer{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractQosConsumer{T}
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
        if MessageHeader.templateId(header) != UInt16(5) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(41)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(41))
        MessageHeader.templateId!(header, UInt16(5))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractQosConsumer) = begin
        m.buffer
    end
sbe_offset(m::AbstractQosConsumer) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractQosConsumer) = begin
        m.position_ptr
    end
sbe_position(m::AbstractQosConsumer) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractQosConsumer, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractQosConsumer) = begin
        UInt16(41)
    end
sbe_block_length(::Type{<:AbstractQosConsumer}) = begin
        UInt16(41)
    end
sbe_template_id(::AbstractQosConsumer) = begin
        UInt16(5)
    end
sbe_template_id(::Type{<:AbstractQosConsumer}) = begin
        UInt16(5)
    end
sbe_schema_id(::AbstractQosConsumer) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractQosConsumer}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractQosConsumer) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractQosConsumer}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractQosConsumer) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(41)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractQosConsumer) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractQosConsumer) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractQosConsumer) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractQosConsumer) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractQosConsumer}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractQosConsumer) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractQosConsumer}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractQosConsumer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractQosConsumer) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractQosConsumer}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractQosConsumer) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractQosConsumer}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractQosConsumer) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractQosConsumer}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractQosConsumer) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractQosConsumer}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractQosConsumer) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractQosConsumer}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractQosConsumer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractQosConsumer}, meta_attribute)
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
    consumerId_id(::AbstractQosConsumer) = begin
            UInt16(2)
        end
    consumerId_id(::Type{<:AbstractQosConsumer}) = begin
            UInt16(2)
        end
    consumerId_since_version(::AbstractQosConsumer) = begin
            UInt16(0)
        end
    consumerId_since_version(::Type{<:AbstractQosConsumer}) = begin
            UInt16(0)
        end
    consumerId_in_acting_version(m::AbstractQosConsumer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    consumerId_encoding_offset(::AbstractQosConsumer) = begin
            Int(4)
        end
    consumerId_encoding_offset(::Type{<:AbstractQosConsumer}) = begin
            Int(4)
        end
    consumerId_encoding_length(::AbstractQosConsumer) = begin
            Int(4)
        end
    consumerId_encoding_length(::Type{<:AbstractQosConsumer}) = begin
            Int(4)
        end
    consumerId_null_value(::AbstractQosConsumer) = begin
            UInt32(4294967295)
        end
    consumerId_null_value(::Type{<:AbstractQosConsumer}) = begin
            UInt32(4294967295)
        end
    consumerId_min_value(::AbstractQosConsumer) = begin
            UInt32(0)
        end
    consumerId_min_value(::Type{<:AbstractQosConsumer}) = begin
            UInt32(0)
        end
    consumerId_max_value(::AbstractQosConsumer) = begin
            UInt32(4294967294)
        end
    consumerId_max_value(::Type{<:AbstractQosConsumer}) = begin
            UInt32(4294967294)
        end
end
begin
    function consumerId_meta_attribute(::AbstractQosConsumer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function consumerId_meta_attribute(::Type{<:AbstractQosConsumer}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function consumerId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 4)
        end
    @inline consumerId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 4, val)
            end
    export consumerId, consumerId!
end
begin
    epoch_id(::AbstractQosConsumer) = begin
            UInt16(3)
        end
    epoch_id(::Type{<:AbstractQosConsumer}) = begin
            UInt16(3)
        end
    epoch_since_version(::AbstractQosConsumer) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractQosConsumer}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractQosConsumer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractQosConsumer) = begin
            Int(8)
        end
    epoch_encoding_offset(::Type{<:AbstractQosConsumer}) = begin
            Int(8)
        end
    epoch_encoding_length(::AbstractQosConsumer) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractQosConsumer}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractQosConsumer) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractQosConsumer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractQosConsumer}, meta_attribute)
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
    lastSeqSeen_id(::AbstractQosConsumer) = begin
            UInt16(4)
        end
    lastSeqSeen_id(::Type{<:AbstractQosConsumer}) = begin
            UInt16(4)
        end
    lastSeqSeen_since_version(::AbstractQosConsumer) = begin
            UInt16(0)
        end
    lastSeqSeen_since_version(::Type{<:AbstractQosConsumer}) = begin
            UInt16(0)
        end
    lastSeqSeen_in_acting_version(m::AbstractQosConsumer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    lastSeqSeen_encoding_offset(::AbstractQosConsumer) = begin
            Int(16)
        end
    lastSeqSeen_encoding_offset(::Type{<:AbstractQosConsumer}) = begin
            Int(16)
        end
    lastSeqSeen_encoding_length(::AbstractQosConsumer) = begin
            Int(8)
        end
    lastSeqSeen_encoding_length(::Type{<:AbstractQosConsumer}) = begin
            Int(8)
        end
    lastSeqSeen_null_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551615)
        end
    lastSeqSeen_null_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551615)
        end
    lastSeqSeen_min_value(::AbstractQosConsumer) = begin
            UInt64(0)
        end
    lastSeqSeen_min_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(0)
        end
    lastSeqSeen_max_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551614)
        end
    lastSeqSeen_max_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function lastSeqSeen_meta_attribute(::AbstractQosConsumer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function lastSeqSeen_meta_attribute(::Type{<:AbstractQosConsumer}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function lastSeqSeen(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 16)
        end
    @inline lastSeqSeen!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 16, val)
            end
    export lastSeqSeen, lastSeqSeen!
end
begin
    dropsGap_id(::AbstractQosConsumer) = begin
            UInt16(5)
        end
    dropsGap_id(::Type{<:AbstractQosConsumer}) = begin
            UInt16(5)
        end
    dropsGap_since_version(::AbstractQosConsumer) = begin
            UInt16(0)
        end
    dropsGap_since_version(::Type{<:AbstractQosConsumer}) = begin
            UInt16(0)
        end
    dropsGap_in_acting_version(m::AbstractQosConsumer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    dropsGap_encoding_offset(::AbstractQosConsumer) = begin
            Int(24)
        end
    dropsGap_encoding_offset(::Type{<:AbstractQosConsumer}) = begin
            Int(24)
        end
    dropsGap_encoding_length(::AbstractQosConsumer) = begin
            Int(8)
        end
    dropsGap_encoding_length(::Type{<:AbstractQosConsumer}) = begin
            Int(8)
        end
    dropsGap_null_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551615)
        end
    dropsGap_null_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551615)
        end
    dropsGap_min_value(::AbstractQosConsumer) = begin
            UInt64(0)
        end
    dropsGap_min_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(0)
        end
    dropsGap_max_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551614)
        end
    dropsGap_max_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function dropsGap_meta_attribute(::AbstractQosConsumer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dropsGap_meta_attribute(::Type{<:AbstractQosConsumer}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function dropsGap(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 24)
        end
    @inline dropsGap!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 24, val)
            end
    export dropsGap, dropsGap!
end
begin
    dropsLate_id(::AbstractQosConsumer) = begin
            UInt16(6)
        end
    dropsLate_id(::Type{<:AbstractQosConsumer}) = begin
            UInt16(6)
        end
    dropsLate_since_version(::AbstractQosConsumer) = begin
            UInt16(0)
        end
    dropsLate_since_version(::Type{<:AbstractQosConsumer}) = begin
            UInt16(0)
        end
    dropsLate_in_acting_version(m::AbstractQosConsumer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    dropsLate_encoding_offset(::AbstractQosConsumer) = begin
            Int(32)
        end
    dropsLate_encoding_offset(::Type{<:AbstractQosConsumer}) = begin
            Int(32)
        end
    dropsLate_encoding_length(::AbstractQosConsumer) = begin
            Int(8)
        end
    dropsLate_encoding_length(::Type{<:AbstractQosConsumer}) = begin
            Int(8)
        end
    dropsLate_null_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551615)
        end
    dropsLate_null_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551615)
        end
    dropsLate_min_value(::AbstractQosConsumer) = begin
            UInt64(0)
        end
    dropsLate_min_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(0)
        end
    dropsLate_max_value(::AbstractQosConsumer) = begin
            UInt64(18446744073709551614)
        end
    dropsLate_max_value(::Type{<:AbstractQosConsumer}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function dropsLate_meta_attribute(::AbstractQosConsumer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dropsLate_meta_attribute(::Type{<:AbstractQosConsumer}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function dropsLate(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 32)
        end
    @inline dropsLate!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 32, val)
            end
    export dropsLate, dropsLate!
end
begin
    mode_id(::AbstractQosConsumer) = begin
            UInt16(7)
        end
    mode_id(::Type{<:AbstractQosConsumer}) = begin
            UInt16(7)
        end
    mode_since_version(::AbstractQosConsumer) = begin
            UInt16(0)
        end
    mode_since_version(::Type{<:AbstractQosConsumer}) = begin
            UInt16(0)
        end
    mode_in_acting_version(m::AbstractQosConsumer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    mode_encoding_offset(::AbstractQosConsumer) = begin
            Int(40)
        end
    mode_encoding_offset(::Type{<:AbstractQosConsumer}) = begin
            Int(40)
        end
    mode_encoding_length(::AbstractQosConsumer) = begin
            Int(1)
        end
    mode_encoding_length(::Type{<:AbstractQosConsumer}) = begin
            Int(1)
        end
    mode_null_value(::AbstractQosConsumer) = begin
            UInt8(255)
        end
    mode_null_value(::Type{<:AbstractQosConsumer}) = begin
            UInt8(255)
        end
    mode_min_value(::AbstractQosConsumer) = begin
            UInt8(0)
        end
    mode_min_value(::Type{<:AbstractQosConsumer}) = begin
            UInt8(0)
        end
    mode_max_value(::AbstractQosConsumer) = begin
            UInt8(254)
        end
    mode_max_value(::Type{<:AbstractQosConsumer}) = begin
            UInt8(254)
        end
end
begin
    function mode_meta_attribute(::AbstractQosConsumer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function mode_meta_attribute(::Type{<:AbstractQosConsumer}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function mode(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 40)
        end
    @inline function mode(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 40)
            return Mode.SbeEnum(raw)
        end
    @inline function mode!(m::Encoder, value::Mode.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 40, UInt8(value))
        end
    export mode, mode!
end
@inline function sbe_decoded_length(m::AbstractQosConsumer)
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
module DataSourceMeta
export AbstractDataSourceMeta, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractDataSourceMeta{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractDataSourceMeta{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractDataSourceMeta{T}
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
        if MessageHeader.templateId(header) != UInt16(8) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(16)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(16))
        MessageHeader.templateId!(header, UInt16(8))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractDataSourceMeta) = begin
        m.buffer
    end
sbe_offset(m::AbstractDataSourceMeta) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractDataSourceMeta) = begin
        m.position_ptr
    end
sbe_position(m::AbstractDataSourceMeta) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractDataSourceMeta, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractDataSourceMeta) = begin
        UInt16(16)
    end
sbe_block_length(::Type{<:AbstractDataSourceMeta}) = begin
        UInt16(16)
    end
sbe_template_id(::AbstractDataSourceMeta) = begin
        UInt16(8)
    end
sbe_template_id(::Type{<:AbstractDataSourceMeta}) = begin
        UInt16(8)
    end
sbe_schema_id(::AbstractDataSourceMeta) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractDataSourceMeta}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractDataSourceMeta) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractDataSourceMeta}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractDataSourceMeta) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(16)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractDataSourceMeta) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractDataSourceMeta) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractDataSourceMeta) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractDataSourceMeta) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractDataSourceMeta}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractDataSourceMeta) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractDataSourceMeta}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractDataSourceMeta) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractDataSourceMeta) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractDataSourceMeta}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractDataSourceMeta) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractDataSourceMeta}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractDataSourceMeta) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractDataSourceMeta) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractDataSourceMeta) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractDataSourceMeta, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractDataSourceMeta}, meta_attribute)
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
    metaVersion_id(::AbstractDataSourceMeta) = begin
            UInt16(2)
        end
    metaVersion_id(::Type{<:AbstractDataSourceMeta}) = begin
            UInt16(2)
        end
    metaVersion_since_version(::AbstractDataSourceMeta) = begin
            UInt16(0)
        end
    metaVersion_since_version(::Type{<:AbstractDataSourceMeta}) = begin
            UInt16(0)
        end
    metaVersion_in_acting_version(m::AbstractDataSourceMeta) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    metaVersion_encoding_offset(::AbstractDataSourceMeta) = begin
            Int(4)
        end
    metaVersion_encoding_offset(::Type{<:AbstractDataSourceMeta}) = begin
            Int(4)
        end
    metaVersion_encoding_length(::AbstractDataSourceMeta) = begin
            Int(4)
        end
    metaVersion_encoding_length(::Type{<:AbstractDataSourceMeta}) = begin
            Int(4)
        end
    metaVersion_null_value(::AbstractDataSourceMeta) = begin
            UInt32(4294967295)
        end
    metaVersion_null_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt32(4294967295)
        end
    metaVersion_min_value(::AbstractDataSourceMeta) = begin
            UInt32(0)
        end
    metaVersion_min_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt32(0)
        end
    metaVersion_max_value(::AbstractDataSourceMeta) = begin
            UInt32(4294967294)
        end
    metaVersion_max_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt32(4294967294)
        end
end
begin
    function metaVersion_meta_attribute(::AbstractDataSourceMeta, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function metaVersion_meta_attribute(::Type{<:AbstractDataSourceMeta}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function metaVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 4)
        end
    @inline metaVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 4, val)
            end
    export metaVersion, metaVersion!
end
begin
    timestampNs_id(::AbstractDataSourceMeta) = begin
            UInt16(3)
        end
    timestampNs_id(::Type{<:AbstractDataSourceMeta}) = begin
            UInt16(3)
        end
    timestampNs_since_version(::AbstractDataSourceMeta) = begin
            UInt16(0)
        end
    timestampNs_since_version(::Type{<:AbstractDataSourceMeta}) = begin
            UInt16(0)
        end
    timestampNs_in_acting_version(m::AbstractDataSourceMeta) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    timestampNs_encoding_offset(::AbstractDataSourceMeta) = begin
            Int(8)
        end
    timestampNs_encoding_offset(::Type{<:AbstractDataSourceMeta}) = begin
            Int(8)
        end
    timestampNs_encoding_length(::AbstractDataSourceMeta) = begin
            Int(8)
        end
    timestampNs_encoding_length(::Type{<:AbstractDataSourceMeta}) = begin
            Int(8)
        end
    timestampNs_null_value(::AbstractDataSourceMeta) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_null_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_min_value(::AbstractDataSourceMeta) = begin
            UInt64(0)
        end
    timestampNs_min_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt64(0)
        end
    timestampNs_max_value(::AbstractDataSourceMeta) = begin
            UInt64(18446744073709551614)
        end
    timestampNs_max_value(::Type{<:AbstractDataSourceMeta}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function timestampNs_meta_attribute(::AbstractDataSourceMeta, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function timestampNs_meta_attribute(::Type{<:AbstractDataSourceMeta}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function timestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 8)
        end
    @inline timestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 8, val)
            end
    export timestampNs, timestampNs!
end
module Attributes
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
abstract type AbstractAttributes{T} <: AbstractSbeGroup end
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractAttributes{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractAttributes{T}
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
sbe_header_size(::AbstractAttributes) = begin
        4
    end
sbe_header_size(::Type{<:AbstractAttributes}) = begin
        4
    end
sbe_block_length(::AbstractAttributes) = begin
        UInt16(0)
    end
sbe_block_length(::Type{<:AbstractAttributes}) = begin
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
sbe_acting_version(::Type{<:AbstractAttributes}) = begin
        UInt16(1)
    end
sbe_position(g::AbstractAttributes) = begin
        g.position_ptr[]
    end
@inline sbe_position!(g::AbstractAttributes, position) = begin
            g.position_ptr[] = position
        end
sbe_position_ptr(g::AbstractAttributes) = begin
        g.position_ptr
    end
@inline function next!(g::AbstractAttributes)
        if g.index >= g.count
            error("index >= count")
        end
        g.offset = sbe_position(g)
        sbe_position!(g, g.offset + sbe_acting_block_length(g))
        g.index += one(UInt16)
        return g
    end
function Base.iterate(g::AbstractAttributes, state = nothing)
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
Base.isdone(g::AbstractAttributes, state = nothing) = begin
        g.index >= g.count
    end
Base.length(g::AbstractAttributes) = begin
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
    function key_meta_attribute(::AbstractAttributes, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function key_meta_attribute(::Type{<:AbstractAttributes}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    key_character_encoding(::AbstractAttributes) = begin
            "US-ASCII"
        end
    key_character_encoding(::Type{<:AbstractAttributes}) = begin
            "US-ASCII"
        end
end
begin
    const key_id = UInt16(1)
    const key_since_version = UInt16(0)
    const key_header_length = 4
    key_in_acting_version(m::AbstractAttributes) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function key_length(m::AbstractAttributes)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function key_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_key!(m::Decoder)
            len = key_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function key(m::Decoder)
            len = key_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function key_buffer!(m::Encoder, len)
            key_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function key!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            key_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function key!(m::Encoder, src::NTuple)
            len = sizeof(src)
            key_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function key!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            key_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline key!(m::Encoder, src::Symbol) = begin
                key!(m, to_string(src))
            end
    @inline key!(m::Encoder, src::Real) = begin
                key!(m, Tuple(src))
            end
    @inline key!(m::Encoder, ::Nothing) = begin
                key_buffer!(m, 0)
            end
end
begin
    @inline function key(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(key(m))))
        end
    @inline function key(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(key(m)))
        end
    @inline function key(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(key(m, StringView))
        end
    @inline function key(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, key(m)))[]
        end
    @inline function key(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, key(m))
        end
    @inline function key(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, key(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function key(m::Decoder, ::Type{T}) where T <: Nothing
            skip_key!(m)
            return nothing
        end
end
begin
    function format_meta_attribute(::AbstractAttributes, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function format_meta_attribute(::Type{<:AbstractAttributes}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    format_character_encoding(::AbstractAttributes) = begin
            "US-ASCII"
        end
    format_character_encoding(::Type{<:AbstractAttributes}) = begin
            "US-ASCII"
        end
end
begin
    const format_id = UInt16(2)
    const format_since_version = UInt16(0)
    const format_header_length = 4
    format_in_acting_version(m::AbstractAttributes) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function format_length(m::AbstractAttributes)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function format_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_format!(m::Decoder)
            len = format_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function format(m::Decoder)
            len = format_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function format_buffer!(m::Encoder, len)
            format_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function format!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            format_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function format!(m::Encoder, src::NTuple)
            len = sizeof(src)
            format_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function format!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            format_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline format!(m::Encoder, src::Symbol) = begin
                format!(m, to_string(src))
            end
    @inline format!(m::Encoder, src::Real) = begin
                format!(m, Tuple(src))
            end
    @inline format!(m::Encoder, ::Nothing) = begin
                format_buffer!(m, 0)
            end
end
begin
    @inline function format(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(format(m))))
        end
    @inline function format(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(format(m)))
        end
    @inline function format(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(format(m, StringView))
        end
    @inline function format(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, format(m)))[]
        end
    @inline function format(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, format(m))
        end
    @inline function format(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, format(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function format(m::Decoder, ::Type{T}) where T <: Nothing
            skip_format!(m)
            return nothing
        end
end
begin
    function value_meta_attribute(::AbstractAttributes, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function value_meta_attribute(::Type{<:AbstractAttributes}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    const value_id = UInt16(3)
    const value_since_version = UInt16(0)
    const value_header_length = 4
    value_in_acting_version(m::AbstractAttributes) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function value_length(m::AbstractAttributes)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function value_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_value!(m::Decoder)
            len = value_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function value(m::Decoder)
            len = value_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function value_buffer!(m::Encoder, len)
            value_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function value!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            value_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function value!(m::Encoder, src::NTuple)
            len = sizeof(src)
            value_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function value!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            value_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline value!(m::Encoder, src::Symbol) = begin
                value!(m, to_string(src))
            end
    @inline value!(m::Encoder, src::Real) = begin
                value!(m, Tuple(src))
            end
    @inline value!(m::Encoder, ::Nothing) = begin
                value_buffer!(m, 0)
            end
end
begin
    @inline function value(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(value(m))))
        end
    @inline function value(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(value(m)))
        end
    @inline function value(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(value(m, StringView))
        end
    @inline function value(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, value(m)))[]
        end
    @inline function value(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, value(m))
        end
    @inline function value(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, value(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function value(m::Decoder, ::Type{T}) where T <: Nothing
            skip_value!(m)
            return nothing
        end
end
@inline function sbe_skip!(m::Decoder)
        begin
            skip_key!(m)
            skip_format!(m)
            skip_value!(m)
        end
        return
    end
export AbstractAttributes, Decoder, Encoder
end
begin
    @inline function attributes(m::AbstractDataSourceMeta)
            return Attributes.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function attributes!(m::AbstractDataSourceMeta, g::Attributes.Decoder)
            return Attributes.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function attributes!(m::AbstractDataSourceMeta, count)
            return Attributes.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    attributes_group_count!(m::Encoder, count) = begin
            attributes!(m, count)
        end
    attributes_id(::AbstractDataSourceMeta) = begin
            UInt16(4)
        end
    attributes_since_version(::AbstractDataSourceMeta) = begin
            UInt16(0)
        end
    attributes_in_acting_version(m::AbstractDataSourceMeta) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export attributes, attributes!, attributes!, Attributes
end
@inline function sbe_decoded_length(m::AbstractDataSourceMeta)
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
                for group = attributes(m)
                    Attributes.sbe_skip!(group)
                end
            end
        end
        return
    end
end
module ShmPoolAnnounce
export AbstractShmPoolAnnounce, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmPoolAnnounce{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmPoolAnnounce{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmPoolAnnounce{T}
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
        if MessageHeader.templateId(header) != UInt16(1) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(35)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(35))
        MessageHeader.templateId!(header, UInt16(1))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmPoolAnnounce) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmPoolAnnounce) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmPoolAnnounce) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmPoolAnnounce) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmPoolAnnounce, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmPoolAnnounce) = begin
        UInt16(35)
    end
sbe_block_length(::Type{<:AbstractShmPoolAnnounce}) = begin
        UInt16(35)
    end
sbe_template_id(::AbstractShmPoolAnnounce) = begin
        UInt16(1)
    end
sbe_template_id(::Type{<:AbstractShmPoolAnnounce}) = begin
        UInt16(1)
    end
sbe_schema_id(::AbstractShmPoolAnnounce) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractShmPoolAnnounce}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractShmPoolAnnounce) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmPoolAnnounce}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmPoolAnnounce) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(35)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractShmPoolAnnounce) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmPoolAnnounce) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmPoolAnnounce) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractShmPoolAnnounce) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractShmPoolAnnounce) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
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
    producerId_id(::AbstractShmPoolAnnounce) = begin
            UInt16(2)
        end
    producerId_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(2)
        end
    producerId_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    producerId_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    producerId_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    producerId_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(4)
        end
    producerId_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(4)
        end
    producerId_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(4)
        end
    producerId_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(4)
        end
    producerId_null_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967295)
        end
    producerId_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967295)
        end
    producerId_min_value(::AbstractShmPoolAnnounce) = begin
            UInt32(0)
        end
    producerId_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(0)
        end
    producerId_max_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967294)
        end
    producerId_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function producerId_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function producerId_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
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
    epoch_id(::AbstractShmPoolAnnounce) = begin
            UInt16(3)
        end
    epoch_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(3)
        end
    epoch_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(8)
        end
    epoch_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(8)
        end
    epoch_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractShmPoolAnnounce) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractShmPoolAnnounce) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractShmPoolAnnounce) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
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
    announceTimestampNs_id(::AbstractShmPoolAnnounce) = begin
            UInt16(4)
        end
    announceTimestampNs_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(4)
        end
    announceTimestampNs_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    announceTimestampNs_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    announceTimestampNs_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    announceTimestampNs_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(16)
        end
    announceTimestampNs_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(16)
        end
    announceTimestampNs_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(8)
        end
    announceTimestampNs_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(8)
        end
    announceTimestampNs_null_value(::AbstractShmPoolAnnounce) = begin
            UInt64(18446744073709551615)
        end
    announceTimestampNs_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    announceTimestampNs_min_value(::AbstractShmPoolAnnounce) = begin
            UInt64(0)
        end
    announceTimestampNs_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt64(0)
        end
    announceTimestampNs_max_value(::AbstractShmPoolAnnounce) = begin
            UInt64(18446744073709551614)
        end
    announceTimestampNs_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function announceTimestampNs_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function announceTimestampNs_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function announceTimestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 16)
        end
    @inline announceTimestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 16, val)
            end
    export announceTimestampNs, announceTimestampNs!
end
begin
    layoutVersion_id(::AbstractShmPoolAnnounce) = begin
            UInt16(5)
        end
    layoutVersion_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(5)
        end
    layoutVersion_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    layoutVersion_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    layoutVersion_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    layoutVersion_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(24)
        end
    layoutVersion_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(24)
        end
    layoutVersion_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(4)
        end
    layoutVersion_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(4)
        end
    layoutVersion_null_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967295)
        end
    layoutVersion_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967295)
        end
    layoutVersion_min_value(::AbstractShmPoolAnnounce) = begin
            UInt32(0)
        end
    layoutVersion_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(0)
        end
    layoutVersion_max_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967294)
        end
    layoutVersion_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function layoutVersion_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function layoutVersion_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function layoutVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 24)
        end
    @inline layoutVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 24, val)
            end
    export layoutVersion, layoutVersion!
end
begin
    headerNslots_id(::AbstractShmPoolAnnounce) = begin
            UInt16(6)
        end
    headerNslots_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(6)
        end
    headerNslots_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    headerNslots_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    headerNslots_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerNslots_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(28)
        end
    headerNslots_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(28)
        end
    headerNslots_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(4)
        end
    headerNslots_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(4)
        end
    headerNslots_null_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967295)
        end
    headerNslots_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967295)
        end
    headerNslots_min_value(::AbstractShmPoolAnnounce) = begin
            UInt32(0)
        end
    headerNslots_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(0)
        end
    headerNslots_max_value(::AbstractShmPoolAnnounce) = begin
            UInt32(4294967294)
        end
    headerNslots_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function headerNslots_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerNslots_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerNslots(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 28)
        end
    @inline headerNslots!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 28, val)
            end
    export headerNslots, headerNslots!
end
begin
    headerSlotBytes_id(::AbstractShmPoolAnnounce) = begin
            UInt16(7)
        end
    headerSlotBytes_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(7)
        end
    headerSlotBytes_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    headerSlotBytes_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    headerSlotBytes_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerSlotBytes_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(32)
        end
    headerSlotBytes_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(32)
        end
    headerSlotBytes_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(2)
        end
    headerSlotBytes_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(2)
        end
    headerSlotBytes_null_value(::AbstractShmPoolAnnounce) = begin
            UInt16(65535)
        end
    headerSlotBytes_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(65535)
        end
    headerSlotBytes_min_value(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    headerSlotBytes_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    headerSlotBytes_max_value(::AbstractShmPoolAnnounce) = begin
            UInt16(65534)
        end
    headerSlotBytes_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(65534)
        end
end
begin
    function headerSlotBytes_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerSlotBytes_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerSlotBytes(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 32)
        end
    @inline headerSlotBytes!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 32, val)
            end
    export headerSlotBytes, headerSlotBytes!
end
begin
    maxDims_id(::AbstractShmPoolAnnounce) = begin
            UInt16(8)
        end
    maxDims_id(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(8)
        end
    maxDims_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    maxDims_since_version(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt16(0)
        end
    maxDims_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    maxDims_encoding_offset(::AbstractShmPoolAnnounce) = begin
            Int(34)
        end
    maxDims_encoding_offset(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(34)
        end
    maxDims_encoding_length(::AbstractShmPoolAnnounce) = begin
            Int(1)
        end
    maxDims_encoding_length(::Type{<:AbstractShmPoolAnnounce}) = begin
            Int(1)
        end
    maxDims_null_value(::AbstractShmPoolAnnounce) = begin
            UInt8(255)
        end
    maxDims_null_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt8(255)
        end
    maxDims_min_value(::AbstractShmPoolAnnounce) = begin
            UInt8(0)
        end
    maxDims_min_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt8(0)
        end
    maxDims_max_value(::AbstractShmPoolAnnounce) = begin
            UInt8(254)
        end
    maxDims_max_value(::Type{<:AbstractShmPoolAnnounce}) = begin
            UInt8(254)
        end
end
begin
    function maxDims_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function maxDims_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function maxDims(m::Decoder)
            return decode_value(UInt8, m.buffer, m.offset + 34)
        end
    @inline maxDims!(m::Encoder, val) = begin
                encode_value(UInt8, m.buffer, m.offset + 34, val)
            end
    export maxDims, maxDims!
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
    @inline function payloadPools(m::AbstractShmPoolAnnounce)
            return PayloadPools.Decoder(m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function payloadPools!(m::AbstractShmPoolAnnounce, g::PayloadPools.Decoder)
            return PayloadPools.reset!(g, m.buffer, sbe_position_ptr(m), sbe_acting_version(m))
        end
    @inline function payloadPools!(m::AbstractShmPoolAnnounce, count)
            return PayloadPools.Encoder(m.buffer, count, sbe_position_ptr(m))
        end
    payloadPools_group_count!(m::Encoder, count) = begin
            payloadPools!(m, count)
        end
    payloadPools_id(::AbstractShmPoolAnnounce) = begin
            UInt16(9)
        end
    payloadPools_since_version(::AbstractShmPoolAnnounce) = begin
            UInt16(0)
        end
    payloadPools_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    export payloadPools, payloadPools!, payloadPools!, PayloadPools
end
begin
    function headerRegionUri_meta_attribute(::AbstractShmPoolAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerRegionUri_meta_attribute(::Type{<:AbstractShmPoolAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    headerRegionUri_character_encoding(::AbstractShmPoolAnnounce) = begin
            "US-ASCII"
        end
    headerRegionUri_character_encoding(::Type{<:AbstractShmPoolAnnounce}) = begin
            "US-ASCII"
        end
end
begin
    const headerRegionUri_id = UInt16(10)
    const headerRegionUri_since_version = UInt16(0)
    const headerRegionUri_header_length = 4
    headerRegionUri_in_acting_version(m::AbstractShmPoolAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function headerRegionUri_length(m::AbstractShmPoolAnnounce)
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
@inline function sbe_decoded_length(m::AbstractShmPoolAnnounce)
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
        end
        return
    end
end
module QosProducer
export AbstractQosProducer, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractQosProducer{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractQosProducer{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractQosProducer{T}
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
        if MessageHeader.templateId(header) != UInt16(6) || MessageHeader.schemaId(header) != UInt16(900)
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
        MessageHeader.templateId!(header, UInt16(6))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractQosProducer) = begin
        m.buffer
    end
sbe_offset(m::AbstractQosProducer) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractQosProducer) = begin
        m.position_ptr
    end
sbe_position(m::AbstractQosProducer) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractQosProducer, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractQosProducer) = begin
        UInt16(28)
    end
sbe_block_length(::Type{<:AbstractQosProducer}) = begin
        UInt16(28)
    end
sbe_template_id(::AbstractQosProducer) = begin
        UInt16(6)
    end
sbe_template_id(::Type{<:AbstractQosProducer}) = begin
        UInt16(6)
    end
sbe_schema_id(::AbstractQosProducer) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractQosProducer}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractQosProducer) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractQosProducer}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractQosProducer) = begin
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
sbe_rewind!(m::AbstractQosProducer) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractQosProducer) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractQosProducer) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractQosProducer) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractQosProducer}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractQosProducer) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractQosProducer}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractQosProducer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractQosProducer) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractQosProducer}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractQosProducer) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractQosProducer}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractQosProducer) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractQosProducer) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractQosProducer) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractQosProducer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractQosProducer}, meta_attribute)
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
    producerId_id(::AbstractQosProducer) = begin
            UInt16(2)
        end
    producerId_id(::Type{<:AbstractQosProducer}) = begin
            UInt16(2)
        end
    producerId_since_version(::AbstractQosProducer) = begin
            UInt16(0)
        end
    producerId_since_version(::Type{<:AbstractQosProducer}) = begin
            UInt16(0)
        end
    producerId_in_acting_version(m::AbstractQosProducer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    producerId_encoding_offset(::AbstractQosProducer) = begin
            Int(4)
        end
    producerId_encoding_offset(::Type{<:AbstractQosProducer}) = begin
            Int(4)
        end
    producerId_encoding_length(::AbstractQosProducer) = begin
            Int(4)
        end
    producerId_encoding_length(::Type{<:AbstractQosProducer}) = begin
            Int(4)
        end
    producerId_null_value(::AbstractQosProducer) = begin
            UInt32(4294967295)
        end
    producerId_null_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(4294967295)
        end
    producerId_min_value(::AbstractQosProducer) = begin
            UInt32(0)
        end
    producerId_min_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(0)
        end
    producerId_max_value(::AbstractQosProducer) = begin
            UInt32(4294967294)
        end
    producerId_max_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(4294967294)
        end
end
begin
    function producerId_meta_attribute(::AbstractQosProducer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function producerId_meta_attribute(::Type{<:AbstractQosProducer}, meta_attribute)
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
    epoch_id(::AbstractQosProducer) = begin
            UInt16(3)
        end
    epoch_id(::Type{<:AbstractQosProducer}) = begin
            UInt16(3)
        end
    epoch_since_version(::AbstractQosProducer) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractQosProducer}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractQosProducer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractQosProducer) = begin
            Int(8)
        end
    epoch_encoding_offset(::Type{<:AbstractQosProducer}) = begin
            Int(8)
        end
    epoch_encoding_length(::AbstractQosProducer) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractQosProducer}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractQosProducer) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractQosProducer}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractQosProducer) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractQosProducer}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractQosProducer) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractQosProducer}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractQosProducer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractQosProducer}, meta_attribute)
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
    currentSeq_id(::AbstractQosProducer) = begin
            UInt16(4)
        end
    currentSeq_id(::Type{<:AbstractQosProducer}) = begin
            UInt16(4)
        end
    currentSeq_since_version(::AbstractQosProducer) = begin
            UInt16(0)
        end
    currentSeq_since_version(::Type{<:AbstractQosProducer}) = begin
            UInt16(0)
        end
    currentSeq_in_acting_version(m::AbstractQosProducer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    currentSeq_encoding_offset(::AbstractQosProducer) = begin
            Int(16)
        end
    currentSeq_encoding_offset(::Type{<:AbstractQosProducer}) = begin
            Int(16)
        end
    currentSeq_encoding_length(::AbstractQosProducer) = begin
            Int(8)
        end
    currentSeq_encoding_length(::Type{<:AbstractQosProducer}) = begin
            Int(8)
        end
    currentSeq_null_value(::AbstractQosProducer) = begin
            UInt64(18446744073709551615)
        end
    currentSeq_null_value(::Type{<:AbstractQosProducer}) = begin
            UInt64(18446744073709551615)
        end
    currentSeq_min_value(::AbstractQosProducer) = begin
            UInt64(0)
        end
    currentSeq_min_value(::Type{<:AbstractQosProducer}) = begin
            UInt64(0)
        end
    currentSeq_max_value(::AbstractQosProducer) = begin
            UInt64(18446744073709551614)
        end
    currentSeq_max_value(::Type{<:AbstractQosProducer}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function currentSeq_meta_attribute(::AbstractQosProducer, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function currentSeq_meta_attribute(::Type{<:AbstractQosProducer}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function currentSeq(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 16)
        end
    @inline currentSeq!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 16, val)
            end
    export currentSeq, currentSeq!
end
begin
    watermark_id(::AbstractQosProducer) = begin
            UInt16(5)
        end
    watermark_id(::Type{<:AbstractQosProducer}) = begin
            UInt16(5)
        end
    watermark_since_version(::AbstractQosProducer) = begin
            UInt16(0)
        end
    watermark_since_version(::Type{<:AbstractQosProducer}) = begin
            UInt16(0)
        end
    watermark_in_acting_version(m::AbstractQosProducer) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    watermark_encoding_offset(::AbstractQosProducer) = begin
            Int(24)
        end
    watermark_encoding_offset(::Type{<:AbstractQosProducer}) = begin
            Int(24)
        end
    watermark_encoding_length(::AbstractQosProducer) = begin
            Int(4)
        end
    watermark_encoding_length(::Type{<:AbstractQosProducer}) = begin
            Int(4)
        end
    watermark_null_value(::AbstractQosProducer) = begin
            UInt32(4294967295)
        end
    watermark_null_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(4294967295)
        end
    watermark_min_value(::AbstractQosProducer) = begin
            UInt32(0)
        end
    watermark_min_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(0)
        end
    watermark_max_value(::AbstractQosProducer) = begin
            UInt32(4294967294)
        end
    watermark_max_value(::Type{<:AbstractQosProducer}) = begin
            UInt32(4294967294)
        end
end
begin
    function watermark_meta_attribute(::AbstractQosProducer, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function watermark_meta_attribute(::Type{<:AbstractQosProducer}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function watermark(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 24)
        end
    @inline watermark!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 24, val)
            end
    export watermark, watermark!
end
@inline function sbe_decoded_length(m::AbstractQosProducer)
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
module FrameProgress
export AbstractFrameProgress, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractFrameProgress{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..FrameProgressState
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractFrameProgress{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractFrameProgress{T}
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
        if MessageHeader.templateId(header) != UInt16(11) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(37)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(37))
        MessageHeader.templateId!(header, UInt16(11))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractFrameProgress) = begin
        m.buffer
    end
sbe_offset(m::AbstractFrameProgress) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractFrameProgress) = begin
        m.position_ptr
    end
sbe_position(m::AbstractFrameProgress) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractFrameProgress, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractFrameProgress) = begin
        UInt16(37)
    end
sbe_block_length(::Type{<:AbstractFrameProgress}) = begin
        UInt16(37)
    end
sbe_template_id(::AbstractFrameProgress) = begin
        UInt16(11)
    end
sbe_template_id(::Type{<:AbstractFrameProgress}) = begin
        UInt16(11)
    end
sbe_schema_id(::AbstractFrameProgress) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractFrameProgress}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractFrameProgress) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractFrameProgress}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractFrameProgress) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(37)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractFrameProgress) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractFrameProgress) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractFrameProgress) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractFrameProgress) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractFrameProgress}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractFrameProgress) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractFrameProgress}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractFrameProgress) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractFrameProgress) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractFrameProgress}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractFrameProgress) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractFrameProgress}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractFrameProgress) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractFrameProgress) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractFrameProgress) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractFrameProgress, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractFrameProgress}, meta_attribute)
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
    epoch_id(::AbstractFrameProgress) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractFrameProgress}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractFrameProgress) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractFrameProgress}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractFrameProgress) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractFrameProgress) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractFrameProgress}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractFrameProgress) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractFrameProgress}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractFrameProgress) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractFrameProgress) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractFrameProgress) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractFrameProgress, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractFrameProgress}, meta_attribute)
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
    frameId_id(::AbstractFrameProgress) = begin
            UInt16(3)
        end
    frameId_id(::Type{<:AbstractFrameProgress}) = begin
            UInt16(3)
        end
    frameId_since_version(::AbstractFrameProgress) = begin
            UInt16(0)
        end
    frameId_since_version(::Type{<:AbstractFrameProgress}) = begin
            UInt16(0)
        end
    frameId_in_acting_version(m::AbstractFrameProgress) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    frameId_encoding_offset(::AbstractFrameProgress) = begin
            Int(12)
        end
    frameId_encoding_offset(::Type{<:AbstractFrameProgress}) = begin
            Int(12)
        end
    frameId_encoding_length(::AbstractFrameProgress) = begin
            Int(8)
        end
    frameId_encoding_length(::Type{<:AbstractFrameProgress}) = begin
            Int(8)
        end
    frameId_null_value(::AbstractFrameProgress) = begin
            UInt64(18446744073709551615)
        end
    frameId_null_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(18446744073709551615)
        end
    frameId_min_value(::AbstractFrameProgress) = begin
            UInt64(0)
        end
    frameId_min_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(0)
        end
    frameId_max_value(::AbstractFrameProgress) = begin
            UInt64(18446744073709551614)
        end
    frameId_max_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function frameId_meta_attribute(::AbstractFrameProgress, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function frameId_meta_attribute(::Type{<:AbstractFrameProgress}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function frameId(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 12)
        end
    @inline frameId!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 12, val)
            end
    export frameId, frameId!
end
begin
    headerIndex_id(::AbstractFrameProgress) = begin
            UInt16(4)
        end
    headerIndex_id(::Type{<:AbstractFrameProgress}) = begin
            UInt16(4)
        end
    headerIndex_since_version(::AbstractFrameProgress) = begin
            UInt16(0)
        end
    headerIndex_since_version(::Type{<:AbstractFrameProgress}) = begin
            UInt16(0)
        end
    headerIndex_in_acting_version(m::AbstractFrameProgress) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerIndex_encoding_offset(::AbstractFrameProgress) = begin
            Int(20)
        end
    headerIndex_encoding_offset(::Type{<:AbstractFrameProgress}) = begin
            Int(20)
        end
    headerIndex_encoding_length(::AbstractFrameProgress) = begin
            Int(4)
        end
    headerIndex_encoding_length(::Type{<:AbstractFrameProgress}) = begin
            Int(4)
        end
    headerIndex_null_value(::AbstractFrameProgress) = begin
            UInt32(4294967295)
        end
    headerIndex_null_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(4294967295)
        end
    headerIndex_min_value(::AbstractFrameProgress) = begin
            UInt32(0)
        end
    headerIndex_min_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(0)
        end
    headerIndex_max_value(::AbstractFrameProgress) = begin
            UInt32(4294967294)
        end
    headerIndex_max_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(4294967294)
        end
end
begin
    function headerIndex_meta_attribute(::AbstractFrameProgress, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerIndex_meta_attribute(::Type{<:AbstractFrameProgress}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerIndex(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 20)
        end
    @inline headerIndex!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 20, val)
            end
    export headerIndex, headerIndex!
end
begin
    payloadBytesFilled_id(::AbstractFrameProgress) = begin
            UInt16(5)
        end
    payloadBytesFilled_id(::Type{<:AbstractFrameProgress}) = begin
            UInt16(5)
        end
    payloadBytesFilled_since_version(::AbstractFrameProgress) = begin
            UInt16(0)
        end
    payloadBytesFilled_since_version(::Type{<:AbstractFrameProgress}) = begin
            UInt16(0)
        end
    payloadBytesFilled_in_acting_version(m::AbstractFrameProgress) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    payloadBytesFilled_encoding_offset(::AbstractFrameProgress) = begin
            Int(24)
        end
    payloadBytesFilled_encoding_offset(::Type{<:AbstractFrameProgress}) = begin
            Int(24)
        end
    payloadBytesFilled_encoding_length(::AbstractFrameProgress) = begin
            Int(8)
        end
    payloadBytesFilled_encoding_length(::Type{<:AbstractFrameProgress}) = begin
            Int(8)
        end
    payloadBytesFilled_null_value(::AbstractFrameProgress) = begin
            UInt64(18446744073709551615)
        end
    payloadBytesFilled_null_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(18446744073709551615)
        end
    payloadBytesFilled_min_value(::AbstractFrameProgress) = begin
            UInt64(0)
        end
    payloadBytesFilled_min_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(0)
        end
    payloadBytesFilled_max_value(::AbstractFrameProgress) = begin
            UInt64(18446744073709551614)
        end
    payloadBytesFilled_max_value(::Type{<:AbstractFrameProgress}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function payloadBytesFilled_meta_attribute(::AbstractFrameProgress, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function payloadBytesFilled_meta_attribute(::Type{<:AbstractFrameProgress}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function payloadBytesFilled(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 24)
        end
    @inline payloadBytesFilled!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 24, val)
            end
    export payloadBytesFilled, payloadBytesFilled!
end
begin
    state_id(::AbstractFrameProgress) = begin
            UInt16(6)
        end
    state_id(::Type{<:AbstractFrameProgress}) = begin
            UInt16(6)
        end
    state_since_version(::AbstractFrameProgress) = begin
            UInt16(0)
        end
    state_since_version(::Type{<:AbstractFrameProgress}) = begin
            UInt16(0)
        end
    state_in_acting_version(m::AbstractFrameProgress) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    state_encoding_offset(::AbstractFrameProgress) = begin
            Int(32)
        end
    state_encoding_offset(::Type{<:AbstractFrameProgress}) = begin
            Int(32)
        end
    state_encoding_length(::AbstractFrameProgress) = begin
            Int(1)
        end
    state_encoding_length(::Type{<:AbstractFrameProgress}) = begin
            Int(1)
        end
    state_null_value(::AbstractFrameProgress) = begin
            UInt8(255)
        end
    state_null_value(::Type{<:AbstractFrameProgress}) = begin
            UInt8(255)
        end
    state_min_value(::AbstractFrameProgress) = begin
            UInt8(0)
        end
    state_min_value(::Type{<:AbstractFrameProgress}) = begin
            UInt8(0)
        end
    state_max_value(::AbstractFrameProgress) = begin
            UInt8(254)
        end
    state_max_value(::Type{<:AbstractFrameProgress}) = begin
            UInt8(254)
        end
end
begin
    function state_meta_attribute(::AbstractFrameProgress, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function state_meta_attribute(::Type{<:AbstractFrameProgress}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function state(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 32)
        end
    @inline function state(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 32)
            return FrameProgressState.SbeEnum(raw)
        end
    @inline function state!(m::Encoder, value::FrameProgressState.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 32, UInt8(value))
        end
    export state, state!
end
begin
    rowsFilled_id(::AbstractFrameProgress) = begin
            UInt16(7)
        end
    rowsFilled_id(::Type{<:AbstractFrameProgress}) = begin
            UInt16(7)
        end
    rowsFilled_since_version(::AbstractFrameProgress) = begin
            UInt16(0)
        end
    rowsFilled_since_version(::Type{<:AbstractFrameProgress}) = begin
            UInt16(0)
        end
    rowsFilled_in_acting_version(m::AbstractFrameProgress) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    rowsFilled_encoding_offset(::AbstractFrameProgress) = begin
            Int(33)
        end
    rowsFilled_encoding_offset(::Type{<:AbstractFrameProgress}) = begin
            Int(33)
        end
    rowsFilled_encoding_length(::AbstractFrameProgress) = begin
            Int(4)
        end
    rowsFilled_encoding_length(::Type{<:AbstractFrameProgress}) = begin
            Int(4)
        end
    rowsFilled_null_value(::AbstractFrameProgress) = begin
            UInt32(4294967295)
        end
    rowsFilled_null_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(4294967295)
        end
    rowsFilled_min_value(::AbstractFrameProgress) = begin
            UInt32(0)
        end
    rowsFilled_min_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(0)
        end
    rowsFilled_max_value(::AbstractFrameProgress) = begin
            UInt32(4294967294)
        end
    rowsFilled_max_value(::Type{<:AbstractFrameProgress}) = begin
            UInt32(4294967294)
        end
end
begin
    function rowsFilled_meta_attribute(::AbstractFrameProgress, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function rowsFilled_meta_attribute(::Type{<:AbstractFrameProgress}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function rowsFilled(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 33)
        end
    @inline rowsFilled!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 33, val)
            end
    export rowsFilled, rowsFilled!
end
@inline function sbe_decoded_length(m::AbstractFrameProgress)
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
module ControlResponse
export AbstractControlResponse, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractControlResponse{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractControlResponse{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractControlResponse{T}
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
        if MessageHeader.templateId(header) != UInt16(9) || MessageHeader.schemaId(header) != UInt16(900)
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
        MessageHeader.templateId!(header, UInt16(9))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractControlResponse) = begin
        m.buffer
    end
sbe_offset(m::AbstractControlResponse) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractControlResponse) = begin
        m.position_ptr
    end
sbe_position(m::AbstractControlResponse) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractControlResponse, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractControlResponse) = begin
        UInt16(12)
    end
sbe_block_length(::Type{<:AbstractControlResponse}) = begin
        UInt16(12)
    end
sbe_template_id(::AbstractControlResponse) = begin
        UInt16(9)
    end
sbe_template_id(::Type{<:AbstractControlResponse}) = begin
        UInt16(9)
    end
sbe_schema_id(::AbstractControlResponse) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractControlResponse}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractControlResponse) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractControlResponse}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractControlResponse) = begin
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
sbe_rewind!(m::AbstractControlResponse) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractControlResponse) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractControlResponse) = begin
        sbe_encoded_length(m)
    end
begin
    correlationId_id(::AbstractControlResponse) = begin
            UInt16(1)
        end
    correlationId_id(::Type{<:AbstractControlResponse}) = begin
            UInt16(1)
        end
    correlationId_since_version(::AbstractControlResponse) = begin
            UInt16(0)
        end
    correlationId_since_version(::Type{<:AbstractControlResponse}) = begin
            UInt16(0)
        end
    correlationId_in_acting_version(m::AbstractControlResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    correlationId_encoding_offset(::AbstractControlResponse) = begin
            Int(0)
        end
    correlationId_encoding_offset(::Type{<:AbstractControlResponse}) = begin
            Int(0)
        end
    correlationId_encoding_length(::AbstractControlResponse) = begin
            Int(8)
        end
    correlationId_encoding_length(::Type{<:AbstractControlResponse}) = begin
            Int(8)
        end
    correlationId_null_value(::AbstractControlResponse) = begin
            Int64(-9223372036854775808)
        end
    correlationId_null_value(::Type{<:AbstractControlResponse}) = begin
            Int64(-9223372036854775808)
        end
    correlationId_min_value(::AbstractControlResponse) = begin
            Int64(-9223372036854775807)
        end
    correlationId_min_value(::Type{<:AbstractControlResponse}) = begin
            Int64(-9223372036854775807)
        end
    correlationId_max_value(::AbstractControlResponse) = begin
            Int64(9223372036854775807)
        end
    correlationId_max_value(::Type{<:AbstractControlResponse}) = begin
            Int64(9223372036854775807)
        end
end
begin
    function correlationId_meta_attribute(::AbstractControlResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function correlationId_meta_attribute(::Type{<:AbstractControlResponse}, meta_attribute)
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
    code_id(::AbstractControlResponse) = begin
            UInt16(2)
        end
    code_id(::Type{<:AbstractControlResponse}) = begin
            UInt16(2)
        end
    code_since_version(::AbstractControlResponse) = begin
            UInt16(0)
        end
    code_since_version(::Type{<:AbstractControlResponse}) = begin
            UInt16(0)
        end
    code_in_acting_version(m::AbstractControlResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    code_encoding_offset(::AbstractControlResponse) = begin
            Int(8)
        end
    code_encoding_offset(::Type{<:AbstractControlResponse}) = begin
            Int(8)
        end
    code_encoding_length(::AbstractControlResponse) = begin
            Int(4)
        end
    code_encoding_length(::Type{<:AbstractControlResponse}) = begin
            Int(4)
        end
    code_null_value(::AbstractControlResponse) = begin
            Int32(-2147483648)
        end
    code_null_value(::Type{<:AbstractControlResponse}) = begin
            Int32(-2147483648)
        end
    code_min_value(::AbstractControlResponse) = begin
            Int32(-2147483647)
        end
    code_min_value(::Type{<:AbstractControlResponse}) = begin
            Int32(-2147483647)
        end
    code_max_value(::AbstractControlResponse) = begin
            Int32(2147483647)
        end
    code_max_value(::Type{<:AbstractControlResponse}) = begin
            Int32(2147483647)
        end
end
begin
    function code_meta_attribute(::AbstractControlResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function code_meta_attribute(::Type{<:AbstractControlResponse}, meta_attribute)
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
    function errorMessage_meta_attribute(::AbstractControlResponse, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function errorMessage_meta_attribute(::Type{<:AbstractControlResponse}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    errorMessage_character_encoding(::AbstractControlResponse) = begin
            "US-ASCII"
        end
    errorMessage_character_encoding(::Type{<:AbstractControlResponse}) = begin
            "US-ASCII"
        end
end
begin
    const errorMessage_id = UInt16(3)
    const errorMessage_since_version = UInt16(0)
    const errorMessage_header_length = 4
    errorMessage_in_acting_version(m::AbstractControlResponse) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function errorMessage_length(m::AbstractControlResponse)
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
@inline function sbe_decoded_length(m::AbstractControlResponse)
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
module ConsumerConfig
export AbstractConsumerConfig, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractConsumerConfig{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Bool_
using ..Mode
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractConsumerConfig{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractConsumerConfig{T}
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
        if MessageHeader.templateId(header) != UInt16(3) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(18)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(18))
        MessageHeader.templateId!(header, UInt16(3))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractConsumerConfig) = begin
        m.buffer
    end
sbe_offset(m::AbstractConsumerConfig) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractConsumerConfig) = begin
        m.position_ptr
    end
sbe_position(m::AbstractConsumerConfig) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractConsumerConfig, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractConsumerConfig) = begin
        UInt16(18)
    end
sbe_block_length(::Type{<:AbstractConsumerConfig}) = begin
        UInt16(18)
    end
sbe_template_id(::AbstractConsumerConfig) = begin
        UInt16(3)
    end
sbe_template_id(::Type{<:AbstractConsumerConfig}) = begin
        UInt16(3)
    end
sbe_schema_id(::AbstractConsumerConfig) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractConsumerConfig}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractConsumerConfig) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractConsumerConfig}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractConsumerConfig) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(18)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractConsumerConfig) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractConsumerConfig) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractConsumerConfig) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractConsumerConfig) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractConsumerConfig) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractConsumerConfig) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractConsumerConfig}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractConsumerConfig) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractConsumerConfig}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractConsumerConfig) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractConsumerConfig) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractConsumerConfig) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
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
    consumerId_id(::AbstractConsumerConfig) = begin
            UInt16(2)
        end
    consumerId_id(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(2)
        end
    consumerId_since_version(::AbstractConsumerConfig) = begin
            UInt16(0)
        end
    consumerId_since_version(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(0)
        end
    consumerId_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    consumerId_encoding_offset(::AbstractConsumerConfig) = begin
            Int(4)
        end
    consumerId_encoding_offset(::Type{<:AbstractConsumerConfig}) = begin
            Int(4)
        end
    consumerId_encoding_length(::AbstractConsumerConfig) = begin
            Int(4)
        end
    consumerId_encoding_length(::Type{<:AbstractConsumerConfig}) = begin
            Int(4)
        end
    consumerId_null_value(::AbstractConsumerConfig) = begin
            UInt32(4294967295)
        end
    consumerId_null_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967295)
        end
    consumerId_min_value(::AbstractConsumerConfig) = begin
            UInt32(0)
        end
    consumerId_min_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(0)
        end
    consumerId_max_value(::AbstractConsumerConfig) = begin
            UInt32(4294967294)
        end
    consumerId_max_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967294)
        end
end
begin
    function consumerId_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function consumerId_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function consumerId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 4)
        end
    @inline consumerId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 4, val)
            end
    export consumerId, consumerId!
end
begin
    useShm_id(::AbstractConsumerConfig) = begin
            UInt16(3)
        end
    useShm_id(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(3)
        end
    useShm_since_version(::AbstractConsumerConfig) = begin
            UInt16(0)
        end
    useShm_since_version(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(0)
        end
    useShm_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    useShm_encoding_offset(::AbstractConsumerConfig) = begin
            Int(8)
        end
    useShm_encoding_offset(::Type{<:AbstractConsumerConfig}) = begin
            Int(8)
        end
    useShm_encoding_length(::AbstractConsumerConfig) = begin
            Int(1)
        end
    useShm_encoding_length(::Type{<:AbstractConsumerConfig}) = begin
            Int(1)
        end
    useShm_null_value(::AbstractConsumerConfig) = begin
            UInt8(255)
        end
    useShm_null_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt8(255)
        end
    useShm_min_value(::AbstractConsumerConfig) = begin
            UInt8(0)
        end
    useShm_min_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt8(0)
        end
    useShm_max_value(::AbstractConsumerConfig) = begin
            UInt8(254)
        end
    useShm_max_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt8(254)
        end
end
begin
    function useShm_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function useShm_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function useShm(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 8)
        end
    @inline function useShm(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 8)
            return Bool_.SbeEnum(raw)
        end
    @inline function useShm!(m::Encoder, value::Bool_.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 8, UInt8(value))
        end
    export useShm, useShm!
end
begin
    mode_id(::AbstractConsumerConfig) = begin
            UInt16(4)
        end
    mode_id(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(4)
        end
    mode_since_version(::AbstractConsumerConfig) = begin
            UInt16(0)
        end
    mode_since_version(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(0)
        end
    mode_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    mode_encoding_offset(::AbstractConsumerConfig) = begin
            Int(9)
        end
    mode_encoding_offset(::Type{<:AbstractConsumerConfig}) = begin
            Int(9)
        end
    mode_encoding_length(::AbstractConsumerConfig) = begin
            Int(1)
        end
    mode_encoding_length(::Type{<:AbstractConsumerConfig}) = begin
            Int(1)
        end
    mode_null_value(::AbstractConsumerConfig) = begin
            UInt8(255)
        end
    mode_null_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt8(255)
        end
    mode_min_value(::AbstractConsumerConfig) = begin
            UInt8(0)
        end
    mode_min_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt8(0)
        end
    mode_max_value(::AbstractConsumerConfig) = begin
            UInt8(254)
        end
    mode_max_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt8(254)
        end
end
begin
    function mode_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function mode_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function mode(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 9)
        end
    @inline function mode(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 9)
            return Mode.SbeEnum(raw)
        end
    @inline function mode!(m::Encoder, value::Mode.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 9, UInt8(value))
        end
    export mode, mode!
end
begin
    descriptorStreamId_id(::AbstractConsumerConfig) = begin
            UInt16(6)
        end
    descriptorStreamId_id(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(6)
        end
    descriptorStreamId_since_version(::AbstractConsumerConfig) = begin
            UInt16(0)
        end
    descriptorStreamId_since_version(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(0)
        end
    descriptorStreamId_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    descriptorStreamId_encoding_offset(::AbstractConsumerConfig) = begin
            Int(10)
        end
    descriptorStreamId_encoding_offset(::Type{<:AbstractConsumerConfig}) = begin
            Int(10)
        end
    descriptorStreamId_encoding_length(::AbstractConsumerConfig) = begin
            Int(4)
        end
    descriptorStreamId_encoding_length(::Type{<:AbstractConsumerConfig}) = begin
            Int(4)
        end
    descriptorStreamId_null_value(::AbstractConsumerConfig) = begin
            UInt32(4294967295)
        end
    descriptorStreamId_null_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967295)
        end
    descriptorStreamId_min_value(::AbstractConsumerConfig) = begin
            UInt32(0)
        end
    descriptorStreamId_min_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(0)
        end
    descriptorStreamId_max_value(::AbstractConsumerConfig) = begin
            UInt32(4294967294)
        end
    descriptorStreamId_max_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967294)
        end
end
begin
    function descriptorStreamId_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function descriptorStreamId_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function descriptorStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 10)
        end
    @inline descriptorStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 10, val)
            end
    export descriptorStreamId, descriptorStreamId!
end
begin
    controlStreamId_id(::AbstractConsumerConfig) = begin
            UInt16(7)
        end
    controlStreamId_id(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(7)
        end
    controlStreamId_since_version(::AbstractConsumerConfig) = begin
            UInt16(0)
        end
    controlStreamId_since_version(::Type{<:AbstractConsumerConfig}) = begin
            UInt16(0)
        end
    controlStreamId_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    controlStreamId_encoding_offset(::AbstractConsumerConfig) = begin
            Int(14)
        end
    controlStreamId_encoding_offset(::Type{<:AbstractConsumerConfig}) = begin
            Int(14)
        end
    controlStreamId_encoding_length(::AbstractConsumerConfig) = begin
            Int(4)
        end
    controlStreamId_encoding_length(::Type{<:AbstractConsumerConfig}) = begin
            Int(4)
        end
    controlStreamId_null_value(::AbstractConsumerConfig) = begin
            UInt32(4294967295)
        end
    controlStreamId_null_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967295)
        end
    controlStreamId_min_value(::AbstractConsumerConfig) = begin
            UInt32(0)
        end
    controlStreamId_min_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(0)
        end
    controlStreamId_max_value(::AbstractConsumerConfig) = begin
            UInt32(4294967294)
        end
    controlStreamId_max_value(::Type{<:AbstractConsumerConfig}) = begin
            UInt32(4294967294)
        end
end
begin
    function controlStreamId_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function controlStreamId_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function controlStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 14)
        end
    @inline controlStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 14, val)
            end
    export controlStreamId, controlStreamId!
end
begin
    function payloadFallbackUri_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function payloadFallbackUri_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    payloadFallbackUri_character_encoding(::AbstractConsumerConfig) = begin
            "US-ASCII"
        end
    payloadFallbackUri_character_encoding(::Type{<:AbstractConsumerConfig}) = begin
            "US-ASCII"
        end
end
begin
    const payloadFallbackUri_id = UInt16(8)
    const payloadFallbackUri_since_version = UInt16(0)
    const payloadFallbackUri_header_length = 4
    payloadFallbackUri_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function payloadFallbackUri_length(m::AbstractConsumerConfig)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function payloadFallbackUri_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_payloadFallbackUri!(m::Decoder)
            len = payloadFallbackUri_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function payloadFallbackUri(m::Decoder)
            len = payloadFallbackUri_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function payloadFallbackUri_buffer!(m::Encoder, len)
            payloadFallbackUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function payloadFallbackUri!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            payloadFallbackUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function payloadFallbackUri!(m::Encoder, src::NTuple)
            len = sizeof(src)
            payloadFallbackUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function payloadFallbackUri!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            payloadFallbackUri_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline payloadFallbackUri!(m::Encoder, src::Symbol) = begin
                payloadFallbackUri!(m, to_string(src))
            end
    @inline payloadFallbackUri!(m::Encoder, src::Real) = begin
                payloadFallbackUri!(m, Tuple(src))
            end
    @inline payloadFallbackUri!(m::Encoder, ::Nothing) = begin
                payloadFallbackUri_buffer!(m, 0)
            end
end
begin
    @inline function payloadFallbackUri(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(payloadFallbackUri(m))))
        end
    @inline function payloadFallbackUri(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(payloadFallbackUri(m)))
        end
    @inline function payloadFallbackUri(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(payloadFallbackUri(m, StringView))
        end
    @inline function payloadFallbackUri(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, payloadFallbackUri(m)))[]
        end
    @inline function payloadFallbackUri(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, payloadFallbackUri(m))
        end
    @inline function payloadFallbackUri(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, payloadFallbackUri(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function payloadFallbackUri(m::Decoder, ::Type{T}) where T <: Nothing
            skip_payloadFallbackUri!(m)
            return nothing
        end
end
begin
    function descriptorChannel_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function descriptorChannel_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    descriptorChannel_character_encoding(::AbstractConsumerConfig) = begin
            "US-ASCII"
        end
    descriptorChannel_character_encoding(::Type{<:AbstractConsumerConfig}) = begin
            "US-ASCII"
        end
end
begin
    const descriptorChannel_id = UInt16(9)
    const descriptorChannel_since_version = UInt16(0)
    const descriptorChannel_header_length = 4
    descriptorChannel_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function descriptorChannel_length(m::AbstractConsumerConfig)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function descriptorChannel_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_descriptorChannel!(m::Decoder)
            len = descriptorChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function descriptorChannel(m::Decoder)
            len = descriptorChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function descriptorChannel_buffer!(m::Encoder, len)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function descriptorChannel!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function descriptorChannel!(m::Encoder, src::NTuple)
            len = sizeof(src)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function descriptorChannel!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline descriptorChannel!(m::Encoder, src::Symbol) = begin
                descriptorChannel!(m, to_string(src))
            end
    @inline descriptorChannel!(m::Encoder, src::Real) = begin
                descriptorChannel!(m, Tuple(src))
            end
    @inline descriptorChannel!(m::Encoder, ::Nothing) = begin
                descriptorChannel_buffer!(m, 0)
            end
end
begin
    @inline function descriptorChannel(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(descriptorChannel(m))))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(descriptorChannel(m)))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(descriptorChannel(m, StringView))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, descriptorChannel(m)))[]
        end
    @inline function descriptorChannel(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, descriptorChannel(m))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, descriptorChannel(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: Nothing
            skip_descriptorChannel!(m)
            return nothing
        end
end
begin
    function controlChannel_meta_attribute(::AbstractConsumerConfig, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function controlChannel_meta_attribute(::Type{<:AbstractConsumerConfig}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    controlChannel_character_encoding(::AbstractConsumerConfig) = begin
            "US-ASCII"
        end
    controlChannel_character_encoding(::Type{<:AbstractConsumerConfig}) = begin
            "US-ASCII"
        end
end
begin
    const controlChannel_id = UInt16(10)
    const controlChannel_since_version = UInt16(0)
    const controlChannel_header_length = 4
    controlChannel_in_acting_version(m::AbstractConsumerConfig) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function controlChannel_length(m::AbstractConsumerConfig)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function controlChannel_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_controlChannel!(m::Decoder)
            len = controlChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function controlChannel(m::Decoder)
            len = controlChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function controlChannel_buffer!(m::Encoder, len)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function controlChannel!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function controlChannel!(m::Encoder, src::NTuple)
            len = sizeof(src)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function controlChannel!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline controlChannel!(m::Encoder, src::Symbol) = begin
                controlChannel!(m, to_string(src))
            end
    @inline controlChannel!(m::Encoder, src::Real) = begin
                controlChannel!(m, Tuple(src))
            end
    @inline controlChannel!(m::Encoder, ::Nothing) = begin
                controlChannel_buffer!(m, 0)
            end
end
begin
    @inline function controlChannel(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(controlChannel(m))))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(controlChannel(m)))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(controlChannel(m, StringView))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, controlChannel(m)))[]
        end
    @inline function controlChannel(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, controlChannel(m))
        end
    @inline function controlChannel(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, controlChannel(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: Nothing
            skip_controlChannel!(m)
            return nothing
        end
end
@inline function sbe_decoded_length(m::AbstractConsumerConfig)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_payloadFallbackUri!(m)
            skip_descriptorChannel!(m)
            skip_controlChannel!(m)
        end
        return
    end
end
module TensorSlotHeader
export AbstractTensorSlotHeader, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractTensorSlotHeader{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Dtype
using ..MajorOrder
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractTensorSlotHeader{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractTensorSlotHeader{T}
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
        if MessageHeader.templateId(header) != UInt16(51) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(256)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(256))
        MessageHeader.templateId!(header, UInt16(51))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractTensorSlotHeader) = begin
        m.buffer
    end
sbe_offset(m::AbstractTensorSlotHeader) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractTensorSlotHeader) = begin
        m.position_ptr
    end
sbe_position(m::AbstractTensorSlotHeader) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractTensorSlotHeader, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractTensorSlotHeader) = begin
        UInt16(256)
    end
sbe_block_length(::Type{<:AbstractTensorSlotHeader}) = begin
        UInt16(256)
    end
sbe_template_id(::AbstractTensorSlotHeader) = begin
        UInt16(51)
    end
sbe_template_id(::Type{<:AbstractTensorSlotHeader}) = begin
        UInt16(51)
    end
sbe_schema_id(::AbstractTensorSlotHeader) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractTensorSlotHeader}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractTensorSlotHeader) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractTensorSlotHeader}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractTensorSlotHeader) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(256)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractTensorSlotHeader) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractTensorSlotHeader) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractTensorSlotHeader) = begin
        sbe_encoded_length(m)
    end
begin
    seqCommit_id(::AbstractTensorSlotHeader) = begin
            UInt16(1)
        end
    seqCommit_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(1)
        end
    seqCommit_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    seqCommit_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    seqCommit_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    seqCommit_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(0)
        end
    seqCommit_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(0)
        end
    seqCommit_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(8)
        end
    seqCommit_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(8)
        end
    seqCommit_null_value(::AbstractTensorSlotHeader) = begin
            UInt64(18446744073709551615)
        end
    seqCommit_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt64(18446744073709551615)
        end
    seqCommit_min_value(::AbstractTensorSlotHeader) = begin
            UInt64(0)
        end
    seqCommit_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt64(0)
        end
    seqCommit_max_value(::AbstractTensorSlotHeader) = begin
            UInt64(18446744073709551614)
        end
    seqCommit_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function seqCommit_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function seqCommit_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function seqCommit(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline seqCommit!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export seqCommit, seqCommit!
end
begin
    valuesLenBytes_id(::AbstractTensorSlotHeader) = begin
            UInt16(2)
        end
    valuesLenBytes_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(2)
        end
    valuesLenBytes_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    valuesLenBytes_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    valuesLenBytes_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    valuesLenBytes_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(8)
        end
    valuesLenBytes_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(8)
        end
    valuesLenBytes_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(4)
        end
    valuesLenBytes_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(4)
        end
    valuesLenBytes_null_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967295)
        end
    valuesLenBytes_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967295)
        end
    valuesLenBytes_min_value(::AbstractTensorSlotHeader) = begin
            UInt32(0)
        end
    valuesLenBytes_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(0)
        end
    valuesLenBytes_max_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967294)
        end
    valuesLenBytes_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967294)
        end
end
begin
    function valuesLenBytes_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function valuesLenBytes_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function valuesLenBytes(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 8)
        end
    @inline valuesLenBytes!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 8, val)
            end
    export valuesLenBytes, valuesLenBytes!
end
begin
    payloadSlot_id(::AbstractTensorSlotHeader) = begin
            UInt16(3)
        end
    payloadSlot_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(3)
        end
    payloadSlot_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    payloadSlot_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    payloadSlot_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    payloadSlot_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(12)
        end
    payloadSlot_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(12)
        end
    payloadSlot_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(4)
        end
    payloadSlot_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(4)
        end
    payloadSlot_null_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967295)
        end
    payloadSlot_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967295)
        end
    payloadSlot_min_value(::AbstractTensorSlotHeader) = begin
            UInt32(0)
        end
    payloadSlot_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(0)
        end
    payloadSlot_max_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967294)
        end
    payloadSlot_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967294)
        end
end
begin
    function payloadSlot_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function payloadSlot_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function payloadSlot(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 12)
        end
    @inline payloadSlot!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 12, val)
            end
    export payloadSlot, payloadSlot!
end
begin
    poolId_id(::AbstractTensorSlotHeader) = begin
            UInt16(4)
        end
    poolId_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(4)
        end
    poolId_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    poolId_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    poolId_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    poolId_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(16)
        end
    poolId_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(16)
        end
    poolId_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(2)
        end
    poolId_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(2)
        end
    poolId_null_value(::AbstractTensorSlotHeader) = begin
            UInt16(65535)
        end
    poolId_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(65535)
        end
    poolId_min_value(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    poolId_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    poolId_max_value(::AbstractTensorSlotHeader) = begin
            UInt16(65534)
        end
    poolId_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(65534)
        end
end
begin
    function poolId_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function poolId_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function poolId(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 16)
        end
    @inline poolId!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 16, val)
            end
    export poolId, poolId!
end
begin
    dtype_id(::AbstractTensorSlotHeader) = begin
            UInt16(5)
        end
    dtype_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(5)
        end
    dtype_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    dtype_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    dtype_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    dtype_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(18)
        end
    dtype_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(18)
        end
    dtype_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(2)
        end
    dtype_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(2)
        end
    dtype_null_value(::AbstractTensorSlotHeader) = begin
            Int16(-32768)
        end
    dtype_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int16(-32768)
        end
    dtype_min_value(::AbstractTensorSlotHeader) = begin
            Int16(-32767)
        end
    dtype_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int16(-32767)
        end
    dtype_max_value(::AbstractTensorSlotHeader) = begin
            Int16(32767)
        end
    dtype_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int16(32767)
        end
end
begin
    function dtype_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dtype_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function dtype(m::Decoder, ::Type{Integer})
            return decode_value(Int16, m.buffer, m.offset + 18)
        end
    @inline function dtype(m::Decoder)
            raw = decode_value(Int16, m.buffer, m.offset + 18)
            return Dtype.SbeEnum(raw)
        end
    @inline function dtype!(m::Encoder, value::Dtype.SbeEnum)
            encode_value(Int16, m.buffer, m.offset + 18, Int16(value))
        end
    export dtype, dtype!
end
begin
    majorOrder_id(::AbstractTensorSlotHeader) = begin
            UInt16(6)
        end
    majorOrder_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(6)
        end
    majorOrder_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    majorOrder_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    majorOrder_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    majorOrder_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(20)
        end
    majorOrder_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(20)
        end
    majorOrder_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(2)
        end
    majorOrder_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(2)
        end
    majorOrder_null_value(::AbstractTensorSlotHeader) = begin
            Int16(-32768)
        end
    majorOrder_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int16(-32768)
        end
    majorOrder_min_value(::AbstractTensorSlotHeader) = begin
            Int16(-32767)
        end
    majorOrder_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int16(-32767)
        end
    majorOrder_max_value(::AbstractTensorSlotHeader) = begin
            Int16(32767)
        end
    majorOrder_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int16(32767)
        end
end
begin
    function majorOrder_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function majorOrder_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function majorOrder(m::Decoder, ::Type{Integer})
            return decode_value(Int16, m.buffer, m.offset + 20)
        end
    @inline function majorOrder(m::Decoder)
            raw = decode_value(Int16, m.buffer, m.offset + 20)
            return MajorOrder.SbeEnum(raw)
        end
    @inline function majorOrder!(m::Encoder, value::MajorOrder.SbeEnum)
            encode_value(Int16, m.buffer, m.offset + 20, Int16(value))
        end
    export majorOrder, majorOrder!
end
begin
    ndims_id(::AbstractTensorSlotHeader) = begin
            UInt16(7)
        end
    ndims_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(7)
        end
    ndims_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    ndims_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    ndims_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    ndims_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(22)
        end
    ndims_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(22)
        end
    ndims_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(1)
        end
    ndims_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(1)
        end
    ndims_null_value(::AbstractTensorSlotHeader) = begin
            UInt8(255)
        end
    ndims_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(255)
        end
    ndims_min_value(::AbstractTensorSlotHeader) = begin
            UInt8(0)
        end
    ndims_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(0)
        end
    ndims_max_value(::AbstractTensorSlotHeader) = begin
            UInt8(254)
        end
    ndims_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(254)
        end
end
begin
    function ndims_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function ndims_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function ndims(m::Decoder)
            return decode_value(UInt8, m.buffer, m.offset + 22)
        end
    @inline ndims!(m::Encoder, val) = begin
                encode_value(UInt8, m.buffer, m.offset + 22, val)
            end
    export ndims, ndims!
end
begin
    maxDims_id(::AbstractTensorSlotHeader) = begin
            UInt16(8)
        end
    maxDims_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(8)
        end
    maxDims_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    maxDims_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    maxDims_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    maxDims_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(23)
        end
    maxDims_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(23)
        end
    maxDims_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(0)
        end
    maxDims_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(0)
        end
    maxDims_null_value(::AbstractTensorSlotHeader) = begin
            UInt8(255)
        end
    maxDims_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(255)
        end
    maxDims_min_value(::AbstractTensorSlotHeader) = begin
            UInt8(0)
        end
    maxDims_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(0)
        end
    maxDims_max_value(::AbstractTensorSlotHeader) = begin
            UInt8(254)
        end
    maxDims_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(254)
        end
end
begin
    function maxDims_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function maxDims_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline maxDims(::Decoder) = begin
                UInt8(8)
            end
    @inline maxDims(::Type{<:Decoder}) = begin
                UInt8(8)
            end
    export maxDims
end
begin
    padAlign_id(::AbstractTensorSlotHeader) = begin
            UInt16(9)
        end
    padAlign_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(9)
        end
    padAlign_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    padAlign_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    padAlign_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    padAlign_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(23)
        end
    padAlign_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(23)
        end
    padAlign_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(1)
        end
    padAlign_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(1)
        end
    padAlign_null_value(::AbstractTensorSlotHeader) = begin
            UInt8(255)
        end
    padAlign_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(255)
        end
    padAlign_min_value(::AbstractTensorSlotHeader) = begin
            UInt8(0)
        end
    padAlign_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(0)
        end
    padAlign_max_value(::AbstractTensorSlotHeader) = begin
            UInt8(254)
        end
    padAlign_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(254)
        end
end
begin
    function padAlign_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function padAlign_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function padAlign(m::Decoder)
            return decode_value(UInt8, m.buffer, m.offset + 23)
        end
    @inline padAlign!(m::Encoder, val) = begin
                encode_value(UInt8, m.buffer, m.offset + 23, val)
            end
    export padAlign, padAlign!
end
begin
    payloadOffset_id(::AbstractTensorSlotHeader) = begin
            UInt16(10)
        end
    payloadOffset_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(10)
        end
    payloadOffset_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    payloadOffset_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    payloadOffset_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    payloadOffset_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(24)
        end
    payloadOffset_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(24)
        end
    payloadOffset_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(4)
        end
    payloadOffset_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(4)
        end
    payloadOffset_null_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967295)
        end
    payloadOffset_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967295)
        end
    payloadOffset_min_value(::AbstractTensorSlotHeader) = begin
            UInt32(0)
        end
    payloadOffset_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(0)
        end
    payloadOffset_max_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967294)
        end
    payloadOffset_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967294)
        end
end
begin
    function payloadOffset_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function payloadOffset_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function payloadOffset(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 24)
        end
    @inline payloadOffset!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 24, val)
            end
    export payloadOffset, payloadOffset!
end
begin
    timestampNs_id(::AbstractTensorSlotHeader) = begin
            UInt16(11)
        end
    timestampNs_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(11)
        end
    timestampNs_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    timestampNs_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    timestampNs_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    timestampNs_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(28)
        end
    timestampNs_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(28)
        end
    timestampNs_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(8)
        end
    timestampNs_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(8)
        end
    timestampNs_null_value(::AbstractTensorSlotHeader) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_min_value(::AbstractTensorSlotHeader) = begin
            UInt64(0)
        end
    timestampNs_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt64(0)
        end
    timestampNs_max_value(::AbstractTensorSlotHeader) = begin
            UInt64(18446744073709551614)
        end
    timestampNs_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function timestampNs_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function timestampNs_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function timestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 28)
        end
    @inline timestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 28, val)
            end
    export timestampNs, timestampNs!
end
begin
    metaVersion_id(::AbstractTensorSlotHeader) = begin
            UInt16(12)
        end
    metaVersion_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(12)
        end
    metaVersion_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    metaVersion_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    metaVersion_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    metaVersion_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(36)
        end
    metaVersion_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(36)
        end
    metaVersion_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(4)
        end
    metaVersion_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(4)
        end
    metaVersion_null_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967295)
        end
    metaVersion_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967295)
        end
    metaVersion_min_value(::AbstractTensorSlotHeader) = begin
            UInt32(0)
        end
    metaVersion_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(0)
        end
    metaVersion_max_value(::AbstractTensorSlotHeader) = begin
            UInt32(4294967294)
        end
    metaVersion_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt32(4294967294)
        end
end
begin
    function metaVersion_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function metaVersion_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function metaVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 36)
        end
    @inline metaVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 36, val)
            end
    export metaVersion, metaVersion!
end
begin
    dims_id(::AbstractTensorSlotHeader) = begin
            UInt16(13)
        end
    dims_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(13)
        end
    dims_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    dims_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    dims_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    dims_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(40)
        end
    dims_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(40)
        end
    dims_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(32)
        end
    dims_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(32)
        end
    dims_null_value(::AbstractTensorSlotHeader) = begin
            Int32(-2147483648)
        end
    dims_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int32(-2147483648)
        end
    dims_min_value(::AbstractTensorSlotHeader) = begin
            Int32(-2147483647)
        end
    dims_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int32(-2147483647)
        end
    dims_max_value(::AbstractTensorSlotHeader) = begin
            Int32(2147483647)
        end
    dims_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int32(2147483647)
        end
end
begin
    function dims_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function dims_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function dims(m::Decoder)
            return decode_array(Int32, m.buffer, m.offset + 40, 8)
        end
    @inline function dims(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            N == 8 || throw(ArgumentError("Expected NTuple{$(array_len),<:Real}"))
            x = decode_array(Int32, m.buffer, m.offset + 40, 8)
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function dims!(m::Encoder)
            return encode_array(Int32, m.buffer, m.offset + 40, 8)
        end
    @inline function dims!(m::Encoder, val)
            copyto!(dims!(m), val)
        end
    @inline function dims!(m::Encoder, val::NTuple{N, T}) where {N, T <: Real}
            N == 8 || throw(ArgumentError("Expected NTuple{$(array_len),<:Real}"))
            dest = dims!(m)
            @inbounds for i = 1:8
                    dest[i] = val[i]
                end
        end
    export dims, dims!
end
begin
    strides_id(::AbstractTensorSlotHeader) = begin
            UInt16(14)
        end
    strides_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(14)
        end
    strides_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    strides_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    strides_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    strides_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(72)
        end
    strides_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(72)
        end
    strides_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(32)
        end
    strides_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(32)
        end
    strides_null_value(::AbstractTensorSlotHeader) = begin
            Int32(-2147483648)
        end
    strides_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int32(-2147483648)
        end
    strides_min_value(::AbstractTensorSlotHeader) = begin
            Int32(-2147483647)
        end
    strides_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int32(-2147483647)
        end
    strides_max_value(::AbstractTensorSlotHeader) = begin
            Int32(2147483647)
        end
    strides_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            Int32(2147483647)
        end
end
begin
    function strides_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function strides_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function strides(m::Decoder)
            return decode_array(Int32, m.buffer, m.offset + 72, 8)
        end
    @inline function strides(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            N == 8 || throw(ArgumentError("Expected NTuple{$(array_len),<:Real}"))
            x = decode_array(Int32, m.buffer, m.offset + 72, 8)
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function strides!(m::Encoder)
            return encode_array(Int32, m.buffer, m.offset + 72, 8)
        end
    @inline function strides!(m::Encoder, val)
            copyto!(strides!(m), val)
        end
    @inline function strides!(m::Encoder, val::NTuple{N, T}) where {N, T <: Real}
            N == 8 || throw(ArgumentError("Expected NTuple{$(array_len),<:Real}"))
            dest = strides!(m)
            @inbounds for i = 1:8
                    dest[i] = val[i]
                end
        end
    export strides, strides!
end
begin
    padding_id(::AbstractTensorSlotHeader) = begin
            UInt16(15)
        end
    padding_id(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(15)
        end
    padding_since_version(::AbstractTensorSlotHeader) = begin
            UInt16(0)
        end
    padding_since_version(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt16(0)
        end
    padding_in_acting_version(m::AbstractTensorSlotHeader) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    padding_encoding_offset(::AbstractTensorSlotHeader) = begin
            Int(104)
        end
    padding_encoding_offset(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(104)
        end
    padding_encoding_length(::AbstractTensorSlotHeader) = begin
            Int(152)
        end
    padding_encoding_length(::Type{<:AbstractTensorSlotHeader}) = begin
            Int(152)
        end
    padding_null_value(::AbstractTensorSlotHeader) = begin
            UInt8(255)
        end
    padding_null_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(255)
        end
    padding_min_value(::AbstractTensorSlotHeader) = begin
            UInt8(0)
        end
    padding_min_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(0)
        end
    padding_max_value(::AbstractTensorSlotHeader) = begin
            UInt8(254)
        end
    padding_max_value(::Type{<:AbstractTensorSlotHeader}) = begin
            UInt8(254)
        end
end
begin
    function padding_meta_attribute(::AbstractTensorSlotHeader, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function padding_meta_attribute(::Type{<:AbstractTensorSlotHeader}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function padding(m::Decoder)
            return decode_array(UInt8, m.buffer, m.offset + 104, 152)
        end
    @inline function padding(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            N == 152 || throw(ArgumentError("Expected NTuple{$(array_len),<:Real}"))
            x = decode_array(UInt8, m.buffer, m.offset + 104, 152)
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function padding!(m::Encoder)
            return encode_array(UInt8, m.buffer, m.offset + 104, 152)
        end
    @inline function padding!(m::Encoder, val)
            copyto!(padding!(m), val)
        end
    @inline function padding!(m::Encoder, val::NTuple{N, T}) where {N, T <: Real}
            N == 152 || throw(ArgumentError("Expected NTuple{$(array_len),<:Real}"))
            dest = padding!(m)
            @inbounds for i = 1:152
                    dest[i] = val[i]
                end
        end
    export padding, padding!
end
@inline function sbe_decoded_length(m::AbstractTensorSlotHeader)
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
module DataSourceAnnounce
export AbstractDataSourceAnnounce, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractDataSourceAnnounce{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractDataSourceAnnounce{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractDataSourceAnnounce{T}
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
        if MessageHeader.templateId(header) != UInt16(7) || MessageHeader.schemaId(header) != UInt16(900)
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
        MessageHeader.templateId!(header, UInt16(7))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractDataSourceAnnounce) = begin
        m.buffer
    end
sbe_offset(m::AbstractDataSourceAnnounce) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractDataSourceAnnounce) = begin
        m.position_ptr
    end
sbe_position(m::AbstractDataSourceAnnounce) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractDataSourceAnnounce, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractDataSourceAnnounce) = begin
        UInt16(20)
    end
sbe_block_length(::Type{<:AbstractDataSourceAnnounce}) = begin
        UInt16(20)
    end
sbe_template_id(::AbstractDataSourceAnnounce) = begin
        UInt16(7)
    end
sbe_template_id(::Type{<:AbstractDataSourceAnnounce}) = begin
        UInt16(7)
    end
sbe_schema_id(::AbstractDataSourceAnnounce) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractDataSourceAnnounce}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractDataSourceAnnounce) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractDataSourceAnnounce}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractDataSourceAnnounce) = begin
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
sbe_rewind!(m::AbstractDataSourceAnnounce) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractDataSourceAnnounce) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractDataSourceAnnounce) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractDataSourceAnnounce) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractDataSourceAnnounce) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractDataSourceAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractDataSourceAnnounce) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractDataSourceAnnounce) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractDataSourceAnnounce) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractDataSourceAnnounce) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractDataSourceAnnounce) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractDataSourceAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractDataSourceAnnounce}, meta_attribute)
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
    producerId_id(::AbstractDataSourceAnnounce) = begin
            UInt16(2)
        end
    producerId_id(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(2)
        end
    producerId_since_version(::AbstractDataSourceAnnounce) = begin
            UInt16(0)
        end
    producerId_since_version(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(0)
        end
    producerId_in_acting_version(m::AbstractDataSourceAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    producerId_encoding_offset(::AbstractDataSourceAnnounce) = begin
            Int(4)
        end
    producerId_encoding_offset(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(4)
        end
    producerId_encoding_length(::AbstractDataSourceAnnounce) = begin
            Int(4)
        end
    producerId_encoding_length(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(4)
        end
    producerId_null_value(::AbstractDataSourceAnnounce) = begin
            UInt32(4294967295)
        end
    producerId_null_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(4294967295)
        end
    producerId_min_value(::AbstractDataSourceAnnounce) = begin
            UInt32(0)
        end
    producerId_min_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(0)
        end
    producerId_max_value(::AbstractDataSourceAnnounce) = begin
            UInt32(4294967294)
        end
    producerId_max_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function producerId_meta_attribute(::AbstractDataSourceAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function producerId_meta_attribute(::Type{<:AbstractDataSourceAnnounce}, meta_attribute)
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
    epoch_id(::AbstractDataSourceAnnounce) = begin
            UInt16(3)
        end
    epoch_id(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(3)
        end
    epoch_since_version(::AbstractDataSourceAnnounce) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractDataSourceAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractDataSourceAnnounce) = begin
            Int(8)
        end
    epoch_encoding_offset(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(8)
        end
    epoch_encoding_length(::AbstractDataSourceAnnounce) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractDataSourceAnnounce) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractDataSourceAnnounce) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractDataSourceAnnounce) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractDataSourceAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractDataSourceAnnounce}, meta_attribute)
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
    metaVersion_id(::AbstractDataSourceAnnounce) = begin
            UInt16(4)
        end
    metaVersion_id(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(4)
        end
    metaVersion_since_version(::AbstractDataSourceAnnounce) = begin
            UInt16(0)
        end
    metaVersion_since_version(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt16(0)
        end
    metaVersion_in_acting_version(m::AbstractDataSourceAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    metaVersion_encoding_offset(::AbstractDataSourceAnnounce) = begin
            Int(16)
        end
    metaVersion_encoding_offset(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(16)
        end
    metaVersion_encoding_length(::AbstractDataSourceAnnounce) = begin
            Int(4)
        end
    metaVersion_encoding_length(::Type{<:AbstractDataSourceAnnounce}) = begin
            Int(4)
        end
    metaVersion_null_value(::AbstractDataSourceAnnounce) = begin
            UInt32(4294967295)
        end
    metaVersion_null_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(4294967295)
        end
    metaVersion_min_value(::AbstractDataSourceAnnounce) = begin
            UInt32(0)
        end
    metaVersion_min_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(0)
        end
    metaVersion_max_value(::AbstractDataSourceAnnounce) = begin
            UInt32(4294967294)
        end
    metaVersion_max_value(::Type{<:AbstractDataSourceAnnounce}) = begin
            UInt32(4294967294)
        end
end
begin
    function metaVersion_meta_attribute(::AbstractDataSourceAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function metaVersion_meta_attribute(::Type{<:AbstractDataSourceAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function metaVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 16)
        end
    @inline metaVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 16, val)
            end
    export metaVersion, metaVersion!
end
begin
    function name_meta_attribute(::AbstractDataSourceAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function name_meta_attribute(::Type{<:AbstractDataSourceAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    name_character_encoding(::AbstractDataSourceAnnounce) = begin
            "US-ASCII"
        end
    name_character_encoding(::Type{<:AbstractDataSourceAnnounce}) = begin
            "US-ASCII"
        end
end
begin
    const name_id = UInt16(5)
    const name_since_version = UInt16(0)
    const name_header_length = 4
    name_in_acting_version(m::AbstractDataSourceAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function name_length(m::AbstractDataSourceAnnounce)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function name_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_name!(m::Decoder)
            len = name_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function name(m::Decoder)
            len = name_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function name_buffer!(m::Encoder, len)
            name_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function name!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            name_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function name!(m::Encoder, src::NTuple)
            len = sizeof(src)
            name_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function name!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            name_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline name!(m::Encoder, src::Symbol) = begin
                name!(m, to_string(src))
            end
    @inline name!(m::Encoder, src::Real) = begin
                name!(m, Tuple(src))
            end
    @inline name!(m::Encoder, ::Nothing) = begin
                name_buffer!(m, 0)
            end
end
begin
    @inline function name(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(name(m))))
        end
    @inline function name(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(name(m)))
        end
    @inline function name(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(name(m, StringView))
        end
    @inline function name(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, name(m)))[]
        end
    @inline function name(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, name(m))
        end
    @inline function name(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, name(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function name(m::Decoder, ::Type{T}) where T <: Nothing
            skip_name!(m)
            return nothing
        end
end
begin
    function summary_meta_attribute(::AbstractDataSourceAnnounce, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function summary_meta_attribute(::Type{<:AbstractDataSourceAnnounce}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    summary_character_encoding(::AbstractDataSourceAnnounce) = begin
            "US-ASCII"
        end
    summary_character_encoding(::Type{<:AbstractDataSourceAnnounce}) = begin
            "US-ASCII"
        end
end
begin
    const summary_id = UInt16(6)
    const summary_since_version = UInt16(0)
    const summary_header_length = 4
    summary_in_acting_version(m::AbstractDataSourceAnnounce) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function summary_length(m::AbstractDataSourceAnnounce)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function summary_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_summary!(m::Decoder)
            len = summary_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function summary(m::Decoder)
            len = summary_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function summary_buffer!(m::Encoder, len)
            summary_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function summary!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            summary_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function summary!(m::Encoder, src::NTuple)
            len = sizeof(src)
            summary_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function summary!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            summary_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline summary!(m::Encoder, src::Symbol) = begin
                summary!(m, to_string(src))
            end
    @inline summary!(m::Encoder, src::Real) = begin
                summary!(m, Tuple(src))
            end
    @inline summary!(m::Encoder, ::Nothing) = begin
                summary_buffer!(m, 0)
            end
end
begin
    @inline function summary(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(summary(m))))
        end
    @inline function summary(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(summary(m)))
        end
    @inline function summary(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(summary(m, StringView))
        end
    @inline function summary(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, summary(m)))[]
        end
    @inline function summary(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, summary(m))
        end
    @inline function summary(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, summary(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function summary(m::Decoder, ::Type{T}) where T <: Nothing
            skip_summary!(m)
            return nothing
        end
end
@inline function sbe_decoded_length(m::AbstractDataSourceAnnounce)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_name!(m)
            skip_summary!(m)
        end
        return
    end
end
module FrameDescriptor
export AbstractFrameDescriptor, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractFrameDescriptor{T} <: AbstractSbeMessage{T} end
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractFrameDescriptor{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractFrameDescriptor{T}
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
        if MessageHeader.templateId(header) != UInt16(4) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(36)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(36))
        MessageHeader.templateId!(header, UInt16(4))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractFrameDescriptor) = begin
        m.buffer
    end
sbe_offset(m::AbstractFrameDescriptor) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractFrameDescriptor) = begin
        m.position_ptr
    end
sbe_position(m::AbstractFrameDescriptor) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractFrameDescriptor, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractFrameDescriptor) = begin
        UInt16(36)
    end
sbe_block_length(::Type{<:AbstractFrameDescriptor}) = begin
        UInt16(36)
    end
sbe_template_id(::AbstractFrameDescriptor) = begin
        UInt16(4)
    end
sbe_template_id(::Type{<:AbstractFrameDescriptor}) = begin
        UInt16(4)
    end
sbe_schema_id(::AbstractFrameDescriptor) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractFrameDescriptor}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractFrameDescriptor) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractFrameDescriptor}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractFrameDescriptor) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(36)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractFrameDescriptor) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractFrameDescriptor) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractFrameDescriptor) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractFrameDescriptor) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractFrameDescriptor) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractFrameDescriptor) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractFrameDescriptor) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractFrameDescriptor}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractFrameDescriptor) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractFrameDescriptor}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractFrameDescriptor) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractFrameDescriptor) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractFrameDescriptor) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractFrameDescriptor, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractFrameDescriptor}, meta_attribute)
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
    epoch_id(::AbstractFrameDescriptor) = begin
            UInt16(2)
        end
    epoch_id(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(2)
        end
    epoch_since_version(::AbstractFrameDescriptor) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractFrameDescriptor) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractFrameDescriptor) = begin
            Int(4)
        end
    epoch_encoding_offset(::Type{<:AbstractFrameDescriptor}) = begin
            Int(4)
        end
    epoch_encoding_length(::AbstractFrameDescriptor) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractFrameDescriptor}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractFrameDescriptor) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractFrameDescriptor) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractFrameDescriptor) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractFrameDescriptor, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractFrameDescriptor}, meta_attribute)
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
    seq_id(::AbstractFrameDescriptor) = begin
            UInt16(3)
        end
    seq_id(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(3)
        end
    seq_since_version(::AbstractFrameDescriptor) = begin
            UInt16(0)
        end
    seq_since_version(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(0)
        end
    seq_in_acting_version(m::AbstractFrameDescriptor) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    seq_encoding_offset(::AbstractFrameDescriptor) = begin
            Int(12)
        end
    seq_encoding_offset(::Type{<:AbstractFrameDescriptor}) = begin
            Int(12)
        end
    seq_encoding_length(::AbstractFrameDescriptor) = begin
            Int(8)
        end
    seq_encoding_length(::Type{<:AbstractFrameDescriptor}) = begin
            Int(8)
        end
    seq_null_value(::AbstractFrameDescriptor) = begin
            UInt64(18446744073709551615)
        end
    seq_null_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(18446744073709551615)
        end
    seq_min_value(::AbstractFrameDescriptor) = begin
            UInt64(0)
        end
    seq_min_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(0)
        end
    seq_max_value(::AbstractFrameDescriptor) = begin
            UInt64(18446744073709551614)
        end
    seq_max_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function seq_meta_attribute(::AbstractFrameDescriptor, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function seq_meta_attribute(::Type{<:AbstractFrameDescriptor}, meta_attribute)
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
    headerIndex_id(::AbstractFrameDescriptor) = begin
            UInt16(4)
        end
    headerIndex_id(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(4)
        end
    headerIndex_since_version(::AbstractFrameDescriptor) = begin
            UInt16(0)
        end
    headerIndex_since_version(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(0)
        end
    headerIndex_in_acting_version(m::AbstractFrameDescriptor) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    headerIndex_encoding_offset(::AbstractFrameDescriptor) = begin
            Int(20)
        end
    headerIndex_encoding_offset(::Type{<:AbstractFrameDescriptor}) = begin
            Int(20)
        end
    headerIndex_encoding_length(::AbstractFrameDescriptor) = begin
            Int(4)
        end
    headerIndex_encoding_length(::Type{<:AbstractFrameDescriptor}) = begin
            Int(4)
        end
    headerIndex_null_value(::AbstractFrameDescriptor) = begin
            UInt32(4294967295)
        end
    headerIndex_null_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(4294967295)
        end
    headerIndex_min_value(::AbstractFrameDescriptor) = begin
            UInt32(0)
        end
    headerIndex_min_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(0)
        end
    headerIndex_max_value(::AbstractFrameDescriptor) = begin
            UInt32(4294967294)
        end
    headerIndex_max_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(4294967294)
        end
end
begin
    function headerIndex_meta_attribute(::AbstractFrameDescriptor, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function headerIndex_meta_attribute(::Type{<:AbstractFrameDescriptor}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function headerIndex(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 20)
        end
    @inline headerIndex!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 20, val)
            end
    export headerIndex, headerIndex!
end
begin
    timestampNs_id(::AbstractFrameDescriptor) = begin
            UInt16(5)
        end
    timestampNs_id(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(5)
        end
    timestampNs_since_version(::AbstractFrameDescriptor) = begin
            UInt16(0)
        end
    timestampNs_since_version(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(0)
        end
    timestampNs_in_acting_version(m::AbstractFrameDescriptor) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    timestampNs_encoding_offset(::AbstractFrameDescriptor) = begin
            Int(24)
        end
    timestampNs_encoding_offset(::Type{<:AbstractFrameDescriptor}) = begin
            Int(24)
        end
    timestampNs_encoding_length(::AbstractFrameDescriptor) = begin
            Int(8)
        end
    timestampNs_encoding_length(::Type{<:AbstractFrameDescriptor}) = begin
            Int(8)
        end
    timestampNs_null_value(::AbstractFrameDescriptor) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_null_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(18446744073709551615)
        end
    timestampNs_min_value(::AbstractFrameDescriptor) = begin
            UInt64(0)
        end
    timestampNs_min_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(0)
        end
    timestampNs_max_value(::AbstractFrameDescriptor) = begin
            UInt64(18446744073709551614)
        end
    timestampNs_max_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function timestampNs_meta_attribute(::AbstractFrameDescriptor, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function timestampNs_meta_attribute(::Type{<:AbstractFrameDescriptor}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function timestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 24)
        end
    @inline timestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 24, val)
            end
    export timestampNs, timestampNs!
end
begin
    metaVersion_id(::AbstractFrameDescriptor) = begin
            UInt16(6)
        end
    metaVersion_id(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(6)
        end
    metaVersion_since_version(::AbstractFrameDescriptor) = begin
            UInt16(0)
        end
    metaVersion_since_version(::Type{<:AbstractFrameDescriptor}) = begin
            UInt16(0)
        end
    metaVersion_in_acting_version(m::AbstractFrameDescriptor) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    metaVersion_encoding_offset(::AbstractFrameDescriptor) = begin
            Int(32)
        end
    metaVersion_encoding_offset(::Type{<:AbstractFrameDescriptor}) = begin
            Int(32)
        end
    metaVersion_encoding_length(::AbstractFrameDescriptor) = begin
            Int(4)
        end
    metaVersion_encoding_length(::Type{<:AbstractFrameDescriptor}) = begin
            Int(4)
        end
    metaVersion_null_value(::AbstractFrameDescriptor) = begin
            UInt32(4294967295)
        end
    metaVersion_null_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(4294967295)
        end
    metaVersion_min_value(::AbstractFrameDescriptor) = begin
            UInt32(0)
        end
    metaVersion_min_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(0)
        end
    metaVersion_max_value(::AbstractFrameDescriptor) = begin
            UInt32(4294967294)
        end
    metaVersion_max_value(::Type{<:AbstractFrameDescriptor}) = begin
            UInt32(4294967294)
        end
end
begin
    function metaVersion_meta_attribute(::AbstractFrameDescriptor, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function metaVersion_meta_attribute(::Type{<:AbstractFrameDescriptor}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function metaVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 32)
        end
    @inline metaVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 32, val)
            end
    export metaVersion, metaVersion!
end
@inline function sbe_decoded_length(m::AbstractFrameDescriptor)
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
module ShmRegionSuperblock
export AbstractShmRegionSuperblock, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractShmRegionSuperblock{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..RegionType
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractShmRegionSuperblock{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractShmRegionSuperblock{T}
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
        if MessageHeader.templateId(header) != UInt16(50) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(64)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(64))
        MessageHeader.templateId!(header, UInt16(50))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractShmRegionSuperblock) = begin
        m.buffer
    end
sbe_offset(m::AbstractShmRegionSuperblock) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractShmRegionSuperblock) = begin
        m.position_ptr
    end
sbe_position(m::AbstractShmRegionSuperblock) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractShmRegionSuperblock, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractShmRegionSuperblock) = begin
        UInt16(64)
    end
sbe_block_length(::Type{<:AbstractShmRegionSuperblock}) = begin
        UInt16(64)
    end
sbe_template_id(::AbstractShmRegionSuperblock) = begin
        UInt16(50)
    end
sbe_template_id(::Type{<:AbstractShmRegionSuperblock}) = begin
        UInt16(50)
    end
sbe_schema_id(::AbstractShmRegionSuperblock) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractShmRegionSuperblock}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractShmRegionSuperblock) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractShmRegionSuperblock}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractShmRegionSuperblock) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(64)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractShmRegionSuperblock) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractShmRegionSuperblock) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractShmRegionSuperblock) = begin
        sbe_encoded_length(m)
    end
begin
    magic_id(::AbstractShmRegionSuperblock) = begin
            UInt16(1)
        end
    magic_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(1)
        end
    magic_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    magic_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    magic_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    magic_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(0)
        end
    magic_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(0)
        end
    magic_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(8)
        end
    magic_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(8)
        end
    magic_null_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551615)
        end
    magic_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551615)
        end
    magic_min_value(::AbstractShmRegionSuperblock) = begin
            UInt64(0)
        end
    magic_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(0)
        end
    magic_max_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551614)
        end
    magic_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function magic_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function magic_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function magic(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 0)
        end
    @inline magic!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 0, val)
            end
    export magic, magic!
end
begin
    layoutVersion_id(::AbstractShmRegionSuperblock) = begin
            UInt16(2)
        end
    layoutVersion_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(2)
        end
    layoutVersion_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    layoutVersion_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    layoutVersion_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    layoutVersion_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(8)
        end
    layoutVersion_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(8)
        end
    layoutVersion_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(4)
        end
    layoutVersion_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(4)
        end
    layoutVersion_null_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967295)
        end
    layoutVersion_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967295)
        end
    layoutVersion_min_value(::AbstractShmRegionSuperblock) = begin
            UInt32(0)
        end
    layoutVersion_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(0)
        end
    layoutVersion_max_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967294)
        end
    layoutVersion_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967294)
        end
end
begin
    function layoutVersion_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function layoutVersion_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function layoutVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 8)
        end
    @inline layoutVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 8, val)
            end
    export layoutVersion, layoutVersion!
end
begin
    epoch_id(::AbstractShmRegionSuperblock) = begin
            UInt16(3)
        end
    epoch_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(3)
        end
    epoch_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    epoch_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    epoch_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    epoch_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(12)
        end
    epoch_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(12)
        end
    epoch_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(8)
        end
    epoch_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(8)
        end
    epoch_null_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551615)
        end
    epoch_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551615)
        end
    epoch_min_value(::AbstractShmRegionSuperblock) = begin
            UInt64(0)
        end
    epoch_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(0)
        end
    epoch_max_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551614)
        end
    epoch_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function epoch_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function epoch_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function epoch(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 12)
        end
    @inline epoch!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 12, val)
            end
    export epoch, epoch!
end
begin
    streamId_id(::AbstractShmRegionSuperblock) = begin
            UInt16(4)
        end
    streamId_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(4)
        end
    streamId_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(20)
        end
    streamId_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(20)
        end
    streamId_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractShmRegionSuperblock) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function streamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 20)
        end
    @inline streamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 20, val)
            end
    export streamId, streamId!
end
begin
    regionType_id(::AbstractShmRegionSuperblock) = begin
            UInt16(5)
        end
    regionType_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(5)
        end
    regionType_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    regionType_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    regionType_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    regionType_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(24)
        end
    regionType_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(24)
        end
    regionType_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(2)
        end
    regionType_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(2)
        end
    regionType_null_value(::AbstractShmRegionSuperblock) = begin
            Int16(-32768)
        end
    regionType_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int16(-32768)
        end
    regionType_min_value(::AbstractShmRegionSuperblock) = begin
            Int16(-32767)
        end
    regionType_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int16(-32767)
        end
    regionType_max_value(::AbstractShmRegionSuperblock) = begin
            Int16(32767)
        end
    regionType_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int16(32767)
        end
end
begin
    function regionType_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function regionType_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function regionType(m::Decoder, ::Type{Integer})
            return decode_value(Int16, m.buffer, m.offset + 24)
        end
    @inline function regionType(m::Decoder)
            raw = decode_value(Int16, m.buffer, m.offset + 24)
            return RegionType.SbeEnum(raw)
        end
    @inline function regionType!(m::Encoder, value::RegionType.SbeEnum)
            encode_value(Int16, m.buffer, m.offset + 24, Int16(value))
        end
    export regionType, regionType!
end
begin
    poolId_id(::AbstractShmRegionSuperblock) = begin
            UInt16(6)
        end
    poolId_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(6)
        end
    poolId_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    poolId_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    poolId_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    poolId_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(26)
        end
    poolId_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(26)
        end
    poolId_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(2)
        end
    poolId_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(2)
        end
    poolId_null_value(::AbstractShmRegionSuperblock) = begin
            UInt16(65535)
        end
    poolId_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(65535)
        end
    poolId_min_value(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    poolId_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    poolId_max_value(::AbstractShmRegionSuperblock) = begin
            UInt16(65534)
        end
    poolId_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(65534)
        end
end
begin
    function poolId_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function poolId_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function poolId(m::Decoder)
            return decode_value(UInt16, m.buffer, m.offset + 26)
        end
    @inline poolId!(m::Encoder, val) = begin
                encode_value(UInt16, m.buffer, m.offset + 26, val)
            end
    export poolId, poolId!
end
begin
    nslots_id(::AbstractShmRegionSuperblock) = begin
            UInt16(7)
        end
    nslots_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(7)
        end
    nslots_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    nslots_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    nslots_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    nslots_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(28)
        end
    nslots_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(28)
        end
    nslots_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(4)
        end
    nslots_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(4)
        end
    nslots_null_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967295)
        end
    nslots_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967295)
        end
    nslots_min_value(::AbstractShmRegionSuperblock) = begin
            UInt32(0)
        end
    nslots_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(0)
        end
    nslots_max_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967294)
        end
    nslots_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967294)
        end
end
begin
    function nslots_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function nslots_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function nslots(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 28)
        end
    @inline nslots!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 28, val)
            end
    export nslots, nslots!
end
begin
    slotBytes_id(::AbstractShmRegionSuperblock) = begin
            UInt16(8)
        end
    slotBytes_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(8)
        end
    slotBytes_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    slotBytes_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    slotBytes_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    slotBytes_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(32)
        end
    slotBytes_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(32)
        end
    slotBytes_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(4)
        end
    slotBytes_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(4)
        end
    slotBytes_null_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967295)
        end
    slotBytes_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967295)
        end
    slotBytes_min_value(::AbstractShmRegionSuperblock) = begin
            UInt32(0)
        end
    slotBytes_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(0)
        end
    slotBytes_max_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967294)
        end
    slotBytes_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967294)
        end
end
begin
    function slotBytes_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function slotBytes_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function slotBytes(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 32)
        end
    @inline slotBytes!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 32, val)
            end
    export slotBytes, slotBytes!
end
begin
    strideBytes_id(::AbstractShmRegionSuperblock) = begin
            UInt16(9)
        end
    strideBytes_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(9)
        end
    strideBytes_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    strideBytes_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    strideBytes_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    strideBytes_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(36)
        end
    strideBytes_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(36)
        end
    strideBytes_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(4)
        end
    strideBytes_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(4)
        end
    strideBytes_null_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967295)
        end
    strideBytes_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967295)
        end
    strideBytes_min_value(::AbstractShmRegionSuperblock) = begin
            UInt32(0)
        end
    strideBytes_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(0)
        end
    strideBytes_max_value(::AbstractShmRegionSuperblock) = begin
            UInt32(4294967294)
        end
    strideBytes_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt32(4294967294)
        end
end
begin
    function strideBytes_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function strideBytes_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function strideBytes(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 36)
        end
    @inline strideBytes!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 36, val)
            end
    export strideBytes, strideBytes!
end
begin
    pid_id(::AbstractShmRegionSuperblock) = begin
            UInt16(10)
        end
    pid_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(10)
        end
    pid_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    pid_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    pid_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    pid_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(40)
        end
    pid_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(40)
        end
    pid_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(8)
        end
    pid_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(8)
        end
    pid_null_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551615)
        end
    pid_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551615)
        end
    pid_min_value(::AbstractShmRegionSuperblock) = begin
            UInt64(0)
        end
    pid_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(0)
        end
    pid_max_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551614)
        end
    pid_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function pid_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function pid_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function pid(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 40)
        end
    @inline pid!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 40, val)
            end
    export pid, pid!
end
begin
    startTimestampNs_id(::AbstractShmRegionSuperblock) = begin
            UInt16(11)
        end
    startTimestampNs_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(11)
        end
    startTimestampNs_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    startTimestampNs_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    startTimestampNs_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    startTimestampNs_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(48)
        end
    startTimestampNs_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(48)
        end
    startTimestampNs_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(8)
        end
    startTimestampNs_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(8)
        end
    startTimestampNs_null_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551615)
        end
    startTimestampNs_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551615)
        end
    startTimestampNs_min_value(::AbstractShmRegionSuperblock) = begin
            UInt64(0)
        end
    startTimestampNs_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(0)
        end
    startTimestampNs_max_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551614)
        end
    startTimestampNs_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function startTimestampNs_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function startTimestampNs_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function startTimestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 48)
        end
    @inline startTimestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 48, val)
            end
    export startTimestampNs, startTimestampNs!
end
begin
    activityTimestampNs_id(::AbstractShmRegionSuperblock) = begin
            UInt16(12)
        end
    activityTimestampNs_id(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(12)
        end
    activityTimestampNs_since_version(::AbstractShmRegionSuperblock) = begin
            UInt16(0)
        end
    activityTimestampNs_since_version(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt16(0)
        end
    activityTimestampNs_in_acting_version(m::AbstractShmRegionSuperblock) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    activityTimestampNs_encoding_offset(::AbstractShmRegionSuperblock) = begin
            Int(56)
        end
    activityTimestampNs_encoding_offset(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(56)
        end
    activityTimestampNs_encoding_length(::AbstractShmRegionSuperblock) = begin
            Int(8)
        end
    activityTimestampNs_encoding_length(::Type{<:AbstractShmRegionSuperblock}) = begin
            Int(8)
        end
    activityTimestampNs_null_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551615)
        end
    activityTimestampNs_null_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551615)
        end
    activityTimestampNs_min_value(::AbstractShmRegionSuperblock) = begin
            UInt64(0)
        end
    activityTimestampNs_min_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(0)
        end
    activityTimestampNs_max_value(::AbstractShmRegionSuperblock) = begin
            UInt64(18446744073709551614)
        end
    activityTimestampNs_max_value(::Type{<:AbstractShmRegionSuperblock}) = begin
            UInt64(18446744073709551614)
        end
end
begin
    function activityTimestampNs_meta_attribute(::AbstractShmRegionSuperblock, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function activityTimestampNs_meta_attribute(::Type{<:AbstractShmRegionSuperblock}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function activityTimestampNs(m::Decoder)
            return decode_value(UInt64, m.buffer, m.offset + 56)
        end
    @inline activityTimestampNs!(m::Encoder, val) = begin
                encode_value(UInt64, m.buffer, m.offset + 56, val)
            end
    export activityTimestampNs, activityTimestampNs!
end
@inline function sbe_decoded_length(m::AbstractShmRegionSuperblock)
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
module ConsumerHello
export AbstractConsumerHello, Decoder, Encoder
using SBE: AbstractSbeMessage, PositionPointer, to_string
import SBE: sbe_buffer, sbe_offset, sbe_position_ptr, sbe_position, sbe_position!
import SBE: sbe_block_length, sbe_template_id, sbe_schema_id, sbe_schema_version
import SBE: sbe_acting_block_length, sbe_acting_version, sbe_rewind!
import SBE: sbe_encoded_length, sbe_decoded_length, sbe_semantic_type
abstract type AbstractConsumerHello{T} <: AbstractSbeMessage{T} end
using ..MessageHeader
using StringViews: StringView
using ..Bool_
using ..Mode
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
mutable struct Decoder{T <: AbstractArray{UInt8}} <: AbstractConsumerHello{T}
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
mutable struct Encoder{T <: AbstractArray{UInt8}} <: AbstractConsumerHello{T}
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
        if MessageHeader.templateId(header) != UInt16(2) || MessageHeader.schemaId(header) != UInt16(900)
            throw(DomainError("Template id or schema id mismatch"))
        end
        return wrap!(m, buffer, offset + sbe_encoded_length(header), MessageHeader.blockLength(header), MessageHeader.version(header))
    end
@inline function wrap!(m::Encoder{T}, buffer::T, offset::Integer) where T
        m.buffer = buffer
        m.offset = Int64(offset)
        m.position_ptr[] = m.offset + UInt16(39)
        return m
    end
@inline function wrap_and_apply_header!(m::Encoder, buffer::AbstractArray, offset::Integer = 0; header = MessageHeader.Encoder(buffer, offset))
        MessageHeader.blockLength!(header, UInt16(39))
        MessageHeader.templateId!(header, UInt16(2))
        MessageHeader.schemaId!(header, UInt16(900))
        MessageHeader.version!(header, UInt16(1))
        return wrap!(m, buffer, offset + sbe_encoded_length(header))
    end
sbe_buffer(m::AbstractConsumerHello) = begin
        m.buffer
    end
sbe_offset(m::AbstractConsumerHello) = begin
        m.offset
    end
sbe_position_ptr(m::AbstractConsumerHello) = begin
        m.position_ptr
    end
sbe_position(m::AbstractConsumerHello) = begin
        m.position_ptr[]
    end
sbe_position!(m::AbstractConsumerHello, position) = begin
        m.position_ptr[] = position
    end
sbe_block_length(::AbstractConsumerHello) = begin
        UInt16(39)
    end
sbe_block_length(::Type{<:AbstractConsumerHello}) = begin
        UInt16(39)
    end
sbe_template_id(::AbstractConsumerHello) = begin
        UInt16(2)
    end
sbe_template_id(::Type{<:AbstractConsumerHello}) = begin
        UInt16(2)
    end
sbe_schema_id(::AbstractConsumerHello) = begin
        UInt16(900)
    end
sbe_schema_id(::Type{<:AbstractConsumerHello}) = begin
        UInt16(900)
    end
sbe_schema_version(::AbstractConsumerHello) = begin
        UInt16(1)
    end
sbe_schema_version(::Type{<:AbstractConsumerHello}) = begin
        UInt16(1)
    end
sbe_semantic_type(::AbstractConsumerHello) = begin
        ""
    end
sbe_acting_block_length(m::Decoder) = begin
        m.acting_block_length
    end
sbe_acting_block_length(::Encoder) = begin
        UInt16(39)
    end
sbe_acting_version(m::Decoder) = begin
        m.acting_version
    end
sbe_acting_version(::Encoder) = begin
        UInt16(1)
    end
sbe_rewind!(m::AbstractConsumerHello) = begin
        sbe_position!(m, m.offset + sbe_acting_block_length(m))
    end
sbe_encoded_length(m::AbstractConsumerHello) = begin
        sbe_position(m) - m.offset
    end
Base.sizeof(m::AbstractConsumerHello) = begin
        sbe_encoded_length(m)
    end
begin
    streamId_id(::AbstractConsumerHello) = begin
            UInt16(1)
        end
    streamId_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(1)
        end
    streamId_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    streamId_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    streamId_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    streamId_encoding_offset(::AbstractConsumerHello) = begin
            Int(0)
        end
    streamId_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(0)
        end
    streamId_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    streamId_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    streamId_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    streamId_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    streamId_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    streamId_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    streamId_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    streamId_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function streamId_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function streamId_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
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
    consumerId_id(::AbstractConsumerHello) = begin
            UInt16(2)
        end
    consumerId_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(2)
        end
    consumerId_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    consumerId_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    consumerId_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    consumerId_encoding_offset(::AbstractConsumerHello) = begin
            Int(4)
        end
    consumerId_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    consumerId_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    consumerId_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    consumerId_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    consumerId_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    consumerId_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    consumerId_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    consumerId_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    consumerId_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function consumerId_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function consumerId_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function consumerId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 4)
        end
    @inline consumerId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 4, val)
            end
    export consumerId, consumerId!
end
begin
    supportsShm_id(::AbstractConsumerHello) = begin
            UInt16(3)
        end
    supportsShm_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(3)
        end
    supportsShm_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    supportsShm_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    supportsShm_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    supportsShm_encoding_offset(::AbstractConsumerHello) = begin
            Int(8)
        end
    supportsShm_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(8)
        end
    supportsShm_encoding_length(::AbstractConsumerHello) = begin
            Int(1)
        end
    supportsShm_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(1)
        end
    supportsShm_null_value(::AbstractConsumerHello) = begin
            UInt8(255)
        end
    supportsShm_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(255)
        end
    supportsShm_min_value(::AbstractConsumerHello) = begin
            UInt8(0)
        end
    supportsShm_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(0)
        end
    supportsShm_max_value(::AbstractConsumerHello) = begin
            UInt8(254)
        end
    supportsShm_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(254)
        end
end
begin
    function supportsShm_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function supportsShm_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function supportsShm(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 8)
        end
    @inline function supportsShm(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 8)
            return Bool_.SbeEnum(raw)
        end
    @inline function supportsShm!(m::Encoder, value::Bool_.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 8, UInt8(value))
        end
    export supportsShm, supportsShm!
end
begin
    supportsProgress_id(::AbstractConsumerHello) = begin
            UInt16(4)
        end
    supportsProgress_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(4)
        end
    supportsProgress_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    supportsProgress_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    supportsProgress_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    supportsProgress_encoding_offset(::AbstractConsumerHello) = begin
            Int(9)
        end
    supportsProgress_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(9)
        end
    supportsProgress_encoding_length(::AbstractConsumerHello) = begin
            Int(1)
        end
    supportsProgress_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(1)
        end
    supportsProgress_null_value(::AbstractConsumerHello) = begin
            UInt8(255)
        end
    supportsProgress_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(255)
        end
    supportsProgress_min_value(::AbstractConsumerHello) = begin
            UInt8(0)
        end
    supportsProgress_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(0)
        end
    supportsProgress_max_value(::AbstractConsumerHello) = begin
            UInt8(254)
        end
    supportsProgress_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(254)
        end
end
begin
    function supportsProgress_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function supportsProgress_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function supportsProgress(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 9)
        end
    @inline function supportsProgress(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 9)
            return Bool_.SbeEnum(raw)
        end
    @inline function supportsProgress!(m::Encoder, value::Bool_.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 9, UInt8(value))
        end
    export supportsProgress, supportsProgress!
end
begin
    mode_id(::AbstractConsumerHello) = begin
            UInt16(5)
        end
    mode_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(5)
        end
    mode_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    mode_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    mode_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    mode_encoding_offset(::AbstractConsumerHello) = begin
            Int(10)
        end
    mode_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(10)
        end
    mode_encoding_length(::AbstractConsumerHello) = begin
            Int(1)
        end
    mode_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(1)
        end
    mode_null_value(::AbstractConsumerHello) = begin
            UInt8(255)
        end
    mode_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(255)
        end
    mode_min_value(::AbstractConsumerHello) = begin
            UInt8(0)
        end
    mode_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(0)
        end
    mode_max_value(::AbstractConsumerHello) = begin
            UInt8(254)
        end
    mode_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt8(254)
        end
end
begin
    function mode_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function mode_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function mode(m::Decoder, ::Type{Integer})
            return decode_value(UInt8, m.buffer, m.offset + 10)
        end
    @inline function mode(m::Decoder)
            raw = decode_value(UInt8, m.buffer, m.offset + 10)
            return Mode.SbeEnum(raw)
        end
    @inline function mode!(m::Encoder, value::Mode.SbeEnum)
            encode_value(UInt8, m.buffer, m.offset + 10, UInt8(value))
        end
    export mode, mode!
end
begin
    maxRateHz_id(::AbstractConsumerHello) = begin
            UInt16(6)
        end
    maxRateHz_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(6)
        end
    maxRateHz_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    maxRateHz_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    maxRateHz_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    maxRateHz_encoding_offset(::AbstractConsumerHello) = begin
            Int(11)
        end
    maxRateHz_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(11)
        end
    maxRateHz_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    maxRateHz_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    maxRateHz_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    maxRateHz_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    maxRateHz_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    maxRateHz_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    maxRateHz_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    maxRateHz_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function maxRateHz_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function maxRateHz_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function maxRateHz(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 11)
        end
    @inline maxRateHz!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 11, val)
            end
    export maxRateHz, maxRateHz!
end
begin
    expectedLayoutVersion_id(::AbstractConsumerHello) = begin
            UInt16(7)
        end
    expectedLayoutVersion_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(7)
        end
    expectedLayoutVersion_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    expectedLayoutVersion_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    expectedLayoutVersion_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    expectedLayoutVersion_encoding_offset(::AbstractConsumerHello) = begin
            Int(15)
        end
    expectedLayoutVersion_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(15)
        end
    expectedLayoutVersion_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    expectedLayoutVersion_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    expectedLayoutVersion_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    expectedLayoutVersion_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    expectedLayoutVersion_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    expectedLayoutVersion_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    expectedLayoutVersion_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    expectedLayoutVersion_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function expectedLayoutVersion_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function expectedLayoutVersion_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function expectedLayoutVersion(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 15)
        end
    @inline expectedLayoutVersion!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 15, val)
            end
    export expectedLayoutVersion, expectedLayoutVersion!
end
begin
    progressIntervalUs_id(::AbstractConsumerHello) = begin
            UInt16(8)
        end
    progressIntervalUs_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(8)
        end
    progressIntervalUs_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    progressIntervalUs_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    progressIntervalUs_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    progressIntervalUs_encoding_offset(::AbstractConsumerHello) = begin
            Int(19)
        end
    progressIntervalUs_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(19)
        end
    progressIntervalUs_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    progressIntervalUs_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    progressIntervalUs_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    progressIntervalUs_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    progressIntervalUs_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    progressIntervalUs_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    progressIntervalUs_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    progressIntervalUs_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function progressIntervalUs_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function progressIntervalUs_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function progressIntervalUs(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 19)
        end
    @inline progressIntervalUs!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 19, val)
            end
    export progressIntervalUs, progressIntervalUs!
end
begin
    progressBytesDelta_id(::AbstractConsumerHello) = begin
            UInt16(9)
        end
    progressBytesDelta_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(9)
        end
    progressBytesDelta_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    progressBytesDelta_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    progressBytesDelta_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    progressBytesDelta_encoding_offset(::AbstractConsumerHello) = begin
            Int(23)
        end
    progressBytesDelta_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(23)
        end
    progressBytesDelta_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    progressBytesDelta_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    progressBytesDelta_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    progressBytesDelta_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    progressBytesDelta_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    progressBytesDelta_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    progressBytesDelta_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    progressBytesDelta_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function progressBytesDelta_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function progressBytesDelta_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function progressBytesDelta(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 23)
        end
    @inline progressBytesDelta!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 23, val)
            end
    export progressBytesDelta, progressBytesDelta!
end
begin
    progressRowsDelta_id(::AbstractConsumerHello) = begin
            UInt16(10)
        end
    progressRowsDelta_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(10)
        end
    progressRowsDelta_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    progressRowsDelta_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    progressRowsDelta_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    progressRowsDelta_encoding_offset(::AbstractConsumerHello) = begin
            Int(27)
        end
    progressRowsDelta_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(27)
        end
    progressRowsDelta_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    progressRowsDelta_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    progressRowsDelta_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    progressRowsDelta_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    progressRowsDelta_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    progressRowsDelta_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    progressRowsDelta_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    progressRowsDelta_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function progressRowsDelta_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function progressRowsDelta_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function progressRowsDelta(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 27)
        end
    @inline progressRowsDelta!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 27, val)
            end
    export progressRowsDelta, progressRowsDelta!
end
begin
    descriptorStreamId_id(::AbstractConsumerHello) = begin
            UInt16(11)
        end
    descriptorStreamId_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(11)
        end
    descriptorStreamId_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    descriptorStreamId_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    descriptorStreamId_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    descriptorStreamId_encoding_offset(::AbstractConsumerHello) = begin
            Int(31)
        end
    descriptorStreamId_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(31)
        end
    descriptorStreamId_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    descriptorStreamId_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    descriptorStreamId_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    descriptorStreamId_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    descriptorStreamId_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    descriptorStreamId_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    descriptorStreamId_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    descriptorStreamId_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function descriptorStreamId_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function descriptorStreamId_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function descriptorStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 31)
        end
    @inline descriptorStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 31, val)
            end
    export descriptorStreamId, descriptorStreamId!
end
begin
    controlStreamId_id(::AbstractConsumerHello) = begin
            UInt16(12)
        end
    controlStreamId_id(::Type{<:AbstractConsumerHello}) = begin
            UInt16(12)
        end
    controlStreamId_since_version(::AbstractConsumerHello) = begin
            UInt16(0)
        end
    controlStreamId_since_version(::Type{<:AbstractConsumerHello}) = begin
            UInt16(0)
        end
    controlStreamId_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
    controlStreamId_encoding_offset(::AbstractConsumerHello) = begin
            Int(35)
        end
    controlStreamId_encoding_offset(::Type{<:AbstractConsumerHello}) = begin
            Int(35)
        end
    controlStreamId_encoding_length(::AbstractConsumerHello) = begin
            Int(4)
        end
    controlStreamId_encoding_length(::Type{<:AbstractConsumerHello}) = begin
            Int(4)
        end
    controlStreamId_null_value(::AbstractConsumerHello) = begin
            UInt32(4294967295)
        end
    controlStreamId_null_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967295)
        end
    controlStreamId_min_value(::AbstractConsumerHello) = begin
            UInt32(0)
        end
    controlStreamId_min_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(0)
        end
    controlStreamId_max_value(::AbstractConsumerHello) = begin
            UInt32(4294967294)
        end
    controlStreamId_max_value(::Type{<:AbstractConsumerHello}) = begin
            UInt32(4294967294)
        end
end
begin
    function controlStreamId_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function controlStreamId_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("optional")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    @inline function controlStreamId(m::Decoder)
            return decode_value(UInt32, m.buffer, m.offset + 35)
        end
    @inline controlStreamId!(m::Encoder, val) = begin
                encode_value(UInt32, m.buffer, m.offset + 35, val)
            end
    export controlStreamId, controlStreamId!
end
begin
    function descriptorChannel_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function descriptorChannel_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    descriptorChannel_character_encoding(::AbstractConsumerHello) = begin
            "US-ASCII"
        end
    descriptorChannel_character_encoding(::Type{<:AbstractConsumerHello}) = begin
            "US-ASCII"
        end
end
begin
    const descriptorChannel_id = UInt16(13)
    const descriptorChannel_since_version = UInt16(0)
    const descriptorChannel_header_length = 4
    descriptorChannel_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function descriptorChannel_length(m::AbstractConsumerHello)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function descriptorChannel_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_descriptorChannel!(m::Decoder)
            len = descriptorChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function descriptorChannel(m::Decoder)
            len = descriptorChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function descriptorChannel_buffer!(m::Encoder, len)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function descriptorChannel!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function descriptorChannel!(m::Encoder, src::NTuple)
            len = sizeof(src)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function descriptorChannel!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            descriptorChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline descriptorChannel!(m::Encoder, src::Symbol) = begin
                descriptorChannel!(m, to_string(src))
            end
    @inline descriptorChannel!(m::Encoder, src::Real) = begin
                descriptorChannel!(m, Tuple(src))
            end
    @inline descriptorChannel!(m::Encoder, ::Nothing) = begin
                descriptorChannel_buffer!(m, 0)
            end
end
begin
    @inline function descriptorChannel(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(descriptorChannel(m))))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(descriptorChannel(m)))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(descriptorChannel(m, StringView))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, descriptorChannel(m)))[]
        end
    @inline function descriptorChannel(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, descriptorChannel(m))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, descriptorChannel(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function descriptorChannel(m::Decoder, ::Type{T}) where T <: Nothing
            skip_descriptorChannel!(m)
            return nothing
        end
end
begin
    function controlChannel_meta_attribute(::AbstractConsumerHello, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
    function controlChannel_meta_attribute(::Type{<:AbstractConsumerHello}, meta_attribute)
        meta_attribute === :presence && return Symbol("required")
        meta_attribute === :semanticType && return Symbol("")
        return Symbol("")
    end
end
begin
    controlChannel_character_encoding(::AbstractConsumerHello) = begin
            "US-ASCII"
        end
    controlChannel_character_encoding(::Type{<:AbstractConsumerHello}) = begin
            "US-ASCII"
        end
end
begin
    const controlChannel_id = UInt16(14)
    const controlChannel_since_version = UInt16(0)
    const controlChannel_header_length = 4
    controlChannel_in_acting_version(m::AbstractConsumerHello) = begin
            sbe_acting_version(m) >= UInt16(0)
        end
end
begin
    @inline function controlChannel_length(m::AbstractConsumerHello)
            return decode_value(UInt32, m.buffer, sbe_position(m))
        end
end
begin
    @inline function controlChannel_length!(m::Encoder, n)
            @boundscheck n > 1073741824 && throw(ArgumentError("length exceeds schema limit"))
            @boundscheck checkbounds(m.buffer, sbe_position(m) + 4 + n)
            return encode_value(UInt32, m.buffer, sbe_position(m), UInt32(n))
        end
end
begin
    @inline function skip_controlChannel!(m::Decoder)
            len = controlChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return len
        end
end
begin
    @inline function controlChannel(m::Decoder)
            len = controlChannel_length(m)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function controlChannel_buffer!(m::Encoder, len)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            return view(m.buffer, pos + 1:pos + len)
        end
end
begin
    @inline function controlChannel!(m::Encoder, src::AbstractArray)
            len = sizeof(eltype(src)) * Base.length(src)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(UInt8, src))
        end
end
begin
    @inline function controlChannel!(m::Encoder, src::NTuple)
            len = sizeof(src)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, reinterpret(NTuple{len, UInt8}, src))
        end
end
begin
    @inline function controlChannel!(m::Encoder, src::AbstractString)
            len = sizeof(src)
            controlChannel_length!(m, len)
            pos = sbe_position(m) + 4
            sbe_position!(m, pos + len)
            dest = view(m.buffer, pos + 1:pos + len)
            copyto!(dest, codeunits(src))
        end
end
begin
    @inline controlChannel!(m::Encoder, src::Symbol) = begin
                controlChannel!(m, to_string(src))
            end
    @inline controlChannel!(m::Encoder, src::Real) = begin
                controlChannel!(m, Tuple(src))
            end
    @inline controlChannel!(m::Encoder, ::Nothing) = begin
                controlChannel_buffer!(m, 0)
            end
end
begin
    @inline function controlChannel(m::Decoder, ::Type{String})
            return String(StringView(rstrip_nul(controlChannel(m))))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: AbstractString
            return StringView(rstrip_nul(controlChannel(m)))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: Symbol
            return Symbol(controlChannel(m, StringView))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: Real
            return (reinterpret(T, controlChannel(m)))[]
        end
    @inline function controlChannel(m::Decoder, ::Type{AbstractArray{T}}) where T <: Real
            return reinterpret(T, controlChannel(m))
        end
    @inline function controlChannel(m::Decoder, ::Type{NTuple{N, T}}) where {N, T <: Real}
            x = reinterpret(T, controlChannel(m))
            return ntuple((i->begin
                            x[i]
                        end), Val(N))
        end
    @inline function controlChannel(m::Decoder, ::Type{T}) where T <: Nothing
            skip_controlChannel!(m)
            return nothing
        end
end
@inline function sbe_decoded_length(m::AbstractConsumerHello)
        skipper = Decoder(typeof(sbe_buffer(m)))
        skipper.position_ptr = PositionPointer()
        wrap!(skipper, sbe_buffer(m), sbe_offset(m), sbe_acting_block_length(m), sbe_acting_version(m))
        sbe_skip!(skipper)
        return sbe_encoded_length(skipper)
    end
@inline function sbe_skip!(m::Decoder)
        sbe_rewind!(m)
        begin
            skip_descriptorChannel!(m)
            skip_controlChannel!(m)
        end
        return
    end
end
end

const Shm_tensorpool_control = ShmTensorpoolControl