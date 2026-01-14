const DISCOVERY_SCHEMA_ID = UInt16(
    ShmTensorpoolDiscovery.DiscoveryRequest.sbe_schema_id(
        ShmTensorpoolDiscovery.DiscoveryRequest.Decoder,
    ),
)
const DISCOVERY_MAX_RESULTS_DEFAULT = UInt32(1000)
const DISCOVERY_MAX_DATASOURCE_NAME_BYTES = UInt32(256)
const DISCOVERY_RESPONSE_BUF_BYTES = 65536
const DISCOVERY_INSTANCE_ID_MAX_BYTES = UInt32(128)
const DISCOVERY_CONTROL_CHANNEL_MAX_BYTES = UInt32(1024)
const DISCOVERY_TAG_MAX_BYTES = UInt32(64)
const DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT = UInt16(16)
const DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT = UInt16(16)
const DISCOVERY_RESULT_BLOCK_LEN = ShmTensorpoolDiscovery.DiscoveryResponse.Results.sbe_block_length(
    ShmTensorpoolDiscovery.DiscoveryResponse.Results.Encoder,
)
