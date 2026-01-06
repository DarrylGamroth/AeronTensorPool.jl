module Agents

module Producer
using ...Aeron
using ...Agent
using ...Core
using ...AgentLib
using ...AeronUtils
include("producer_agent.jl")
end

module Consumer
using ...Aeron
using ...Agent
using ...Core
using ...AgentLib
using ...AeronUtils
include("consumer_agent.jl")
end

module Supervisor
using ...Aeron
using ...Agent
using ...Core
using ...AgentLib
using ...AeronUtils
include("supervisor_agent.jl")
end

module Driver
using ...Aeron
using ...Agent
using ...Core
using ...Driver
using ...AeronUtils
include("driver_agent.jl")
end

module Discovery
using ...Aeron
using ...Agent
using ...Core
using ...AgentLib
using ...AeronUtils
include("discovery_agent.jl")
end

module DiscoveryRegistry
using ...Aeron
using ...Agent
using ...Core
using ...AgentLib
using ...AeronUtils
include("discovery_registry_agent.jl")
end

module Bridge
using ...Aeron
using ...Agent
using ...Core
using ...AgentLib
using ...AeronUtils
include("bridge_agent.jl")
end

module BridgeSystem
using ...Aeron
using ...Agent
using ...Core
using ...AgentLib
using ...AeronUtils
include("bridge_system_agent.jl")
end

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
