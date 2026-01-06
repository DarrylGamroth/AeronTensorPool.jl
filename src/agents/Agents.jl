module Agents

using ..Core
using ..Core.TPLog
using ..Aeron
using ..Agent
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
using ..ShmTensorpoolControl
using ..ShmTensorpoolDriver
using ..ShmTensorpoolBridge
using ..ShmTensorpoolDiscovery

include("types.jl")
include("producer/producer.jl")
include("producer/agent.jl")
include("consumer/consumer.jl")
include("consumer/agent.jl")
include("supervisor/supervisor.jl")
include("supervisor/agent.jl")
include("bridge/bridge.jl")
include("bridge/agent.jl")
include("bridge/system_agent.jl")
include("discovery/discovery.jl")
include("discovery/agent.jl")
include("discovery/registry_agent.jl")
include("driver/agent.jl")

export ProducerState,
    ProducerHooks,
    ProducerInfo,
    ProducerConsumerStream,
    PayloadPoolConfig,
    ProducerConfig,
    ProducerAgent,
    ConsumerSettings,
    ConsumerAgent,
    BridgeMapping,
    BridgeStreamIdRange,
    BridgeConfig,
    PayloadView,
    SlotClaim,
    select_pool,
    ProducerCounters,
    ConsumerCounters,
    SupervisorCounters,
    BridgeCounters,
    ConsumerState,
    ConsumerHooks,
    ConsumerInfo,
    ConsumerFrameView,
    SupervisorAgent,
    SupervisorState,
    SupervisorConfig,
    SupervisorHooks,
    BridgeSourceInfo,
    BridgeAssembledFrame,
    BridgeSenderState,
    BridgeReceiverState,
    BridgeHooks,
    BridgeConfigError,
    BridgeAgent,
    BridgeSystemAgent,
    DiscoveryProviderState,
    DiscoveryRegistryState,
    DiscoveryAgent,
    DiscoveryRegistryAgent,
    DriverAgent,
    init_producer,
    init_producer_from_attach,
    init_consumer,
    init_consumer_from_attach,
    init_supervisor,
    remap_consumer_from_attach!,
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
    bridge_apply_source_announce!,
    bridge_rematerialize!,
    bridge_send_frame!,
    bridge_chunk_message_length,
    bridge_publish_progress!,
    bridge_receive_chunk!,
    validate_bridge_config,
    validate_mapped_superblocks!,
    maybe_track_gap!,
    consumer_stream_last_seen_ns,
    entry_expired,
    entry_matches!,
    make_announce_assembler,
    make_metadata_assembler,
    make_request_assembler,
    validate_strides!,
    try_read_frame!,
    validate_stride,
    payload_view

end
