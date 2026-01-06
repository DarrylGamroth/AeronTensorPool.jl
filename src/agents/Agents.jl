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

include("producer/Producer.jl")
include("consumer/Consumer.jl")
include("supervisor/Supervisor.jl")
include("bridge/Bridge.jl")
include("discovery/Discovery.jl")
include("discovery/DiscoveryRegistry.jl")

using .Producer: PayloadPoolConfig,
    ProducerConfig,
    SlotClaim,
    select_pool,
    ProducerState,
    ProducerHooks,
    ProducerConsumerStream,
    ProducerCounters,
    init_producer,
    init_producer_from_attach,
    producer_config_from_attach,
    producer_do_work!,
    emit_announce!,
    emit_progress_complete!,
    offer_frame!,
    commit_slot!,
    try_claim_slot!,
    with_claimed_slot!,
    payload_pool_config,
    consumer_stream_last_seen_ns,
    ProducerAgent

using .Consumer: ConsumerSettings,
    PayloadView,
    payload_view,
    ConsumerState,
    ConsumerHooks,
    ConsumerFrameView,
    ConsumerCounters,
    init_consumer,
    init_consumer_from_attach,
    remap_consumer_from_attach!,
    map_from_announce!,
    map_from_attach_response!,
    reset_mappings!,
    validate_mapped_superblocks!,
    consumer_do_work!,
    make_descriptor_assembler,
    emit_consumer_hello!,
    poll_descriptor!,
    maybe_track_gap!,
    validate_strides!,
    try_read_frame!,
    validate_stride,
    ConsumerAgent

using .Supervisor: SupervisorState,
    SupervisorConfig,
    SupervisorHooks,
    ProducerInfo,
    ConsumerInfo,
    SupervisorCounters,
    init_supervisor,
    supervisor_do_work!,
    handle_qos_producer!,
    handle_qos_consumer!,
    SupervisorAgent

using .Bridge: BridgeMapping,
    BridgeStreamIdRange,
    BridgeConfig,
    BridgeSenderState,
    BridgeReceiverState,
    BridgeHooks,
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

using .Discovery: DiscoveryProviderState,
    init_discovery_provider,
    discovery_do_work!,
    make_request_assembler,
    make_announce_assembler,
    make_metadata_assembler,
    entry_expired,
    entry_matches!,
    DiscoveryAgent

using .DiscoveryRegistry: DiscoveryRegistryState,
    init_discovery_registry,
    discovery_registry_do_work!,
    DiscoveryRegistryAgent

using ..Driver: DriverAgent

function make_control_assembler(state::ProducerState; kwargs...)
    return Producer.make_control_assembler(state; kwargs...)
end

function make_control_assembler(state::ConsumerState; kwargs...)
    return Consumer.make_control_assembler(state; kwargs...)
end

function make_control_assembler(state::SupervisorState; kwargs...)
    return Supervisor.make_control_assembler(state; kwargs...)
end

function make_qos_assembler(state::ProducerState; kwargs...)
    return Producer.make_qos_assembler(state; kwargs...)
end

function make_qos_assembler(state::SupervisorState; kwargs...)
    return Supervisor.make_qos_assembler(state; kwargs...)
end

@inline function poll_control!(
    state::ProducerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Producer.poll_control!(state, assembler, fragment_limit)
end

@inline function poll_control!(
    state::ConsumerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Consumer.poll_control!(state, assembler, fragment_limit)
end

@inline function poll_control!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Supervisor.poll_control!(state, assembler, fragment_limit)
end

@inline function poll_qos!(
    state::ProducerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Producer.poll_qos!(state, assembler, fragment_limit)
end

@inline function poll_qos!(
    state::ConsumerState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Consumer.poll_qos!(state, assembler, fragment_limit)
end

@inline function poll_qos!(
    state::SupervisorState,
    assembler::Aeron.FragmentAssembler,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    return Supervisor.poll_qos!(state, assembler, fragment_limit)
end

function emit_qos!(state::ProducerState)
    return Producer.emit_qos!(state)
end

function emit_qos!(state::ConsumerState)
    return Consumer.emit_qos!(state)
end

function emit_consumer_config!(state::ProducerState, consumer_id::UInt32; kwargs...)
    return Producer.emit_consumer_config!(state, consumer_id; kwargs...)
end

function emit_consumer_config!(state::SupervisorState, consumer_id::UInt32; kwargs...)
    return Supervisor.emit_consumer_config!(state, consumer_id; kwargs...)
end

function handle_shm_pool_announce!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    return Consumer.handle_shm_pool_announce!(state, msg)
end

function handle_shm_pool_announce!(state::SupervisorState, msg::ShmPoolAnnounce.Decoder)
    return Supervisor.handle_shm_pool_announce!(state, msg)
end

function handle_consumer_hello!(state::ProducerState, msg::ConsumerHello.Decoder)
    return Producer.handle_consumer_hello!(state, msg)
end

function handle_consumer_hello!(state::SupervisorState, msg::ConsumerHello.Decoder)
    return Supervisor.handle_consumer_hello!(state, msg)
end

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
