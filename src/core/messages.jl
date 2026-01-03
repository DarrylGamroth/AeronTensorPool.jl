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
const DataSourceAnnounce = ShmTensorpoolControl.DataSourceAnnounce
const DataSourceMeta = ShmTensorpoolControl.DataSourceMeta

const MAX_DIMS::Int = Int(TensorSlotHeader256.maxDims(TensorSlotHeader256.Decoder))

const DriverMessageHeader = ShmTensorpoolDriver.MessageHeader
const DriverHugepagesPolicy = ShmTensorpoolDriver.HugepagesPolicy
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
const ShmDriverShutdownRequest = ShmTensorpoolDriver.ShmDriverShutdownRequest

const BridgeMessageHeader = ShmTensorpoolBridge.MessageHeader
const BridgeBool = ShmTensorpoolBridge.Bool_
const BridgeFrameChunk = ShmTensorpoolBridge.BridgeFrameChunk

const MESSAGE_HEADER_LEN = Int(MessageHeader.sbe_encoded_length(MessageHeader.Decoder))
const DRIVER_MESSAGE_HEADER_LEN =
    Int(DriverMessageHeader.sbe_encoded_length(DriverMessageHeader.Decoder))
const BRIDGE_MESSAGE_HEADER_LEN =
    Int(BridgeMessageHeader.sbe_encoded_length(BridgeMessageHeader.Decoder))
const FRAME_DESCRIPTOR_LEN = MESSAGE_HEADER_LEN + Int(FrameDescriptor.sbe_block_length(FrameDescriptor.Decoder))
const FRAME_PROGRESS_LEN = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_block_length(FrameProgress.Decoder))
const QOS_PRODUCER_LEN = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_block_length(QosProducer.Decoder))
const QOS_CONSUMER_LEN = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_block_length(QosConsumer.Decoder))
const CONSUMER_HELLO_LEN = MESSAGE_HEADER_LEN +
    Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder)) +
    Int(ConsumerHello.descriptorChannel_header_length) +
    Int(ConsumerHello.controlChannel_header_length)

const TEMPLATE_FRAME_DESCRIPTOR = FrameDescriptor.sbe_template_id(FrameDescriptor.Decoder)
const TEMPLATE_FRAME_PROGRESS = FrameProgress.sbe_template_id(FrameProgress.Decoder)
const TEMPLATE_SHM_POOL_ANNOUNCE = ShmPoolAnnounce.sbe_template_id(ShmPoolAnnounce.Decoder)
const TEMPLATE_CONSUMER_CONFIG = ConsumerConfigMsg.sbe_template_id(ConsumerConfigMsg.Decoder)
const TEMPLATE_CONSUMER_HELLO = ConsumerHello.sbe_template_id(ConsumerHello.Decoder)
const TEMPLATE_QOS_CONSUMER = QosConsumer.sbe_template_id(QosConsumer.Decoder)
const TEMPLATE_QOS_PRODUCER = QosProducer.sbe_template_id(QosProducer.Decoder)
const TEMPLATE_DATA_SOURCE_ANNOUNCE = DataSourceAnnounce.sbe_template_id(DataSourceAnnounce.Decoder)
const TEMPLATE_DATA_SOURCE_META = DataSourceMeta.sbe_template_id(DataSourceMeta.Decoder)

const TEMPLATE_SHM_ATTACH_REQUEST = ShmAttachRequest.sbe_template_id(ShmAttachRequest.Decoder)
const TEMPLATE_SHM_ATTACH_RESPONSE = ShmAttachResponse.sbe_template_id(ShmAttachResponse.Decoder)
const TEMPLATE_SHM_DETACH_REQUEST = ShmDetachRequest.sbe_template_id(ShmDetachRequest.Decoder)
const TEMPLATE_SHM_DETACH_RESPONSE = ShmDetachResponse.sbe_template_id(ShmDetachResponse.Decoder)
const TEMPLATE_SHM_LEASE_KEEPALIVE = ShmLeaseKeepalive.sbe_template_id(ShmLeaseKeepalive.Decoder)
const TEMPLATE_SHM_DRIVER_SHUTDOWN = ShmDriverShutdown.sbe_template_id(ShmDriverShutdown.Decoder)
const TEMPLATE_SHM_LEASE_REVOKED = ShmLeaseRevoked.sbe_template_id(ShmLeaseRevoked.Decoder)
const TEMPLATE_SHM_DRIVER_SHUTDOWN_REQUEST =
    ShmDriverShutdownRequest.sbe_template_id(ShmDriverShutdownRequest.Decoder)
const TEMPLATE_BRIDGE_FRAME_CHUNK = BridgeFrameChunk.sbe_template_id(BridgeFrameChunk.Decoder)

"""
Return full SBE message length (header + body) for an encoder/decoder.
"""
@inline function sbe_message_length(msg::SBE.AbstractSbeMessage)
    return MESSAGE_HEADER_LEN + sbe_encoded_length(msg)
end
