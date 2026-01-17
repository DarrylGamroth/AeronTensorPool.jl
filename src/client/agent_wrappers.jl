"""
Convenience wrappers to use TensorPoolClient for agent init and constructors.
"""

function Driver.init_driver(config::Driver.DriverConfig; client::TensorPoolClient, kwargs...)
    return Driver.init_driver(config; client = client.aeron_client, kwargs...)
end

function Driver.DriverAgent(config::Driver.DriverConfig; client::TensorPoolClient, kwargs...)
    return Driver.DriverAgent(config; client = client.aeron_client, kwargs...)
end

function Agents.Producer.init_producer(
    config::Agents.Producer.ProducerConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Producer.init_producer(config; client = client.aeron_client, kwargs...)
end

function Agents.Producer.ProducerAgent(
    config::Agents.Producer.ProducerConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Producer.ProducerAgent(config; client = client.aeron_client, kwargs...)
end

function Agents.Consumer.init_consumer(
    config::Agents.Consumer.ConsumerConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Consumer.init_consumer(config; client = client.aeron_client, kwargs...)
end

function Agents.Consumer.ConsumerAgent(
    config::Agents.Consumer.ConsumerConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Consumer.ConsumerAgent(config; client = client.aeron_client, kwargs...)
end

function Agents.Supervisor.init_supervisor(
    config::Agents.Supervisor.SupervisorConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Supervisor.init_supervisor(config; client = client.aeron_client, kwargs...)
end

function Agents.Supervisor.SupervisorAgent(
    config::Agents.Supervisor.SupervisorConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Supervisor.SupervisorAgent(config; client = client.aeron_client, kwargs...)
end

function Agents.Bridge.init_bridge_sender(
    consumer_state::Agents.Consumer.ConsumerState,
    config::Agents.Bridge.BridgeConfig,
    mapping::Agents.Bridge.BridgeMapping;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Bridge.init_bridge_sender(
        consumer_state,
        config,
        mapping;
        client = client.aeron_client,
        kwargs...,
    )
end

function Agents.Bridge.init_bridge_receiver(
    config::Agents.Bridge.BridgeConfig,
    mapping::Agents.Bridge.BridgeMapping;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Bridge.init_bridge_receiver(
        config,
        mapping;
        client = client.aeron_client,
        kwargs...,
    )
end

function Agents.Bridge.BridgeAgent(
    config::Agents.Bridge.BridgeConfig,
    mapping::Agents.Bridge.BridgeMapping,
    consumer_config::Agents.Consumer.ConsumerConfig,
    producer_config::Agents.Producer.ProducerConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Bridge.BridgeAgent(
        config,
        mapping,
        consumer_config,
        producer_config;
        client = client.aeron_client,
        kwargs...,
    )
end

function Agents.Bridge.BridgeSystemAgent(
    bridge_config::Agents.Bridge.BridgeConfig,
    mappings::Vector{Agents.Bridge.BridgeMapping},
    consumer_config::Agents.Consumer.ConsumerConfig,
    producer_config::Agents.Producer.ProducerConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Bridge.BridgeSystemAgent(
        bridge_config,
        mappings,
        consumer_config,
        producer_config;
        client = client.aeron_client,
        kwargs...,
    )
end

function Agents.Discovery.init_discovery_provider(
    config::Agents.Discovery.DiscoveryConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Discovery.init_discovery_provider(config; client = client.aeron_client, kwargs...)
end

function Agents.Discovery.DiscoveryAgent(
    config::Agents.Discovery.DiscoveryConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.Discovery.DiscoveryAgent(config; client = client.aeron_client, kwargs...)
end

function Agents.DiscoveryRegistry.init_discovery_registry(
    config::Agents.DiscoveryRegistry.DiscoveryRegistryConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.DiscoveryRegistry.init_discovery_registry(config; client = client.aeron_client, kwargs...)
end

function Agents.DiscoveryRegistry.DiscoveryRegistryAgent(
    config::Agents.DiscoveryRegistry.DiscoveryRegistryConfig;
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.DiscoveryRegistry.DiscoveryRegistryAgent(config; client = client.aeron_client, kwargs...)
end

function Agents.RateLimiter.init_rate_limiter(
    config::Agents.RateLimiter.RateLimiterConfig,
    mappings::Vector{Agents.RateLimiter.RateLimiterMapping};
    client::TensorPoolClient,
    kwargs...,
)
    return Agents.RateLimiter.init_rate_limiter(
        config,
        mappings;
        client = client.aeron_client,
        kwargs...,
    )
end
