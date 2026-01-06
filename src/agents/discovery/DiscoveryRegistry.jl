module DiscoveryRegistry

using ...Core
using ...Core.TPLog
using ...Aeron
using ...Agent
using ...Shm
using ...Control
using ...Driver
using ...Discovery
using ...Timers
using ...AeronUtils
using ...Clocks
using ...FixedSizeArrays
using ...SBE
using ...StringViews
using ...UnsafeArrays
using ...ShmTensorpoolControl
using ...ShmTensorpoolDriver
using ...ShmTensorpoolBridge
using ...ShmTensorpoolDiscovery
using ..Discovery: AbstractDiscoveryState

include("registry_state.jl")
include("registry_handlers.jl")
include("registry_init.jl")
include("registry_work.jl")
include("registry_agent.jl")

export DiscoveryRegistryState,
    init_discovery_registry,
    discovery_registry_do_work!,
    make_registry_announce_assembler,
    make_registry_metadata_assembler,
    make_request_assembler,
    DiscoveryRegistryAgent

end
