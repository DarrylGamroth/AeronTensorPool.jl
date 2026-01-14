module Bridge

using ...Core
using ...Core.TPLog
using ...Aeron
using ...Agent
using ...Shm
using ...Control
using ...Driver
using ...DiscoveryClient
using ...Timers
using ...AeronUtils
using ...Clocks
using ...Hsm
using CRC32c
using ...FixedSizeArrays
using ...SBE
using ...StringViews
using ...UnsafeArrays
using ...ShmTensorpoolControl
using ...ShmTensorpoolDriver
using ...ShmTensorpoolBridge
using ...ShmTensorpoolDiscovery
import ..Producer
import ..Consumer
using ..Producer: PayloadPoolConfig,
    ProducerConfig,
    ProducerState,
    SlotClaim,
    select_pool,
    producer_driver_active,
    try_claim_slot!,
    encode_frame_descriptor!,
    publish_descriptor_to_consumers!
using ..Consumer: ConsumerConfig, ConsumerState

include("types.jl")
include("config.jl")
include("errors.jl")
include("counters.jl")
include("assembly_lifecycle_types.jl")
include("state.jl")
include("callbacks.jl")
include("adapters.jl")
include("assembly.jl")
include("assembly_lifecycle.jl")
include("sender.jl")
include("receiver.jl")
include("proxy.jl")
include("validation.jl")
include("agent.jl")
include("system_agent.jl")

export BridgeMapping,
    BridgeStreamIdRange,
    BridgeConfig,
    load_bridge_config,
    BridgeSenderState,
    BridgeReceiverState,
    BridgeCallbacks,
    BridgeAssembledFrame,
    BridgeSourceInfo,
    BridgeCounters,
    BridgeConfigError,
    init_bridge_sender,
    init_bridge_receiver,
    bridge_sender_do_work!,
    bridge_receiver_do_work!,
    bridge_forward_announce!,
    bridge_apply_source_announce!,
    bridge_rematerialize!,
    bridge_send_frame!,
    bridge_chunk_message_length,
    bridge_publish_progress!,
    bridge_receive_chunk!,
    validate_bridge_config,
    BridgeAgent,
    BridgeSystemAgent

end
