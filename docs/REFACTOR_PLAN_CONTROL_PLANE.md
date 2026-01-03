# Control Plane Refactor Plan (Structural)

Goal: move Aeron control-plane primitives into a focused module/directory without changing behavior or introducing transport abstraction.

## Scope
- Keep Aeron as the only control-plane transport.
- Preserve public API and wire behavior.
- Avoid allocations/type instability in hot paths.

## Proposed Layout
- `src/control/`
  - `runtime.jl`: `ControlPlaneRuntime` and any shared Aeron wiring utilities.
  - `proxies.jl`: request/response proxy types and `send_*` helpers.
  - `pollers.jl`: pollers, assemblers, fragment handlers for control messages.
  - `adapters.jl`: handler adapters for agent integration (if needed).
  - `constants.jl` (optional): control-plane buffer sizes or stream defaults.

Note: `proxies.jl`, `pollers.jl`, and `adapters.jl` can be split into subfiles/directories as they grow (e.g., `proxies/attach.jl`, `pollers/driver_responses.jl`). Start with single files to keep include order simple.

## Step 1: Inventory & Grouping
- Identify control-plane primitives currently spread across:
  - `src/client/`
  - `src/driver/`
  - `src/agents/*/` (control-plane runtime usage)
- Classify into runtime, proxies, pollers, adapters, constants.

## Step 2: Move Files (No API Change)
- Create new `src/control/` directory and move files accordingly.
- Update `include(...)` order in `src/AeronTensorPool.jl`.
- Update module references and imports (keep names stable).

## Step 3: Validate Behavior
- Ensure all tests pass without API changes.
- Confirm no allocations added on hot paths (existing allocation tests).

## Step 4: Optional Cleanup
- Reduce cross-module dependency (e.g., avoid `driver` depending on `agents`).
- Keep control-plane types lightweight and type-stable.

## Non-Goals
- No transport abstraction or interface layer in this plan.
- No behavioral changes to attach/keepalive/shutdown flows.

## Risks & Mitigations
- **Risk:** include order or circular references.
  - **Mitigation:** keep control-plane as leaf module; avoid referencing agent state.
- **Risk:** accidental API changes.
  - **Mitigation:** move only; do not rename or change signatures.

## Done Criteria
- Control-plane code lives in `src/control/` and builds.
- Tests pass unchanged.
- Public API remains stable.
