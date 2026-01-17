# Refactoring Targets

This document tracks non-urgent refactors that are intentionally deferred.
Keep entries short and include rationale and any blockers.

## Candidates

Effort ranks are rough (lower is easier). Dependencies indicate suggested ordering, not strict blockers.
Entries are ordered by a suggested implementation sequence.

### Agent client convenience wrappers
- Goal: add non-invasive overloads that accept `TensorPoolClient` for agent init.
- Rationale: cleaner public API without forcing internal refactor to `TensorPoolClient`.
- Status: deferred.
- Effort rank: 1
- Dependencies: none.
- Notes: pass through `client.aeron_client` to existing init functions.

### SHM URI/path normalization
- Goal: centralize conversion between `ShmUri` and filesystem paths.
- Rationale: avoid accidental `joinpath(::ShmUri)` errors and duplicated parsing.
- Status: deferred.
- Effort rank: 3
- Dependencies: none.
- Notes: keep conversions explicit; avoid implicit coercions.

### Message header gating helper
- Goal: centralize schema/template/version checks used in fragment handlers.
- Rationale: reduce duplicated guard logic across consumer/producer/bridge/pollers.
- Status: deferred.
- Effort rank: 4
- Dependencies: none.
- Notes: keep `@inline` and allocation-free; consider `Core.decode_if_template!` helpers.

### Config builder overlay
- Goal: provide a single entry point like `DriverConfig.from_toml(path; env=true, overrides=...)`.
- Rationale: centralize defaults and validation and reduce duplicated parsing.
- Status: deferred.
- Effort rank: 5
- Dependencies: none.
- Notes: ensure deterministic precedence order for overrides.

### Script consolidation and CLI cleanup
- Goal: consolidate redundant scripts (driver launcher, tp_tool wrapper) and simplify usage output.
- Rationale: reduce maintenance and make CLI ergonomics consistent.
- Status: deferred.
- Effort rank: 2
- Dependencies: config builder overlay (optional).
- Notes: keep `tp_tool` app as primary entry point; minimize script-only features.

### Telemetry callback interface
- Goal: add an optional `TelemetrySink`/`EventCallback` interface for counters and debug events.
- Rationale: decouple instrumentation from logging and keep observability consistent.
- Status: deferred.
- Effort rank: 6
- Dependencies: none.
- Notes: keep calls cheap and default to no-op.

### Logging overhead cleanup
- Goal: reduce runtime logging overhead and revisit default logging backend.
- Rationale: noted in `src/core/logging.jl`.
- Status: deferred.
- Effort rank: 7
- Dependencies: telemetry hook interface (optional).

### Do-block resource wrappers
- Goal: add `with_* do ... end` helpers for resources with explicit lifecycle (driver, client, mapped SHM).
- Rationale: reduce leakage and simplify test/resource cleanup.
- Status: deferred.
- Effort rank: 6
- Dependencies: none.
- Notes: ensure helpers do not capture closures in hot paths.

### External test harness standardization
- Goal: unify embedded-driver test setup and environment handling across external-process tests.
- Rationale: reduce flakiness and enforce consistent timeouts/log capture.
- Status: deferred.
- Effort rank: 8
- Dependencies: do-block resource wrappers (optional).
- Notes: prefer embedded media driver for CI portability.

### Control/Discovery poller interface alignment
- Goal: align `DiscoveryResponsePoller` and `DriverResponsePoller` with `AbstractControlPoller`.
- Rationale: common `poll!`/`close!` interface for orchestration code.
- Status: deferred.
- Effort rank: 10
- Dependencies: none.
- Notes: avoid abstract storage in hot paths.

### Subscription rebind helper
- Goal: unify close/recreate logic for descriptor/control/progress subscriptions.
- Rationale: avoid drift and edge-case leaks; keep per-consumer reassignment consistent.
- Status: deferred.
- Effort rank: 9
- Dependencies: align poller interfaces (Control/Discovery) (optional).
- Notes: should be explicit about channel/stream change detection and close ordering.

### Multiple-dispatch handler split
- Goal: use multiple dispatch to separate per-message/per-config handling logic.
- Rationale: improves readability and isolates logic without large `if`/`case` blocks.
- Status: deferred.
- Effort rank: 12
- Dependencies: message header gating helper (optional).
- Notes: ensure dispatch is on concrete types/`Val`s to avoid dynamic dispatch in hot paths.

### Trait-based JoinBarrier rule handling
- Goal: use traits to unify sequence/timestamp rule handling where appropriate.
- Rationale: reduce branching while keeping type-stable paths.
- Status: deferred.
- Effort rank: 11
- Dependencies: none.
- Notes: avoid traits for runtime config flags; restrict to concrete rule types.

### Trait-based message dispatch
- Goal: use Holy Traits to map message kinds to schema/template/decoder types.
- Rationale: consolidate decode/gating logic while keeping compile-time dispatch.
- Status: deferred.
- Effort rank: 13
- Dependencies: message header gating helper; multiple-dispatch handler split (optional).
- Notes: keep trait returns as constants (`Val`/types) to preserve type stability.

### Poller unification (future)
- Goal: align `DriverResponsePoller` and new descriptor/config/progress pollers under a shared interface and ownership model.
- Rationale: consistent API surface and lifecycle.
- Status: deferred; prioritize stable control-plane wiring first.
- Effort rank: 14
- Dependencies: align poller interfaces (Control/Discovery), subscription rebind helper.
- Notes: add abstract interface (`poll!`, `close!`, optional `rebind!`) without forcing ownership changes.

### Structured error categories
- Goal: introduce typed error categories (`ProtocolError`, `ShmError`, `AeronError`) for debugging and interop.
- Rationale: reduce string matching and make errors actionable across language bindings.
- Status: deferred.
- Effort rank: 16
- Dependencies: none.
- Notes: avoid adding allocations in hot paths.

### Agent lifecycle interface
- Goal: define a small abstract interface for agent lifecycle (`init!`, `do_work!`, `close!`) and optional `rebind!`.
- Rationale: unify runner/supervisor patterns and simplify tests around agent ownership.
- Status: deferred.
- Effort rank: 15
- Dependencies: none.
- Notes: avoid abstract storage in hot paths; keep concrete state structs.

### TensorPoolRuntime ownership object
- Goal: add a runtime object that owns `Aeron.Context`, `Aeron.Client`, clocks, and `ControlPlaneRuntime`.
- Rationale: clear lifecycle management with `with_runtime do ... end`.
- Status: deferred.
- Effort rank: 17
- Dependencies: agent lifecycle interface, do-block resource wrappers, config builder overlay (optional).
- Notes: keep it optional to avoid forcing a single construction path.

### Client vs agent API split
- Goal: define a clearer split between `TensorPoolClient` and agent APIs (`ProducerAgent`/`ConsumerAgent`).
- Rationale: reduce ambiguity about attach/keepalive vs data-plane responsibilities.
- Status: deferred.
- Effort rank: 18
- Dependencies: agent client convenience wrappers (optional).
- Notes: keep constructors thin; avoid coupling to `Aeron.Client`.
