# Naming Consistency Report

This report reviews naming where two different terms represent the same concept or lifecycle, with emphasis on `Config` vs `Settings`.

## Findings

1) Consumer configuration naming diverges
- `ConsumerConfig` is the local configuration type for consumers.
- `ProducerConfig`, `SupervisorConfig`, `DriverConfig`, `BridgeConfig`, `DiscoveryConfig`, and `DiscoveryRegistryConfig` all use `Config`.
- `ConsumerConfigMsg` is the SBE message type, and `apply_consumer_config!` mutates `ConsumerConfig`.
- Result: the consumer uses `Settings` while every other role uses `Config`, but they all represent configuration objects.

2) Wrapper configs use different labels
- `SystemConfig` aggregates `ProducerConfig`, `ConsumerConfig`, `SupervisorConfig`.
- `BridgeSystemConfig` aggregates `BridgeConfig` and mappings.
- Result: aggregation naming is consistent but embedded consumer type still diverges.

3) Config vs state naming is consistent but mixed for the consumer
- `ConsumerState` stores `config::ConsumerConfig`.
- `ProducerState` stores `config::ProducerConfig` and `SupervisorState` stores `config::SupervisorConfig`.
- Result: only the consumer uses a different config name inside state.

4) Message vs local config naming is almost consistent
- `ConsumerConfigMsg` clearly indicates a message, and `ConsumerConfig` is the local config.
- The consumer now follows the same `*Config` naming pattern as other roles.

## Examples (paths)
- Consumer config type: `src/agents/consumer/types.jl`
- Producer config type: `src/agents/producer/types.jl`
- Driver config type: `src/agents/driver/config.jl`
- System config aggregate: `src/config/config_loader.jl`
- Consumer config message: `src/core/messages.jl`

## Recommendation

Pick one term for role configuration types and use it across all roles. Two viable choices:

Option A (preferred for consistency): use `Config` for all role configuration types.
- Rename `ConsumerConfig` -> `ConsumerConfig`.
- Keep message type as `ConsumerConfigMsg` to avoid name collision.
- Update references in config loader, state structs, and examples.

Option B (preferred for mutability signaling): use `Settings` for all role configuration types.
- Rename `ProducerConfig` -> `ProducerSettings`, `SupervisorConfig` -> `SupervisorSettings`, etc.
- Update config loader and state structs accordingly.
- More churn because many types already use `Config`.

Given the rest of the codebase already uses `Config`, Option A is the minimal-change and clearest.

## Other Naming Pairs to Watch

These are not direct conflicts, but should be kept consistent as the API evolves:
- `DriverPolicyConfig` vs `DriverConfig`: policy fields live in config types; the naming is acceptable but should be documented.
- `DiscoveryConfig` vs `DiscoveryRegistryConfig`: clear suffixing; keep consistent if new discovery types are added.
- `BridgeSystemConfig` vs `SystemConfig`: both are aggregate configs; consider a shared naming pattern if more system-level configs are added.
