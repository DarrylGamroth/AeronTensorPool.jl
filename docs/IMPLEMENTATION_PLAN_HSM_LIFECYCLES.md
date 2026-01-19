# HSM Lifecycle Refactor Plan

## Goal
Introduce explicit Hsm.jl state machines for lifecycle/control-plane flows that are
already described by the specs, while keeping hot paths unchanged.

## Scope (initial)
- Consumer attach/reattach/backoff lifecycle.
- Producer attach/backoff lifecycle (extend existing HSM).
- Consumer announce/remap gating lifecycle.
- Driver shutdown/drain lifecycle (extend existing HSM).

## Progress
- [x] Phase 1: Consumer attach/reattach lifecycle HSM (attach/ok/failed/invalid transitions).
- [x] Phase 2: Producer attach/backoff lifecycle HSM extension.
- [x] Phase 3: Consumer announce/remap gating lifecycle HSM.
- [x] Phase 4: Driver shutdown/drain lifecycle HSM extension.

## Out of scope
- Fragment handlers, per-frame processing, and publish hot paths.
- Wire schema changes or codec regeneration.

## Phase 0: Preparation
1. Identify spec anchors for each lifecycle.
   - Driver attach/reattach/backoff: `docs/SHM_Driver_Model_Spec_v1.0.md` (attach, keepalive, revoke).
   - Announce/remap: Driver Model + Wire spec epoch rules.
   - Shutdown/drain: Driver Model shutdown sequence.
2. Enumerate current state variables and side effects in:
   - `src/agents/consumer/lifecycle.jl`
   - `src/agents/producer/lifecycle.jl`
   - `src/agents/driver/lifecycle.jl`
   - `src/agents/driver/lifecycle_handlers.jl`

Deliverable: short mapping of current flags → new HSM states.

## Phase 1: Consumer attach/reattach/backoff HSM
### Files
- `src/agents/consumer/driver_lifecycle_types.jl` (new)
- `src/agents/consumer/driver_lifecycle.jl` (new handlers)
- `src/agents/consumer/state.jl` (add lifecycle field)
- `src/agents/consumer/init.jl` (initialize lifecycle)
- `src/agents/consumer/lifecycle.jl` (wire transitions)

### States
- `Unattached` (no lease, no pending attach)
- `Attaching` (attach sent, waiting response)
- `Attached` (lease valid)
- `Backoff` (retry delay active)

### Events
- `AttachRequested`, `AttachOk`, `AttachFailed`
- `LeaseInvalid`, `AttachTimeout`, `BackoffElapsed`

### Acceptance
- No behavior change in attach success path.
- Revoke/keepalive-fail transitions to `Backoff` or `Unattached` per policy.
- Backoff timer is honored; retries do not spin.

## Phase 2: Producer attach/backoff HSM (extend existing)
### Files
- `src/agents/producer/driver_lifecycle.jl`
- `src/agents/producer/driver_lifecycle_handlers.jl`
- `src/agents/producer/state.jl`
- `src/agents/producer/lifecycle.jl`

### Changes
- Add `Backoff` state to `ProducerDriverLifecycle`.
- Add events `AttachTimeout` and `BackoffElapsed`.
- Ensure `LeaseInvalid` and `AttachFailed` move to `Backoff` if backoff is configured.

### Acceptance
- Producer attach loop is gated by HSM state.
- No publish when not `Active`.

## Phase 3: Consumer announce/remap gating HSM
### Files
- `src/agents/consumer/announce_lifecycle_types.jl` (new)
- `src/agents/consumer/announce_lifecycle.jl` (new handlers)
- `src/agents/consumer/state.jl`
- `src/agents/consumer/lifecycle.jl`

### States
- `Idle` (not waiting)
- `WaitingAnnounce` (epoch bump seen, waiting for announce)
- `Ready` (announce accepted, mapped)
- `RemapPending` (trigger remap)

### Events
- `ProducerRevoke`, `AnnounceSeen`, `AnnounceTimeout`, `EpochChange`

### Acceptance
- Announce timeout behavior remains identical to current logic.
- Remap only occurs after expected epoch announce.

## Phase 4: Driver shutdown/drain HSM (extend existing)
### Files
- `src/agents/driver/lifecycle.jl`
- `src/agents/driver/lifecycle_handlers.jl`
- `src/agents/driver/agent.jl`

### Changes
- Explicit `Draining` → `Stopped` transitions.
- Shutdown request validation triggers `Draining`.
- Timer-based transition to `Stopped`.

### Acceptance
- Driver emits shutdown notice and stops per spec.
- No duplicate shutdown transitions.

## Additional candidates (move side effects into handlers)
- [x] Consumer driver lifecycle: move `reset_mappings!`, `abort_announce_wait!`, and `pending_attach_id` resets into
  `LeaseInvalid` handler in `src/agents/consumer/driver_lifecycle.jl`.
- [x] Consumer announce lifecycle: move timer resets and mapping clears into `ProducerRevoke`/`AnnounceTimeout` handlers
  in `src/agents/consumer/announce_lifecycle.jl` (stash `now_ns`/epoch context in state before dispatch).
- [x] Producer driver lifecycle: move `pending_attach_id` resets and backoff timer setup into `AttachFailed`/`LeaseInvalid`
  handlers in `src/agents/producer/driver_lifecycle_handlers.jl`.
- [x] Bridge assembly lifecycle: move `reset_bridge_assembly!`/`clear_bridge_assembly!` into `AssemblyStart`/
  `AssemblyClear`/`AssemblyTimeout` handlers (stash assembly parameters in state before dispatch).
- [x] RateLimiter mapping lifecycle: move mapping cleanup into `MappingReset` handler in
  `src/agents/ratelimiter/mapping_lifecycle.jl`.

## Timer events as HSM events
- [x] Keep `TimerSet` but have each timer handler dispatch an HSM event (no queues, no allocations).
- [x] Consumer announce wait timer -> `AnnounceTimeout`.
- [x] Consumer/producer backoff timers -> `BackoffElapsed`.
- [x] Driver shutdown timer already emits `ShutdownTimeout`.
- [x] Add small context fields in state (e.g., `announce_event_epoch`, `announce_event_now_ns`) that handlers read.

## Tests
Add or update tests to cover transitions:
- Consumer attach timeout → backoff → reattach.
- Consumer lease revoke → backoff or unattached.
- Producer attach timeout → backoff → attach.
- Announce wait timeout path and reannounce.
- Shutdown request handling and drain timeout.

## Traceability Updates
If behavior changes:
- `docs/SPEC_TRACEABILITY_MATRIX.md`
- `docs/SPEC_COMPLIANCE_MATRIX.md`
- `docs/CONFIG_MATRIX_TESTS.md` (if new config axes are tested)

## Risks
- Accidental hot-path allocation if HSM is used in per-frame loops.
- Behavior drift if state flags are removed without full event coverage.

## Optional follow-ups
- Small HSM for `DriverClientState` (attach/keepalive/revoke).
- Supervisor liveness aggregation lifecycle.
