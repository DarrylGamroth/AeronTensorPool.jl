# Module Cleanup Plan

Goal: resolve naming/ownership ambiguity introduced by module refactor and align file layout with module boundaries.

## Scope
- Clarify `Core` vs agent runtime roles.
- Make discovery naming explicit.
- Remove redundant `driver.jl` wrapper if present.
- Normalize function names now that modules exist (e.g., `poll_timers!` → `poll!`).
- Make `src/agents` follow “one module per file + central include file”.

## Phase 0: Inventory
- [x] Identify which symbols are exported by `Core` vs agent runtime module.
- [x] Inventory discovery client/registry helpers and decide split.
- [x] Check `src/driver/driver.jl` for redundancy.

## Phase 1: Core vs Agents
- [x] Move agent runtime trees from `src/core/{producer,consumer,supervisor,bridge,discovery}` into `src/agents/`.
- [x] Rename `src/core/AgentLib.jl` to `src/agents/Agents.jl` and make it the agent runtime module root.
- [x] Keep `src/core/Core.jl` as the shared types/constants/utilities module root.
- [x] Ensure `AeronTensorPool` re-exports only the intended public API (no changes required).

## Phase 2: Discovery Naming
- [x] Keep `src/discovery/Discovery.jl` and module name `Discovery` as-is.
- [x] If needed, split internal files but keep `Discovery.jl` as the module root and public entry point (no split required).

## Phase 3: Driver Wrapper Cleanup
- [x] Remove `src/driver/driver.jl` if it is only a passthrough to `Driver.jl`.
- [x] Standardize on `Driver.jl` as the module root (file name matches module).

## Phase 4: Function Naming (Namespaced API)
- [x] Rename module-scoped helpers to short names where safe:
  - `Timers.poll_timers!` → `Timers.poll!`
  - `Control.poll_control!` → `Control.poll!` (no Control helper exists currently)
- [x] Do not add compatibility exports; treat renames as breaking changes and update all call sites.
- [x] Review “init_*” functions that are public and decide whether they should be external constructors (kept as-is for now).

## Phase 5: Agents Layout
- [x] Move each `src/agents/*_agent.jl` wrapper into its agent directory as `agent.jl`.
- [x] Remove `src/agents/AgentWrappers.jl`.
- [x] Update `src/agents/Agents.jl` to include per-agent `agent.jl` files.
- [x] Update `src/AeronTensorPool.jl` to stop including/using `AgentWrappers.jl`.
- [x] Ensure exports are unchanged and all call sites still resolve.

## Phase 6: Validation
- [x] Run full tests.
- [x] Run benchmarks.
- [x] Fix any export/load-order regressions.

## Notes
- Keep module roots aligned with filename casing (`Driver.jl`, `DiscoveryClient.jl`, etc.).
- Prefer minimal re-exports at top-level to avoid name pollution.
