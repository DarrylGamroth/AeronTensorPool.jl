module Discovery

using ..Aeron
using ..AeronUtils
using ..Core
using ..Control
using ..ShmTensorpoolDiscovery
using ..Timers
using ..UnsafeArrays
using ..StringViews

include("constants.jl")
include("types.jl")
include("validation.jl")
include("discovery_client.jl")

export DiscoveryClientState,
    DiscoveryResponseSlot,
    DiscoveryResponsePoller,
    DiscoveryConfig,
    DiscoveryRegistryEndpoint,
    DiscoveryRegistryConfig,
    DiscoveryPoolEntry,
    DiscoveryEntry,
    DiscoveryResultView,
    discovery_result_view,
    DISCOVERY_SCHEMA_ID,
    DISCOVERY_MAX_RESULTS_DEFAULT,
    DISCOVERY_MAX_DATASOURCE_NAME_BYTES,
    DISCOVERY_RESPONSE_BUF_BYTES,
    DISCOVERY_INSTANCE_ID_MAX_BYTES,
    DISCOVERY_CONTROL_CHANNEL_MAX_BYTES,
    DISCOVERY_TAG_MAX_BYTES,
    DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
    DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
    DISCOVERY_RESULT_BLOCK_LEN,
    validate_discovery_endpoints,
    init_discovery_client,
    send_discovery_request!,
    discover_streams!,
    poll_discovery_response!,
    wait_for_discovery_response

end
