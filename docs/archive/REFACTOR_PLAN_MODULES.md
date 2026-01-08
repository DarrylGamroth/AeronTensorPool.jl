# Module Refactor Plan (Agents as Modules)

Goal: Organize the codebase into clearer layers:
- Move shared “library” code out of `src/agents/` into `src/core/` (or `src/common/`).
- Keep concrete agent implementations under `src/agents/`.
- Wrap each concrete agent in its own module.

## Principles
- Keep a single top-level `AeronTensorPool` module that re-exports the public API.
- Move shared library code out of `src/agents/` into `src/core/`, preserving the current directory organization (e.g., `adapters/`, `pollers/`, `proxies/`, `handlers/`).
- Wrap concrete agent implementations in standalone modules (one per agent).
- Avoid circular dependencies by keeping shared types in `src/core/` and only `include` shared code from each agent module.
- Preserve file names and paths where possible; only add module wrappers and minimal re-exports.
- Keep tests and benchmarks using the existing API (no test changes unless necessary).

## Proposed Module Layout
```
src/
  AeronTensorPool.jl
  apps/
    TpDriverApp.jl
    TpToolApp.jl
  core/
    constants.jl
    errors.jl
    fixed_string.jl
    logging.jl
    messages.jl
    types.jl
    validation.jl
    (agent runtime moved under src/agents/)
    bridge/
    consumer/
    discovery/
    producer/
    supervisor/
  aeron/
    aeron_utils.jl
    counters.jl
  shm/
    backend.jl
    linux.jl
    paths.jl
    seqlock.jl
    slots.jl
    superblock.jl
    uri.jl
  timers/
    polled_timer.jl
  control/
    pollers.jl
    proxies.jl
    runtime.jl
  driver/
    config.jl
    encoders.jl
    handlers.jl
    inspect.jl
    lease_lifecycle.jl
    leases.jl
    lifecycle_handlers.jl
    lifecycle.jl
    metrics.jl
    registry.jl
    runtime.jl
    state.jl
    streams.jl
  client/
    attach.jl
    context.jl
    discovery.jl
    handles.jl
    discovery_client.jl
    driver_client.jl
  discovery/
    (discovery library helpers)
  agents/
    Agents.jl
    AgentWrappers.jl
    producer/
    consumer/
    supervisor/
    bridge/
    discovery/
    producer_agent.jl
    consumer_agent.jl
    supervisor_agent.jl
    driver_agent.jl
    discovery_agent.jl
    bridge_agent.jl
  gen/
    ShmTensorpoolBridge.jl
    ShmTensorpoolControl.jl
    ShmTensorpoolDiscovery.jl
    ShmTensorpoolDriver.jl
```

## Proposed Module Map (name → files)
- `AeronTensorPool`: top-level re-exports, includes submodules in a fixed order.
- `AeronTensorPool.Core`: `src/core/*.jl` (foundational types/constants)
- `AeronTensorPool.Agents`: `src/agents/Agents.jl` + `src/agents/{producer,consumer,bridge,discovery,supervisor}/*` (agent runtime)
- `AeronTensorPool.AgentWrappers`: `src/agents/AgentWrappers.jl` + `src/agents/*_agent.jl`
- `AeronTensorPool.AeronUtils`: `src/aeron/*.jl` (avoid name clash with Aeron.jl)
- `AeronTensorPool.Shm`: `src/shm/*.jl`
- `AeronTensorPool.Timers`: `src/timers/*.jl`
- `AeronTensorPool.Control`: `src/control/*.jl`
- `AeronTensorPool.Driver`: `src/agents/driver/*.jl`
- `AeronTensorPool.Client`: `src/client/*.jl`
- `AeronTensorPool.Discovery`: `src/discovery/*.jl`
- `AeronTensorPool.AgentWrappers.Producer`: `src/agents/producer_agent.jl` (uses `Agents` runtime)
- `AeronTensorPool.AgentWrappers.Consumer`: `src/agents/consumer_agent.jl`
- `AeronTensorPool.AgentWrappers.Supervisor`: `src/agents/supervisor_agent.jl`
- `AeronTensorPool.AgentWrappers.Driver`: `src/agents/driver_agent.jl`
- `AeronTensorPool.AgentWrappers.Discovery`: `src/agents/discovery_agent.jl`
- `AeronTensorPool.AgentWrappers.Bridge`: `src/agents/bridge_agent.jl`
- `AeronTensorPool.Apps.Tool`: `src/apps/TpToolApp.jl`
- `AeronTensorPool.Apps.Driver`: `src/apps/TpDriverApp.jl`

