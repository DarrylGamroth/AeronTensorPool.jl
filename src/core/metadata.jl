"""
Metadata attribute entry (key/format/value).
"""
struct MetadataAttribute
    key::String
    format::String
    value::Vector{UInt8}
end

"""
Cached metadata entry for a stream.
"""
mutable struct MetadataEntry
    stream_id::UInt32
    producer_id::UInt32
    epoch::UInt64
    meta_version::UInt32
    name::String
    summary::String
    timestamp_ns::UInt64
    attributes::Vector{MetadataAttribute}
end

MetadataEntry(stream_id::UInt32) =
    MetadataEntry(stream_id, UInt32(0), UInt64(0), UInt32(0), "", "", UInt64(0), MetadataAttribute[])

const DEFAULT_METADATA_TEXT_FORMAT = "text/plain"
const DEFAULT_METADATA_BINARY_FORMAT = "application/octet-stream"
const METADATA_CHUNK_MAX = UInt32(64 * 1024)

MetadataAttribute(
    key::AbstractString,
    format::AbstractString,
    value::AbstractVector{UInt8},
) = MetadataAttribute(String(key), String(format), Vector{UInt8}(value))

MetadataAttribute(
    key::AbstractString,
    format::AbstractString,
    value::AbstractString,
) = MetadataAttribute(key, format, Vector{UInt8}(codeunits(value)))

MetadataAttribute(
    key::AbstractString,
    format::AbstractString,
    value::Integer,
) = MetadataAttribute(key, format, Vector{UInt8}(codeunits(string(value))))

MetadataAttribute(kv::Pair{<:AbstractString, <:AbstractString}) =
    MetadataAttribute(kv.first, DEFAULT_METADATA_TEXT_FORMAT, kv.second)

MetadataAttribute(kv::Pair{<:AbstractString, <:Integer}) =
    MetadataAttribute(kv.first, DEFAULT_METADATA_TEXT_FORMAT, kv.second)

MetadataAttribute(kv::Pair{<:AbstractString, <:AbstractVector{UInt8}}) =
    MetadataAttribute(kv.first, DEFAULT_METADATA_BINARY_FORMAT, kv.second)

MetadataAttribute(kv::Pair{<:AbstractString, <:Tuple{<:AbstractString, Any}}) =
    MetadataAttribute(kv.first, kv.second[1], kv.second[2])

MetadataAttribute(kv::Pair{<:AbstractString, <:NamedTuple{(:format, :value), <:Tuple{<:AbstractString, Any}}}) =
    MetadataAttribute(kv.first, kv.second.format, kv.second.value)

"""
Validate metadata chunk offsets and lengths against monotonic, non-overlapping rules.
"""
function validate_metadata_chunks(
    offsets::AbstractVector{UInt32},
    lengths::AbstractVector{UInt32};
    chunk_max::UInt32 = METADATA_CHUNK_MAX,
)
    length(offsets) == length(lengths) || return false
    isempty(offsets) && return true
    last_end = UInt32(0)
    for i in eachindex(offsets)
        len = lengths[i]
        len == 0 && return false
        len > chunk_max && return false
        off = offsets[i]
        off < last_end && return false
        last_end = off + len
    end
    return true
end
