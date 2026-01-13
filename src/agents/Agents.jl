module Agents

include("producer/Producer.jl")
include("consumer/Consumer.jl")
include("supervisor/Supervisor.jl")
include("bridge/Bridge.jl")
include("discovery/Discovery.jl")
include("discovery/DiscoveryRegistry.jl")
include("ratelimiter/RateLimiter.jl")

using .Producer: PayloadPoolConfig,
    ProducerConfig,
    SlotClaim,
    ProducerState,
    ProducerCallbacks,
    ProducerConsumerStream,
    ProducerCounters,
    ProducerAgent

using .Consumer: ConsumerConfig,
    ConsumerPhase,
    UNMAPPED,
    MAPPED,
    FALLBACK,
    PayloadView,
    ConsumerState,
    ConsumerCallbacks,
    ConsumerFrameView,
    ConsumerCounters,
    ConsumerAgent

using .Supervisor: SupervisorState,
    SupervisorConfig,
    SupervisorCallbacks,
    ProducerInfo,
    ConsumerInfo,
    SupervisorCounters,
    SupervisorAgent

using .Bridge: BridgeMapping,
    BridgeStreamIdRange,
    BridgeConfig,
    BridgeSenderState,
    BridgeReceiverState,
    BridgeCallbacks,
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

using .RateLimiter: RateLimiterMapping,
    RateLimiterConfig,
    RateLimiterState,
    RateLimiterAgent

using ..Driver: DriverAgent

export Producer,
    Consumer,
    Supervisor,
    Bridge,
    DiscoveryRegistry,
    ProducerState,
    ProducerCallbacks,
    ProducerInfo,
    ProducerConsumerStream,
    PayloadPoolConfig,
    ProducerConfig,
    ProducerAgent,
    ConsumerConfig,
    ConsumerPhase,
    UNMAPPED,
    MAPPED,
    FALLBACK,
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
    ConsumerCallbacks,
    ConsumerInfo,
    ConsumerFrameView,
    SupervisorAgent,
    SupervisorState,
    SupervisorConfig,
    SupervisorCallbacks,
    BridgeSourceInfo,
    BridgeAssembledFrame,
    BridgeSenderState,
    BridgeReceiverState,
    BridgeCallbacks,
    BridgeConfigError,
    BridgeAgent,
    BridgeSystemAgent,
    DiscoveryProviderState,
    DiscoveryRegistryState,
    DiscoveryAgent,
    DiscoveryRegistryAgent,
    RateLimiterMapping,
    RateLimiterConfig,
    RateLimiterState,
    RateLimiterAgent,
    DriverAgent

end
