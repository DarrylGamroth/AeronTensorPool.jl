module Discovery

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

include("state.jl")
include("handlers.jl")
include("init.jl")
include("work.jl")
include("agent.jl")

export DiscoveryProviderState,
    init_discovery_provider,
    discovery_do_work!,
    make_request_assembler,
    make_announce_assembler,
    make_metadata_assembler,
    entry_expired,
    entry_matches!,
    DiscoveryAgent

end
