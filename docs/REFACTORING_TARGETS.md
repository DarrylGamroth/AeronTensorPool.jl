# Refactoring Targets

This document tracks non-urgent refactors that are intentionally deferred.
Keep entries short and include rationale and any blockers.

## Candidates

Effort ranks are rough (lower is easier). Dependencies indicate suggested ordering, not strict blockers.
Entries are ordered by a suggested implementation sequence. Each entry is numbered so we can track
progress and refer to remaining items.

### 1) Agent client convenience wrappers
- Goal: add non-invasive overloads that accept `TensorPoolClient` for agent init.
- Rationale: cleaner public API without forcing internal refactor to `TensorPoolClient`.
- Status: completed (refactor/targets-1-5).
- Effort rank: 1
- Dependencies: none.
- Notes: wrappers live in `src/client/agent_wrappers.jl` and forward `client.aeron_client`.

### 2) SHM URI/path normalization
- Goal: centralize conversion between `ShmUri` and filesystem paths.
- Rationale: avoid accidental `joinpath(::ShmUri)` errors and duplicated parsing.
- Status: completed (refactor/targets-1-5).
- Effort rank: 3
- Dependencies: none.
- Notes: added `shm_path` helper and replaced direct `.path` uses.

### 3) Message header gating helper
- Goal: centralize schema/template/version checks used in fragment handlers.
- Rationale: reduce duplicated guard logic across consumer/producer/bridge/pollers.
- Status: completed (refactor/targets-1-5).
- Effort rank: 4
- Dependencies: none.
- Notes: added `matches_*` helpers in `src/core/messages.jl` and switched handlers/pollers.

### 4) Config builder overlay
- Goal: provide a single entry point like `DriverConfig.from_toml(path; env=true, overrides=...)`.
- Rationale: centralize defaults and validation and reduce duplicated parsing.
- Status: completed (refactor/targets-1-5).
- Effort rank: 5
- Dependencies: none.
- Notes: added `from_toml(DriverConfig, ...)` with env mapping and overrides support; scripts now use `from_toml` (examples, smoke tests, interop helpers).

### 5) Script consolidation and CLI cleanup
- Goal: consolidate redundant scripts (driver launcher, tp_tool wrapper) and simplify usage output.
- Rationale: reduce maintenance and make CLI ergonomics consistent.
- Status: completed (refactor/targets-1-5).
- Effort rank: 2
- Dependencies: config builder overlay (optional).
- Notes: run_driver uses `from_toml`; tp_tool usage trimmed and config commands use `from_toml`.

### 6) Telemetry callback interface
- Goal: add an optional `TelemetrySink`/`EventCallback` interface for counters and debug events.
- Rationale: decouple instrumentation from logging and keep observability consistent.
- Status: completed (refactor/targets-6-9).
- Effort rank: 6
- Dependencies: none.
- Notes: keep calls cheap and default to no-op; wired to counter updates and TPLog macros.

### 7) Logging overhead cleanup
- Goal: reduce runtime logging overhead and revisit default logging backend.
- Rationale: noted in `src/core/logging.jl`.
- Status: completed (refactor/targets-6-9).
- Effort rank: 7
- Dependencies: telemetry hook interface (optional).
- Notes: TP_LOG_FLUSH and TP_LOG_FORMAT controls; telemetry updates on log settings reload.

### 8) Do-block resource wrappers
- Goal: add `with_* do ... end` helpers for resources with explicit lifecycle (driver, client, mapped SHM).
- Rationale: reduce leakage and simplify test/resource cleanup.
- Status: completed (refactor/targets-6-9).
- Effort rank: 6
- Dependencies: none.
- Notes: helpers are setup/teardown only; avoid hot paths.

### 9) External test harness standardization
- Goal: unify embedded-driver test setup and environment handling across external-process tests.
- Rationale: reduce flakiness and enforce consistent timeouts/log capture.
- Status: completed (refactor/targets-6-9).
- Effort rank: 8
- Dependencies: do-block resource wrappers (optional).
- Notes: prefer embedded media driver for CI portability.

### 10) Control/Discovery poller interface alignment
- Goal: align `DiscoveryResponsePoller` and `DriverResponsePoller` with `AbstractControlPoller`.
- Rationale: common `poll!`/`close!` interface for orchestration code.
- Status: completed (refactor/targets-10-14).
- Effort rank: 10
- Dependencies: none.
- Notes: avoid abstract storage in hot paths.

### 11) Subscription rebind helper
- Goal: unify close/recreate logic for descriptor/control/progress subscriptions.
- Rationale: avoid drift and edge-case leaks; keep per-consumer reassignment consistent.
- Status: completed (refactor/targets-10-14).
- Effort rank: 9
- Dependencies: align poller interfaces (Control/Discovery) (optional).
- Notes: should be explicit about channel/stream change detection and close ordering.

