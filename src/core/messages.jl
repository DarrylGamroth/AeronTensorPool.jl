const RegionType = ShmTensorpoolControl.RegionType
const Dtype = ShmTensorpoolControl.Dtype
const MajorOrder = ShmTensorpoolControl.MajorOrder
const MessageHeader = ShmTensorpoolControl.MessageHeader
const FrameDescriptor = ShmTensorpoolControl.FrameDescriptor
const FrameProgress = ShmTensorpoolControl.FrameProgress
const ProgressUnit = ShmTensorpoolControl.ProgressUnit
const ClockDomain = ShmTensorpoolControl.ClockDomain
const ConsumerConfigMsg = ShmTensorpoolControl.ConsumerConfig
const ConsumerHello = ShmTensorpoolControl.ConsumerHello
const QosConsumer = ShmTensorpoolControl.QosConsumer
const Mode = ShmTensorpoolControl.Mode
const QosProducer = ShmTensorpoolControl.QosProducer
const ShmPoolAnnounce = ShmTensorpoolControl.ShmPoolAnnounce
const ShmRegionSuperblock = ShmTensorpoolControl.ShmRegionSuperblock
const SlotHeaderMsg = ShmTensorpoolControl.SlotHeader
const TensorHeaderMsg = ShmTensorpoolControl.TensorHeader
const DataSourceAnnounce = ShmTensorpoolControl.DataSourceAnnounce
const DataSourceMeta = ShmTensorpoolControl.DataSourceMeta

const MAX_DIMS::Int = Int(TensorHeaderMsg.maxDims(TensorHeaderMsg.Decoder))

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

const DiscoveryMessageHeader = ShmTensorpoolDiscovery.MessageHeader
const DiscoveryRequest = ShmTensorpoolDiscovery.DiscoveryRequest
const DiscoveryResponse = ShmTensorpoolDiscovery.DiscoveryResponse
const DiscoveryStatus = ShmTensorpoolDiscovery.DiscoveryStatus

const TraceLinkMessageHeader = ShmTensorpoolTraceLink.MessageHeader
const TraceLinkSet = ShmTensorpoolTraceLink.TraceLinkSet

const MESSAGE_HEADER_LEN = Int(MessageHeader.sbe_encoded_length(MessageHeader.Decoder))
const DRIVER_MESSAGE_HEADER_LEN =
    Int(DriverMessageHeader.sbe_encoded_length(DriverMessageHeader.Decoder))
const BRIDGE_MESSAGE_HEADER_LEN =
    Int(BridgeMessageHeader.sbe_encoded_length(BridgeMessageHeader.Decoder))
const DISCOVERY_MESSAGE_HEADER_LEN =
    Int(DiscoveryMessageHeader.sbe_encoded_length(DiscoveryMessageHeader.Decoder))
const TRACELINK_MESSAGE_HEADER_LEN =
    Int(TraceLinkMessageHeader.sbe_encoded_length(TraceLinkMessageHeader.Decoder))
const DISCOVERY_GROUP_HEADER_LEN = 4
const DISCOVERY_VAR_ASCII_HEADER_LEN =
    Int(ShmTensorpoolDiscovery.VarAsciiEncoding.length_encoding_length(
        ShmTensorpoolDiscovery.VarAsciiEncoding.Decoder,
    ))
const FRAME_DESCRIPTOR_LEN = MESSAGE_HEADER_LEN + Int(FrameDescriptor.sbe_block_length(FrameDescriptor.Decoder))
const FRAME_PROGRESS_LEN = MESSAGE_HEADER_LEN + Int(FrameProgress.sbe_block_length(FrameProgress.Decoder))
const QOS_PRODUCER_LEN = MESSAGE_HEADER_LEN + Int(QosProducer.sbe_block_length(QosProducer.Decoder))
const QOS_CONSUMER_LEN = MESSAGE_HEADER_LEN + Int(QosConsumer.sbe_block_length(QosConsumer.Decoder))
const CONSUMER_HELLO_LEN = MESSAGE_HEADER_LEN +
    Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder)) +
    Int(ConsumerHello.descriptorChannel_header_length) +
    Int(ConsumerHello.controlChannel_header_length)
const SLOT_HEADER_BLOCK_LEN = Int(SlotHeaderMsg.sbe_block_length(SlotHeaderMsg.Decoder))
const TENSOR_HEADER_LEN =
    MESSAGE_HEADER_LEN + Int(TensorHeaderMsg.sbe_block_length(TensorHeaderMsg.Decoder))

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
const TEMPLATE_DISCOVERY_REQUEST = DiscoveryRequest.sbe_template_id(DiscoveryRequest.Decoder)
const TEMPLATE_DISCOVERY_RESPONSE = DiscoveryResponse.sbe_template_id(DiscoveryResponse.Decoder)

"""
Return full SBE message length (header + body) for an encoder/decoder.

Arguments:
- `msg`: SBE encoder or decoder instance.

Returns:
- Total encoded length in bytes (including message header).
"""
function sbe_message_length(msg::SBE.AbstractSbeMessage)
    return MESSAGE_HEADER_LEN + sbe_encoded_length(msg)
end
