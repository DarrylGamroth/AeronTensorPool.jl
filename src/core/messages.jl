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

@inline function matches_message_schema(header::MessageHeader.Decoder)
    return MessageHeader.schemaId(header) == MessageHeader.sbe_schema_id(MessageHeader.Decoder)
end

@inline function matches_message_schema(header::MessageHeader.Decoder, max_version::UInt16)
    matches_message_schema(header) || return false
    MessageHeader.version(header) <= max_version || return false
    return true
end

@inline function matches_message_header(
    header::MessageHeader.Decoder,
    template_id::UInt16,
    max_version::UInt16,
)
    matches_message_schema(header, max_version) || return false
    MessageHeader.templateId(header) == template_id || return false
    return true
end

@inline function matches_driver_schema(
    header::DriverMessageHeader.Decoder,
    schema_id::UInt16,
    max_version::UInt16,
)
    DriverMessageHeader.schemaId(header) == schema_id || return false
    DriverMessageHeader.version(header) <= max_version || return false
    return true
end

@inline function matches_driver_header(
    header::DriverMessageHeader.Decoder,
    template_id::UInt16,
    schema_id::UInt16,
    max_version::UInt16,
)
    matches_driver_schema(header, schema_id, max_version) || return false
    DriverMessageHeader.templateId(header) == template_id || return false
    return true
end

@inline function matches_discovery_header(
    header::DiscoveryMessageHeader.Decoder,
    template_id::UInt16,
    schema_version::UInt16,
)
    DiscoveryMessageHeader.schemaId(header) ==
    DiscoveryMessageHeader.sbe_schema_id(DiscoveryMessageHeader.Decoder) || return false
    DiscoveryMessageHeader.version(header) == schema_version || return false
    DiscoveryMessageHeader.templateId(header) == template_id || return false
    return true
end

@inline function matches_tracelink_header(
    header::TraceLinkMessageHeader.Decoder,
    template_id::UInt16,
    schema_version::UInt16,
)
    TraceLinkMessageHeader.schemaId(header) ==
    TraceLinkMessageHeader.sbe_schema_id(TraceLinkMessageHeader.Decoder) || return false
    TraceLinkMessageHeader.version(header) == schema_version || return false
    TraceLinkMessageHeader.templateId(header) == template_id || return false
    return true
end


@inline function consumer_hello_var_data_ok(msg::ConsumerHello.Decoder)
    buf = ConsumerHello.sbe_buffer(msg)
    buf_len = length(buf)
    pos = Int(ConsumerHello.sbe_position(msg))
    header_len = Int(ConsumerHello.descriptorChannel_header_length)
    if pos + header_len > buf_len
        return false
    end
    desc_len = Int(ConsumerHello.descriptorChannel_length(msg))
    if pos + header_len + desc_len > buf_len
        return false
    end
    pos = Int(ConsumerHello.sbe_position(msg))
    header_len = Int(ConsumerHello.controlChannel_header_length)
    if pos + header_len > buf_len
        return false
    end
    control_len = Int(ConsumerHello.controlChannel_length(msg))
    if pos + header_len + control_len > buf_len
        return false
    end
    return true
end

@inline function driver_shutdown_request_var_data_ok(msg::ShmDriverShutdownRequest.Decoder)
    buf = ShmDriverShutdownRequest.sbe_buffer(msg)
    buf_len = length(buf)
    pos = Int(ShmDriverShutdownRequest.sbe_position(msg))
    header_len = Int(ShmDriverShutdownRequest.token_header_length)
    if pos + header_len > buf_len
        return false
    end
    token_len = Int(ShmDriverShutdownRequest.token_length(msg))
    if pos + header_len + token_len > buf_len
        return false
    end
    pos = Int(ShmDriverShutdownRequest.sbe_position(msg))
    header_len = Int(ShmDriverShutdownRequest.errorMessage_header_length)
    if pos + header_len > buf_len
        return false
    end
    err_len = Int(ShmDriverShutdownRequest.errorMessage_length(msg))
    if pos + header_len + err_len > buf_len
        return false
    end
    return true
end

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

