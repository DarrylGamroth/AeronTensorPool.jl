module AgentWrappers

include("producer_agent.jl")
include("consumer_agent.jl")
include("supervisor_agent.jl")
include("driver_agent.jl")
include("discovery_agent.jl")
include("discovery_registry_agent.jl")
include("bridge_agent.jl")
include("bridge_system_agent.jl")

const ProducerAgent = Producer.ProducerAgent
const ConsumerAgent = Consumer.ConsumerAgent
const SupervisorAgent = Supervisor.SupervisorAgent
const DriverAgent = Driver.DriverAgent
const DiscoveryAgent = Discovery.DiscoveryAgent
const DiscoveryRegistryAgent = DiscoveryRegistry.DiscoveryRegistryAgent
const BridgeAgent = Bridge.BridgeAgent
const BridgeSystemAgent = BridgeSystem.BridgeSystemAgent

export ProducerAgent,
    ConsumerAgent,
    SupervisorAgent,
    DriverAgent,
    DiscoveryAgent,
    DiscoveryRegistryAgent,
    BridgeAgent,
    BridgeSystemAgent

end
