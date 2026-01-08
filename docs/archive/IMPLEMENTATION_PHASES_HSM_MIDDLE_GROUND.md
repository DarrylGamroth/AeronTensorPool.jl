# Implementation Phases: Driver HSM (Middle‑Ground)

Scope: add a top‑level driver lifecycle HSM only. Per‑lease/per‑stream logic remains procedural.
This is intended to avoid flag‑driven lifecycle handling while keeping the refactor small.

References:
- `docs/DRIVER_HSM_MIDDLE_GROUND.md`
- `docs/DRIVER_HSM_SKETCH.md`

## Phase MG‑0: Design Alignment

Goals
- Confirm event names and lifecycle boundaries.
- Identify which existing driver flags/branches map to lifecycle states.

Deliverables
- Final event list: `Tick`, `ShutdownRequested`, `ShutdownTimeout`.
- Driver lifecycle states: `Init`, `Running`, `Draining`, `Stopped`.
- Mapping notes to current driver functions.

Validation
- Design review only (no code changes).

Status
- Complete (event list and lifecycle mapping captured in HSM docs).

## Phase MG‑1: HSM Scaffolding

Goals
- Introduce the driver lifecycle HSM without changing behavior.

Deliverables
- New `DriverLifecycle` HSM type (using Hsm.jl) with states above.
- Glue that instantiates the HSM alongside `DriverState`.
- `driver_do_work!` dispatches `:Tick` into the HSM.

Validation
- Existing driver tests pass unchanged.

Status
- Complete (DriverLifecycle added; driver loop dispatches Tick).

## Phase MG‑2: Draining Semantics

Goals
- Formalize shutdown behavior without adding per‑lease HSMs.

Deliverables
- `ShutdownRequested` transitions `Running → Draining`.
- In `Draining`, rejects new attaches but allows keepalive/detach/expiry.
- `ShutdownTimeout` transitions `Draining → Stopped` and emits shutdown notice.

Validation
- Driver shutdown tests updated or added to cover Draining behavior.

Status
- Complete (Draining rejects attaches; timer-driven shutdown emits notice).

## Phase MG‑3: Timer Event Wiring

Goals
- Treat announce/lease‑check as events in the driver lifecycle.

Deliverables
- `Tick` handler triggers existing `poll_timers!` and drive `announce`/`lease_check` events.
- Entry/exit callbacks used only for side effects (no transitions).

Validation
- Existing integration tests pass; timing behavior unchanged.

Status
- Complete (Tick dispatches poll_timers!; announce/lease-check handled).

## Phase MG‑4: Documentation and Migration Notes

Goals
- Keep docs aligned and future migration path clear.

Deliverables
- Update `docs/IMPLEMENTATION_PHASES.md` to reference the middle‑ground plan.
- Keep `docs/DRIVER_HSM_MIDDLE_GROUND.md` and `docs/DRIVER_HSM_SKETCH.md` in sync.

Validation
- Documentation review only.

Status
- Complete (IMPLEMENTATION_PHASES.md updated; HSM docs aligned).

## Phase MG‑5: Optional Enhancements

Goals
- Prepare follow-on lifecycle features without altering core behavior.

Deliverables
- Note potential admin `ShutdownRequested` control message integration.
- Define any additional gating for control-plane ops during Draining.
- Optional final announce/QoS snapshot on Draining entry.
- Optional degraded/maintenance state sketch (no implementation).

Validation
- Design review only.

Status
- Complete (admin shutdown request, Draining gating, final announce on Draining entry).
