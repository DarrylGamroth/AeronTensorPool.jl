const SUPERBLOCK_SIZE = 64
const HEADER_SLOT_BYTES = 256
const MAGIC_TPOLSHM1 = 0x544F504C53484D31
const MAX_DIMS = 8
const DEFAULT_FRAGMENT_LIMIT = Int32(10)

const CONTROL_BUF_BYTES = 512
const ANNOUNCE_BUF_BYTES = 1024

const RegionType = ShmTensorpoolControl.RegionType
const Dtype = ShmTensorpoolControl.Dtype
const MajorOrder = ShmTensorpoolControl.MajorOrder
const MessageHeader = ShmTensorpoolControl.MessageHeader
const FrameDescriptor = ShmTensorpoolControl.FrameDescriptor
const FrameProgress = ShmTensorpoolControl.FrameProgress
const ConsumerConfigMsg = ShmTensorpoolControl.ConsumerConfig
const ConsumerHello = ShmTensorpoolControl.ConsumerHello
const QosConsumer = ShmTensorpoolControl.QosConsumer
const Mode = ShmTensorpoolControl.Mode
const QosProducer = ShmTensorpoolControl.QosProducer
const ShmPoolAnnounce = ShmTensorpoolControl.ShmPoolAnnounce
const ShmRegionSuperblock = ShmTensorpoolControl.ShmRegionSuperblock
const TensorSlotHeader256 = ShmTensorpoolControl.TensorSlotHeader256

const DriverMessageHeader = ShmTensorpoolDriver.MessageHeader
const DriverBool = ShmTensorpoolDriver.Bool_
const DriverResponseCode = ShmTensorpoolDriver.ResponseCode
const DriverRole = ShmTensorpoolDriver.Role
const DriverPublishMode = ShmTensorpoolDriver.PublishMode
const DriverLeaseRevokeReason = ShmTensorpoolDriver.LeaseRevokeReason
const DriverShutdownReason = ShmTensorpoolDriver.ShutdownReason
const ShmAttachRequest = ShmTensorpoolDriver.ShmAttachRequest
const ShmAttachResponse = ShmTensorpoolDriver.ShmAttachResponse
const ShmDetachRequest = ShmTensorpoolDriver.ShmDetachRequest
const ShmDetachResponse = ShmTensorpoolDriver.ShmDetachResponse
const ShmLeaseKeepalive = ShmTensorpoolDriver.ShmLeaseKeepalive
const ShmDriverShutdown = ShmTensorpoolDriver.ShmDriverShutdown
const ShmLeaseRevoked = ShmTensorpoolDriver.ShmLeaseRevoked

const MESSAGE_HEADER_LEN = Int(MessageHeader.sbe_encoded_length(MessageHeader.Decoder))
const DRIVER_MESSAGE_HEADER_LEN =
    Int(DriverMessageHeader.sbe_encoded_length(DriverMessageHeader.Decoder))
const FRAME_DESCRIPTOR_LEN = MESSAGE_HEADER_LEN + Int(FrameDescriptor.sbe_block_length(FrameDescriptor.Decoder))
const FRAME_PROGRESS_LEN = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_block_length(FrameProgress.Decoder))
const QOS_PRODUCER_LEN = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_block_length(QosProducer.Decoder))
const QOS_CONSUMER_LEN = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_block_length(QosConsumer.Decoder))
const CONSUMER_HELLO_LEN = MESSAGE_HEADER_LEN + Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder))

const TEMPLATE_FRAME_DESCRIPTOR = FrameDescriptor.sbe_template_id(FrameDescriptor.Decoder)
const TEMPLATE_SHM_POOL_ANNOUNCE = ShmPoolAnnounce.sbe_template_id(ShmPoolAnnounce.Decoder)
const TEMPLATE_CONSUMER_CONFIG = ConsumerConfigMsg.sbe_template_id(ConsumerConfigMsg.Decoder)
const TEMPLATE_CONSUMER_HELLO = ConsumerHello.sbe_template_id(ConsumerHello.Decoder)
const TEMPLATE_QOS_CONSUMER = QosConsumer.sbe_template_id(QosConsumer.Decoder)
const TEMPLATE_QOS_PRODUCER = QosProducer.sbe_template_id(QosProducer.Decoder)

const TEMPLATE_SHM_ATTACH_REQUEST = ShmAttachRequest.sbe_template_id(ShmAttachRequest.Decoder)
const TEMPLATE_SHM_ATTACH_RESPONSE = ShmAttachResponse.sbe_template_id(ShmAttachResponse.Decoder)
const TEMPLATE_SHM_DETACH_REQUEST = ShmDetachRequest.sbe_template_id(ShmDetachRequest.Decoder)
const TEMPLATE_SHM_DETACH_RESPONSE = ShmDetachResponse.sbe_template_id(ShmDetachResponse.Decoder)
const TEMPLATE_SHM_LEASE_KEEPALIVE = ShmLeaseKeepalive.sbe_template_id(ShmLeaseKeepalive.Decoder)
const TEMPLATE_SHM_DRIVER_SHUTDOWN = ShmDriverShutdown.sbe_template_id(ShmDriverShutdown.Decoder)
const TEMPLATE_SHM_LEASE_REVOKED = ShmLeaseRevoked.sbe_template_id(ShmLeaseRevoked.Decoder)

"""
Configuration for a payload pool in shared memory.
"""
struct PayloadPoolConfig
    pool_id::UInt16
    uri::String
    stride_bytes::UInt32
    nslots::UInt32
end

"""
Static configuration for the producer role.
"""
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
    shm_base_dir::String
    shm_namespace::String
    producer_instance_id::String
    header_uri::String
    payload_pools::Vector{PayloadPoolConfig}
    max_dims::UInt8
    announce_interval_ns::UInt64
    qos_interval_ns::UInt64
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
end

"""
Decoded superblock fields for SHM validation and diagnostics.
"""
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

"""
Decoded slot header fields for consumer-side validation.
"""
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

"""
Parsed shm:file URI components.
"""
struct ShmUri
    path::String
    require_hugepages::Bool
end