## Proposed Tree (based on current repo)
```
src/
  AeronTensorPool.jl
  aeron/
    aeron_utils.jl
    counters.jl
    AeronUtils.jl
  client/
    attach.jl
    context.jl
    discovery.jl
    handles.jl
    driver_client.jl
    Client.jl
  config/
    config_loader.jl
  control/
    pollers.jl
    proxies.jl
    runtime.jl
    Control.jl
  core/
    constants.jl
    errors.jl
    fixed_string.jl
    logging.jl
    messages.jl
    types.jl
    validation.jl
    Core.jl
  agents/
    Agents.jl
    AgentWrappers.jl
    bridge/
      adapters.jl
      assembly.jl
      callbacks.jl
      proxy.jl
      receiver.jl
      sender.jl
      state.jl
    consumer/
      consumer.jl
      frames.jl
      handlers.jl
      callbacks.jl
      init.jl
      lifecycle.jl
      mapping.jl
      proxy.jl
      state.jl
      work.jl
    discovery/
      discovery.jl
      handlers.jl
      init.jl
      registry_handlers.jl
      registry_init.jl
      registry_state.jl
      registry_work.jl
      state.jl
      work.jl
    producer/
      frames.jl
      handlers.jl
      callbacks.jl
      init.jl
      lifecycle.jl
      producer.jl
      proxy.jl
      shm.jl
      state.jl
      work.jl
    supervisor/
      handlers.jl
      callbacks.jl
      init.jl
      state.jl
      supervisor.jl
      work.jl
    producer_agent.jl
    consumer_agent.jl
    supervisor_agent.jl
    driver_agent.jl
    discovery_agent.jl
    discovery_registry_agent.jl
    bridge_agent.jl
    bridge_system_agent.jl
  discovery/
    discovery_client.jl
    Discovery.jl
  driver/
    config.jl
    driver.jl
    encoders.jl
    handlers.jl
    inspect.jl
    lease_lifecycle.jl
    leases.jl
    lifecycle_handlers.jl
    lifecycle.jl
    metrics.jl
    registry.jl
    runtime.jl
    state.jl
    streams.jl
    Driver.jl
  gen/
    ShmTensorpoolBridge.jl
    ShmTensorpoolControl.jl
    ShmTensorpoolDiscovery.jl
    ShmTensorpoolDriver.jl
  shm/
    backend.jl
    linux.jl
    paths.jl
    seqlock.jl
    slots.jl
    superblock.jl
    uri.jl
    Shm.jl
  timers/
    polled_timer.jl
    Timers.jl
  apps/
    TpDriverApp.jl
    TpToolApp.jl
    Apps.jl
  agents/
    producer_agent.jl
    consumer_agent.jl
    supervisor_agent.jl
    driver_agent.jl
    discovery_agent.jl
    bridge_agent.jl
    discovery_registry_agent.jl
    bridge_system_agent.jl
    Agents.jl
```

Each agent module lives in a single file under `src/agents/` (e.g., `producer_agent.jl`, `consumer_agent.jl`, etc.). Shared library code is moved out of `src/agents/` into `src/core/` and is included or imported by the agent modules as needed.

## Actionable Checklist (Minimal-Risk Order)
Phase 0: Inventory and API Freeze
- [x] Record current public API exports in `src/AeronTensorPool.jl`.
- [ ] Identify agent-owned types/functions for each agent and mark “public” vs “internal.”
- [x] Confirm which directories map to modules (`core`, `aeron`, `shm`, `timers`, `control`, `driver`, `client`, `discovery`, `agents`, `apps`).