"""
Populate a ConsumerConfig message encoder.

Arguments:
- `enc`: ConsumerConfig encoder.
- `stream_id`: stream identifier.
- `consumer_id`: consumer identifier.
- `use_shm`: enable SHM usage.
- `mode`: consumer mode.
- `descriptor_stream_id`: descriptor stream id (0 for shared).
- `control_stream_id`: control stream id (0 for shared).
- `payload_fallback_uri`: fallback URI (empty string for none).
- `descriptor_channel`: optional per-consumer descriptor channel.
- `control_channel`: optional per-consumer control channel.

Returns:
- `nothing`.
"""
function encode_consumer_config!(
    enc::ConsumerConfigMsg.Encoder,
    stream_id::UInt32,
    consumer_id::UInt32;
    use_shm::Bool,
    mode::Mode.SbeEnum,
    descriptor_stream_id::UInt32,
    control_stream_id::UInt32,
    payload_fallback_uri::AbstractString,
    descriptor_channel::AbstractString,
    control_channel::AbstractString,
)
    ConsumerConfigMsg.streamId!(enc, stream_id)
    ConsumerConfigMsg.consumerId!(enc, consumer_id)
    ConsumerConfigMsg.useShm!(enc, use_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE)
    ConsumerConfigMsg.mode!(enc, mode)
    ConsumerConfigMsg.descriptorStreamId!(enc, descriptor_stream_id)
    ConsumerConfigMsg.controlStreamId!(enc, control_stream_id)
    ConsumerConfigMsg.payloadFallbackUri!(enc, payload_fallback_uri)
    if isempty(descriptor_channel)
        ConsumerConfigMsg.descriptorChannel!(enc, nothing)
    else
        ConsumerConfigMsg.descriptorChannel!(enc, descriptor_channel)
    end
    if isempty(control_channel)
        ConsumerConfigMsg.controlChannel!(enc, nothing)
    else
        ConsumerConfigMsg.controlChannel!(enc, control_channel)
    end
    return nothing
end

"""
Populate a DataSourceAnnounce encoder from a decoded message.

Arguments:
- `enc`: DataSourceAnnounce encoder.
- `stream_id`: stream identifier for the forwarded announce.
- `msg`: decoded DataSourceAnnounce.

Returns:
- `nothing`.
"""
function encode_metadata_announce!(
    enc::DataSourceAnnounce.Encoder,
    stream_id::UInt32,
    msg::DataSourceAnnounce.Decoder,
)
    name = DataSourceAnnounce.name(msg, StringView)
    summary = DataSourceAnnounce.summary(msg, StringView)
    DataSourceAnnounce.streamId!(enc, stream_id)
    DataSourceAnnounce.producerId!(enc, DataSourceAnnounce.producerId(msg))
    DataSourceAnnounce.epoch!(enc, DataSourceAnnounce.epoch(msg))
    DataSourceAnnounce.metaVersion!(enc, DataSourceAnnounce.metaVersion(msg))
    DataSourceAnnounce.name!(enc, name)
    DataSourceAnnounce.summary!(enc, summary)
    return nothing
end

"""
Populate a DataSourceMeta encoder from a decoded message.

Arguments:
- `enc`: DataSourceMeta encoder.
- `stream_id`: stream identifier for the forwarded meta.
- `msg`: decoded DataSourceMeta.

Returns:
- `nothing`.
"""
function encode_metadata_meta!(
    enc::DataSourceMeta.Encoder,
    stream_id::UInt32,
    msg::DataSourceMeta.Decoder,
)
    DataSourceMeta.streamId!(enc, stream_id)
    DataSourceMeta.metaVersion!(enc, DataSourceMeta.metaVersion(msg))
    DataSourceMeta.timestampNs!(enc, DataSourceMeta.timestampNs(msg))
    attrs = DataSourceMeta.attributes(msg)
    attrs_enc = DataSourceMeta.attributes!(enc, length(attrs))
    for attr in attrs
        entry = DataSourceMeta.Attributes.next!(attrs_enc)
        DataSourceMeta.Attributes.key!(entry, DataSourceMeta.Attributes.key(attr, StringView))
        DataSourceMeta.Attributes.format!(entry, DataSourceMeta.Attributes.format(attr, StringView))
        DataSourceMeta.Attributes.value!(entry, DataSourceMeta.Attributes.value(attr))
    end
    return nothing
end
