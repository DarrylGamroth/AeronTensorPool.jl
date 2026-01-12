# Implementation Plan: Spec Completion (Julia)

This plan brings the Julia reference implementation into full alignment with the
authoritative specs. RateLimiter is explicitly out of scope.

## Scope

Specs:
- `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- `docs/SHM_Driver_Model_Spec_v1.0.md`
- `docs/SHM_Discovery_Service_Spec_v_1.0.md`
- `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md`

Out of scope:
- RateLimiter implementation (spec exists; implementation deferred).

## Phase 1: Fresh Announce Gate After Attach

Goal: enforce the spec rule that consumers must not trust descriptors until a
fresh `ShmPoolAnnounce` is observed (even if attach response was OK).

Tasks:
1. Add a `await_fresh_announce` flag and `last_fresh_announce_ns` to `ConsumerState`.
2. On successful attach, set `await_fresh_announce = true`.
3. When a fresh announce is accepted, clear the flag and update `last_fresh_announce_ns`.
4. In `try_read_frame!`, drop descriptors while `await_fresh_announce` is true.
5. Add tests:
   - Attach + descriptor before announce should be dropped.
   - Descriptor after fresh announce should pass.

## Phase 2: Progress Major Delta Units (Producer)

Goal: honor `progressMajorDeltaUnits` hints from `ConsumerHello` and apply the
producer floor/aggregation rules.

Tasks:
1. Track `progress_major_delta_units` in `ProducerState` and initialize to 0.
2. In `handle_consumer_hello!`, update the major delta using:
   - floor = producer config default
   - effective = min(existing, hint) but not below floor
3. Update `should_emit_progress!` to gate on major delta when:
   - `progressUnit != NONE` and `progress_stride_bytes > 0`
4. Add tests for:
   - major delta honored when hints are present
   - producer floor is respected

## Phase 3: Announce Clock Domain (Driver + Consumer)

Goal: make the announce clock domain configurable, and enforce consumer rules.

Tasks:
1. Add driver config `announce_clock_domain` (MONOTONIC default).
2. Emit `ShmPoolAnnounce.announceClockDomain` from config.
3. In consumer, enforce join‑time filtering only for MONOTONIC and enforce
   freshness window for REALTIME_SYNCED.
4. Add tests for both clock domains.

## Phase 4: Layout Version Source of Truth

Goal: remove hardcoded `layoutVersion=1` and ensure a single source of truth.

Tasks:
1. Add `layout_version` to driver config (default: 1).
2. Emit layout version in attach responses and announces from config.
3. Validate `expected_layout_version` against driver config.
4. Add tests to ensure mismatch results in a reject or remap.

## Phase 5: Consumer Mode Semantics

Goal: clarify and enforce consumer mode behavior.

Tasks:
1. Decide whether `Mode.RATE_LIMITED` is informational or functional.
2. If functional: enforce drop policy or gating in `should_process`.
3. If informational: update spec/docs to say it is advisory only.
4. Add tests matching the final decision.

## Phase 6: Aeron Connection Helpers (Documentation)

Goal: ensure `*_connected` helpers are treated as advisory only.

Tasks:
1. Add notes in `docs/USER_GUIDE.md` and `docs/IMPLEMENTATION.md`.
2. Add Julia docstrings on `consumer_connected` / `producer_connected`.

## Tracking

Update this file as phases are completed.
