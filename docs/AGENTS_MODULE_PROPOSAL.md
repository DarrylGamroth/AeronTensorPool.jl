## Proposal: High-Level Agents Module

This document outlines options for the `AeronTensorPool.Agents` module now that each agent has its own module root (`Producer`, `Consumer`, `Supervisor`, `Bridge`, `Discovery`, `DiscoveryRegistry`, plus `Driver`).

### Goals
- Keep agent entrypoints discoverable for users.
- Avoid ambiguous exports and accidental method name collisions.
- Preserve ergonomic helpers for common agent workflows.

### Option A: Keep `Agents` as the default user-facing facade (current)
- `Agents` re-exports common types and helpers across agent modules.
- `Agents` provides wrapper methods (e.g., `make_control_assembler`, `poll_control!`, `emit_consumer_config!`) that dispatch based on state type.

Pros
- Easy import: `using AeronTensorPool.Agents`.
- Minimal user code changes; backwards-compatible naming.
- Centralized dispatch for cross-agent helpers.

Cons
- Name collisions are easy (e.g., multiple `poll_control!`/`emit_qos!` implementations).
- Requires carefully curated wrapper methods to avoid ambiguity or missing exports.
- Adds maintenance overhead whenever a per-agent API changes.

### Option B: Narrow `Agents` to only agent modules + minimal shared types
- `Agents` exports only the module roots and agent wrapper types.
- Users explicitly call `Producer.make_control_assembler`, `Consumer.emit_qos!`, etc.

Pros
- Clear ownership; no ambiguity about which function you’re calling.
- Less glue code; fewer wrapper methods to maintain.
- More explicit in documentation and examples.

Cons
- Slightly more verbose user code.
- Requires updates to existing tests/examples that rely on `Agents` re-exports.

### Option C: Dual-layer approach (recommended)
- Keep `Agents` as a minimal facade:
  - Export agent modules (`Producer`, `Consumer`, `Supervisor`, `Bridge`, `Discovery`, `DiscoveryRegistry`, `Driver`).
  - Export agent wrapper types (`ProducerAgent`, etc.).
  - Export shared data types that are truly cross-cutting (e.g., `PayloadPoolConfig`, `BridgeMapping`).
- Do NOT export per-agent operational helpers (`poll_*`, `emit_*`, `make_*`); keep these namespaced.

Pros
- Retains easy discovery via `Agents`.
- Avoids method-name collisions and wrapper maintenance.
- Encourages explicit calls in examples and user code.

Cons
- Requires a controlled migration of examples/tests.
- Slightly more typing for users.

### Recommendation
Adopt Option C. It preserves discoverability while eliminating most of the cross-agent helper collisions that have already caused precompile/test issues.

### Suggested Migration Steps (if Option C is chosen)
1. Update `src/agents/Agents.jl` exports to include only module roots + wrapper types + shared data types.
2. Remove wrapper functions from `Agents` (e.g., `poll_control!`, `emit_qos!`).
3. Update tests/examples to use `Producer.*`, `Consumer.*`, etc.
4. Consider adding short aliases in `AeronTensorPool` (e.g., `const Producer = Agents.Producer`) for ergonomic imports.

