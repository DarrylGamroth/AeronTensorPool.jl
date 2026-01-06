module AgentLib

using ..Core
using ..Core.TPLog
using ..Aeron
using ..Shm
using ..Control
using ..Driver
using ..Discovery
using ..Timers
using ..AeronUtils
using ..Clocks
using ..FixedSizeArrays
using ..SBE
using ..StringViews
using ..UnsafeArrays
using ..ShmTensorpoolDiscovery

include("producer/producer.jl")
include("consumer/consumer.jl")
include("supervisor/supervisor.jl")
include("bridge/bridge.jl")
include("discovery/discovery.jl")

export ProducerState,
    ProducerHooks,
    ProducerInfo,
    ConsumerState,
    ConsumerHooks,
    ConsumerInfo,
    ConsumerFrameView,
    SupervisorState,
    SupervisorConfig,
    SupervisorHooks,
    BridgeSourceInfo,
    BridgeAssembledFrame,
    BridgeSenderState,
    BridgeReceiverState,
    BridgeHooks,
    DiscoveryProviderState,
    DiscoveryRegistryState,
    init_producer,
    init_producer_from_attach,
    init_consumer,
    init_consumer_from_attach,
    init_supervisor,
    init_bridge_sender,
    init_bridge_receiver,
    init_discovery_provider,
    init_discovery_registry,
    producer_config_from_attach,
    map_from_announce!,
    map_from_attach_response!,
    reset_mappings!,
    producer_do_work!,
    consumer_do_work!,
    supervisor_do_work!,
    bridge_sender_do_work!,
    bridge_receiver_do_work!,
    discovery_do_work!,
    discovery_registry_do_work!,
    make_control_assembler,
    make_descriptor_assembler,
    make_qos_assembler,
    emit_announce!,
    emit_consumer_config!,
    emit_consumer_hello!,
    emit_progress_complete!,
    emit_qos!,
    handle_consumer_hello!,
    handle_shm_pool_announce!,
    poll_control!,
    poll_descriptor!,
    poll_qos!,
    offer_frame!,
    commit_slot!,
    try_claim_slot!,
    with_claimed_slot!,
    payload_pool_config,
    republish_descriptor!,
    bridge_forward_announce!,
    bridge_rematerialize!,
    bridge_send_frame!,
    try_read_frame!,
    validate_stride,
    validate_bridge_config,
    validate_discovery_endpoints

end
