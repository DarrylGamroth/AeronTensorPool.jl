module Consumer

using ...Core
using ...Core.TPLog
using ...Aeron
using ...Agent
using ...Shm
using ...Control
using ...Driver
using ...DiscoveryClient
using ...Hsm
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
using ..Producer: PayloadPoolConfig

include("types.jl")
include("mapping_lifecycle_types.jl")
include("driver_lifecycle_types.jl")
include("state.jl")
include("callbacks.jl")
include("counters.jl")
include("frames.jl")
include("mapping_lifecycle.jl")
include("driver_lifecycle.jl")
include("mapping.jl")
include("proxy.jl")
include("handlers.jl")
include("init.jl")
include("lifecycle.jl")
include("work.jl")
include("agent.jl")

export ConsumerConfig,
    ConsumerPhase,
    UNMAPPED,
    MAPPED,
    FALLBACK,
    PayloadView,
    payload_view,
    ConsumerState,
    ConsumerCallbacks,
    ConsumerFrameView,
    ConsumerCounters,
    init_consumer,
    init_consumer_from_attach,
    remap_consumer_from_attach!,
    map_from_announce!,
    map_from_attach_response!,
    reset_mappings!,
    handle_shm_pool_announce!,
    validate_mapped_superblocks!,
    consumer_do_work!,
    make_descriptor_assembler,
    make_control_assembler,
    emit_consumer_hello!,
    emit_qos!,
    poll_descriptor!,
    poll_control!,
    poll_qos!,
    maybe_track_gap!,
    validate_strides!,
    try_read_frame!,
    validate_stride,
    ConsumerAgent

end
