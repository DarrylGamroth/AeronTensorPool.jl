module Discovery

using ..Core
using ..Aeron
using ..AeronUtils
using ..Timers
using ..UnsafeArrays
using ..StringViews
import ..Core: DiscoveryEntry

include("discovery_client.jl")

export DiscoveryClientState,
    DiscoveryResponseSlot,
    DiscoveryResponsePoller,
    init_discovery_client,
    send_discovery_request!,
    discover_streams!,
    poll_discovery_response!,
    wait_for_discovery_response

end
