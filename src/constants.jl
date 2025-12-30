const SUPERBLOCK_SIZE = 64
const HEADER_SLOT_BYTES = 256
const MAGIC_TPOLSHM1 = 0x544F504C53484D31
const MAX_DIMS = 8

const RegionType = ShmTensorpoolControl.RegionType
const Dtype = ShmTensorpoolControl.Dtype
const MajorOrder = ShmTensorpoolControl.MajorOrder
const FrameDescriptor = ShmTensorpoolControl.FrameDescriptor
const FrameProgress = ShmTensorpoolControl.FrameProgress
const QosProducer = ShmTensorpoolControl.QosProducer
const ShmPoolAnnounce = ShmTensorpoolControl.ShmPoolAnnounce
const ShmRegionSuperblock = ShmTensorpoolControl.ShmRegionSuperblock
const TensorSlotHeader256 = ShmTensorpoolControl.TensorSlotHeader256

struct PayloadPoolConfig
    pool_id::UInt16
    uri::String
    stride_bytes::UInt32
    nslots::UInt32
end

struct ProducerConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    control_stream_id::Int32
    qos_stream_id::Int32
    metadata_stream_id::Int32
    stream_id::UInt32
    producer_id::UInt32
    layout_version::UInt32
    nslots::UInt32
    header_uri::String
    payload_pools::Vector{PayloadPoolConfig}
    max_dims::UInt8
    announce_interval_ns::UInt64
    qos_interval_ns::UInt64
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
end

struct SuperblockFields
    magic::UInt64
    layout_version::UInt32
    epoch::UInt64
    stream_id::UInt32
    region_type::RegionType.SbeEnum
    pool_id::UInt16
    nslots::UInt32
    slot_bytes::UInt32
    stride_bytes::UInt32
    pid::UInt64
    start_timestamp_ns::UInt64
    activity_timestamp_ns::UInt64
end

struct TensorSlotHeader
    commit_word::UInt64
    frame_id::UInt64
    timestamp_ns::UInt64
    meta_version::UInt32
    values_len_bytes::UInt32
    payload_slot::UInt32
    payload_offset::UInt32
    pool_id::UInt16
    dtype::Dtype.SbeEnum
    major_order::MajorOrder.SbeEnum
    ndims::UInt8
    pad_align::UInt8
    dims::NTuple{MAX_DIMS, Int32}
    strides::NTuple{MAX_DIMS, Int32}
end

struct ShmUri
    path::String
    require_hugepages::Bool
end

@inline function is_pow2(n::Integer)
    return n > 0 && (n & (n - 1)) == 0
end
