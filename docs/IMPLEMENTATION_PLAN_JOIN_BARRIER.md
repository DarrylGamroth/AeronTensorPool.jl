# Join Barrier Implementation Plan (v1.0)

Spec reference: `docs/SHM_Join_Barrier_Spec_v1.0.md` (authoritative).

Goal: Implement a Join Barrier API (core state + handlers) to gate readiness per spec, with an optional Agent wrapper for polling and scheduling. Integrate with driver/client control plane and add tests.

---

## Phase 0: Spec survey + schema alignment
- Review Join Barrier spec sections and identify required messages/fields.
- Verify `schemas/*-schema.xml` already include Join Barrier messages; update and regenerate codecs if needed.
- Document any schema changes first if required.

Status: completed.

---

## Phase 1: Core types and programmatic configuration
- Define Join Barrier config types (structs) and programmatic constructors.
- Define mapping/criteria types (stream_id, role, quorum, timeout, epoch policy, etc.).
- Validate config invariants (nonzero streams, quorum > 0, timeouts sensible) in constructors/helpers.

Status: completed.

---

## Phase 2: Join Barrier core API
- Implement Join Barrier state and handlers (pure API; no Agent dependency).
- Define handler entry points for MergeMap announce/request, descriptors, and cursor updates.
- Keep Aeron specifics outside the core to allow embedding in other runtimes.

Status: completed.

---

## Phase 3: Join Barrier logic
- Track participant arrivals and enforce quorum/criteria.
- Gate attach responses or issue JoinBarrierReady per spec.
- Handle timeouts, retries, and stale participants.
- Reset on epoch changes and handle disconnects.

Status: completed.

---

## Phase 4: Optional Agent integration
- Implement Agent wrapper (`JoinBarrierAgent`) with `Agent.do_work` and timers.
- Ensure cached clock usage (single `fetch!` per cycle).
- Clean shutdown and resource release.

Status: completed.

---

## Phase 5: Tests
- Unit tests for quorum logic, timeouts, and epoch reset.
- Integration tests with driver + producer/consumer showing join gating.
- Allocation tests for hot paths after init.

Status: completed.

---

## Phase 6: Docs + examples
- Add programmatic usage example (no TOML loader).
- Update `USER_GUIDE.md` and any relevant docs to reference Join Barrier.

Status: completed.