### 12) Multiple-dispatch handler split
- Goal: use multiple dispatch to separate per-message/per-config handling logic.
- Rationale: improves readability and isolates logic without large `if`/`case` blocks.
- Status: completed (refactor/targets-10-14).
- Effort rank: 12
- Dependencies: message header gating helper (optional).
- Notes: ensure dispatch is on concrete types/`Val`s to avoid dynamic dispatch in hot paths.

### 13) Trait-based JoinBarrier rule handling
- Goal: use traits to unify sequence/timestamp rule handling where appropriate.
- Rationale: reduce branching while keeping type-stable paths.
- Status: completed (refactor/targets-10-14).
- Effort rank: 11
- Dependencies: none.
- Notes: avoid traits for runtime config flags; restrict to concrete rule types.

### 14) Trait-based message dispatch
- Goal: use Holy Traits to map message kinds to schema/template/decoder types.
- Rationale: consolidate decode/gating logic while keeping compile-time dispatch.
- Status: completed (refactor/targets-10-14).
- Effort rank: 13
- Dependencies: message header gating helper; multiple-dispatch handler split (optional).
- Notes: keep trait returns as constants (`Val`/types) to preserve type stability.

### 15) Poller unification (future)
- Goal: align `DriverResponsePoller` and new descriptor/config/progress pollers under a shared interface and ownership model.
- Rationale: consistent API surface and lifecycle.
- Status: completed (refactor/targets-15-18).
- Effort rank: 14
- Dependencies: align poller interfaces (Control/Discovery), subscription rebind helper.
- Notes: add abstract interface (`poll!`, `close!`, optional `rebind!`) without forcing ownership changes.

### 16) Structured error categories
- Goal: introduce typed error categories (`ProtocolError`, `ShmError`, `AeronError`) for debugging and interop.
- Rationale: reduce string matching and make errors actionable across language bindings.
- Status: completed (refactor/targets-15-18).
- Effort rank: 16
- Dependencies: none.
- Notes: avoid adding allocations in hot paths; example scripts report protocol/SHM/Aeron errors at attach/discovery.

### 17) Agent lifecycle interface
- Goal: define a small abstract interface for agent lifecycle (`init!`, `do_work!`, `close!`) and optional `rebind!`.
- Rationale: unify runner/supervisor patterns and simplify tests around agent ownership.
- Status: completed (refactor/targets-15-18).
- Effort rank: 15
- Dependencies: none.
- Notes: rely on Agent.jl lifecycle (`on_start`, `do_work`, `on_close`); rebind remains agent-specific.

### 18) TensorPoolRuntime ownership object
- Goal: add a runtime object that owns `Aeron.Context`, `Aeron.Client`, clocks, and `ControlPlaneRuntime`.
- Rationale: clear lifecycle management with `with_runtime do ... end`.
- Status: completed (refactor/targets-15-18).
- Effort rank: 17
- Dependencies: agent lifecycle interface, do-block resource wrappers, config builder overlay (optional).
- Notes: keep it optional to avoid forcing a single construction path; scripts now use `with_runtime` for Aeron lifecycle.

### 19) Client vs agent API split
- Goal: define a clearer split between `TensorPoolClient` and agent APIs (`ProducerAgent`/`ConsumerAgent`).
- Rationale: reduce ambiguity about attach/keepalive vs data-plane responsibilities.
- Status: deferred.
- Effort rank: 18
- Dependencies: agent client convenience wrappers (optional).
- Notes: keep constructors thin; avoid coupling to `Aeron.Client`.
- Proposal:
  - Public split:
    - Client layer (control plane + discovery + QoS/metadata): `connect`, `attach`, `request_attach`, `poll_attach!`,
      `discover_streams!`, `poll_discovery!`, `QosMonitor`, `MetadataCache`, `TraceLink` helpers.
    - Agent layer (data-plane loops): `ProducerAgent`, `ConsumerAgent`, `SupervisorAgent`, `BridgeAgent`, `RateLimiterAgent`,
      and `*_do_work!` functions only.
  - Ownership:
    - `TensorPoolClient`/`TensorPoolRuntime` are the public owners of Aeron resources.
    - Agent constructors accept `TensorPoolClient` (or `TensorPoolRuntime`) in the public API; raw `Aeron.Client`
      constructors remain internal or deprecated later.
  - Migration (breaking change):
    - Remove public `Aeron.Client` constructors for agents; require `TensorPoolClient`/`TensorPoolRuntime`.
    - Update docs/examples and scripts in the same release; bump major/minor to signal the API break.
  - Phases:
    - Phase 1: update public API surface, docs/examples/tests to use client/runtime constructors.
    - Phase 2: remove legacy agent constructors and add release notes for the breaking change.
