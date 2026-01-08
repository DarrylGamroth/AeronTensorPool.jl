module Agents

include("agent_group.jl")
include("producer/Producer.jl")
include("consumer/Consumer.jl")
include("supervisor/Supervisor.jl")
include("bridge/Bridge.jl")
include("discovery/Discovery.jl")
include("discovery/DiscoveryRegistry.jl")

using .Producer: PayloadPoolConfig,
    ProducerConfig,
    SlotClaim,
    ProducerState,
    ProducerHooks,
    ProducerConsumerStream,
    ProducerCounters,
    ProducerAgent

using .Consumer: ConsumerConfig,
    PayloadView,
    ConsumerState,
    ConsumerHooks,
    ConsumerFrameView,
    ConsumerCounters,
    ConsumerAgent

using .Supervisor: SupervisorState,
    SupervisorConfig,
    SupervisorHooks,
    ProducerInfo,
    ConsumerInfo,
    SupervisorCounters,
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
    BridgeAgent,
    BridgeSystemAgent

using .Discovery: DiscoveryProviderState,
    DiscoveryAgent

using .DiscoveryRegistry: DiscoveryRegistryState,
    DiscoveryRegistryAgent

using .AgentGroups: AgentGroup

using ..Driver: DriverAgent

export Producer,
    Consumer,
    Supervisor,
    Bridge,
    DiscoveryRegistry,
    AgentGroup,
    ProducerState,
    ProducerHooks,
    ProducerInfo,
    ProducerConsumerStream,
    PayloadPoolConfig,
    ProducerConfig,
    ProducerAgent,
    ConsumerConfig,
    ConsumerAgent,
    BridgeMapping,
    BridgeStreamIdRange,
    BridgeConfig,
    PayloadView,
    SlotClaim,
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
    DriverAgent

end
