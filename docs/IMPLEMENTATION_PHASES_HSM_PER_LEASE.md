# Implementation Phases: Driver Per-Lease HSM

Scope: introduce per-lease HSMs while keeping the existing top-level `DriverLifecycle` HSM.
Per-stream HSMs are explicitly deferred to a later stage.

References:
- `docs/DRIVER_HSM_PER_LEASE_PLAN.md`

## Phase L‑0: Design Alignment

Goals
- Confirm lease states and events.
- Map current driver logic to HSM transitions.

Deliverables
- Final lease event list (`AttachOk`, `Keepalive`, `Detach`, `LeaseTimeout`, `Revoke`, `Close`).
- Lease states (`Init`, `Active`, `Detached`, `Expired`, `Revoked`, `Closed`).
- Mapping notes for driver functions.

Validation
- Design review only.

Status
- Pending.

## Phase L‑1: HSM Scaffolding

Goals
- Add a per-lease HSM type without changing behavior.

Deliverables
- `LeaseLifecycle` HSM type using Hsm.jl.
- Lease HSM stored with `DriverLease` or a parallel map in `DriverState`.
- No behavioral changes in attach/detach/keepalive yet.

Validation
- Existing driver tests pass unchanged.

Status
- Pending.

## Phase L‑2: Attach/Keepalive Integration

Goals
- Route attach and keepalive through the lease HSM.

Deliverables
- On successful attach: dispatch `AttachOk`.
- On keepalive: dispatch `Keepalive` and update expiry.

Validation
- Existing attach/keepalive tests pass unchanged.
- Allocation checks remain flat.

Status
- Pending.

## Phase L‑3: Detach/Expiry/Revoke Integration

Goals
- Route detach/expiry/revoke through the lease HSM.

Deliverables
- Detach → `Detach` then `Close`.
- Expiry scan → `LeaseTimeout` then `Close`.
- Revoke → `Revoke` then `Close`.

Validation
- Driver lease expiry tests pass.
- Revoke paths still bump epoch and emit revoke.

Status
- Pending.

## Phase L‑4: Tests and Metrics

Goals
- Validate state transitions explicitly.

Deliverables
- Unit tests for lease HSM transitions.
- Counter or metric updates for invalid transitions (optional).

Validation
- Tests pass; no allocation regressions.

Status
- Pending.