Phase 1: Module Wrappers (No Behavior Change)
- [x] Wrap each directory as a module (`Core`, `Agents`, `AgentWrappers`, `AeronUtils`, `Shm`, `Timers`, `Control`, `Driver`, `Client`, `Discovery`, `Apps`).
- [x] Wrap each `src/agents/*_agent.jl` file in its own agent module.
- [x] Add explicit `export` lists in each agent module.
- [x] Update `src/AeronTensorPool.jl` to `include` the agent modules and re-export symbols.
- [x] Keep logic unchanged (file moves allowed for module boundaries).

Phase 2: Module Boundary Cleanup
- [x] Move shared library directories from `src/agents/` into `src/core/` (preserving structure).
- [x] Update unqualified references to use explicit module names.
- [x] Ensure no agent module reaches into another agent module (bridge is the only exception by design).

Phase 3: Validation
- [x] Run full tests.
- [ ] Run benchmarks to confirm no regressions.
- [x] Fix load-order or import issues.

## Phase 1: Introduce Module Wrappers (No Behavior Change)
- Move shared library code out of `src/agents/` into `src/core/` while preserving subdirectories.
- Keep agent definitions in `src/agents/*_agent.jl` and wrap each file in its own module:
  - `module Producer` in `src/agents/producer_agent.jl` (and similarly for other agents).
  - Move existing includes into module body and add `export` for agent types.
- Update `src/AeronTensorPool.jl` to `include` the new module files and re-export the agent symbols.

## Phase 2: Relabel Shared Code as Core
- Move shared library files out of `src/agents/` into `src/core/`, keeping the same subdirectory structure.
- Update include paths in module wrappers and `src/AeronTensorPool.jl`.
- Update any relative includes in tests/benchmarks if they refer to file paths directly.

## Phase 3: Shared Code Extraction
- Consolidate shared utilities under `src/core/`.
- Update `include` paths and imports in agent modules.
- Ensure no agent module includes another agent module directly.

## Phase 4: Logging and Namespace Cleanup
- Add optional `AeronTensorPool.Logging` helpers (or similar) for targeted debug.
- Replace raw `@info/@debug` uses with `@tp_info/@tp_debug` where helpful.
- Ensure logging symbols are re-exported at top-level if used by callers.

## Phase 5: Public API Consistency Pass
- Ensure top-level exports remain unchanged (or update docs if any changes are required).
- Update documentation references to new module namespaces if exposed.

## Phase 6: Test & Benchmark Validation
- Run full tests and benchmarks.
- Fix any load-order or include path issues.
- Ensure no performance regressions from module boundaries.

## Risks / Considerations
- Load order: module wrappers must include shared code before agent logic.
- Cycles: keep shared code in `src/shared/` to avoid agent ↔ agent dependencies.
- Longer type names: decide whether to re-export short aliases in `AeronTensorPool`.
- Documentation: update any mention of file paths if moved.

## Coupling Summary
- High intra-agent coupling: each agent’s `state/handlers/work` files form a tight unit and should be moved together.
- Limited cross-agent coupling:
  - Bridge depends on consumer/producer runtime types (`ConsumerState`, `ProducerState`) for sender/receiver and in `bridge_system_agent.jl`.
- Shared library coupling: agents depend heavily on `core/`, `shm/`, `driver/`, and `control/` helpers.

Recommendation: keep the cross-agent coupling as-is for now. It is localized to the bridge composition layer and does not warrant a redesign unless you want to formally decouple bridge from concrete producer/consumer states (which would add abstraction complexity).

## Open Decisions
- Whether to expose agent modules publicly (e.g., `AeronTensorPool.Producer`) or keep them internal and only export types.
- Whether to split non-agent subsystems (e.g., discovery, bridge, driver client) into their own modules as well.
