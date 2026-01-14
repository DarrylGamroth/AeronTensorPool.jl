# Implementation Plan: Review Findings

Specs are authoritative. This plan addresses gaps and refactors identified in the review.

## Phase 0: JoinBarrier Review Corrections (Spec Compliance)
Status: complete
- Enforce monotonic input timestamps for TimestampJoinBarrier; reject streams with decreasing timestamps.
- Track output `out_time` monotonicity per output stream and reject non‑monotonic outputs.
- Track output `out_seq` monotonicity per output stream for SequenceJoinBarrier.
- Add tests for monotonic enforcement (sequence + timestamp).
- Update `docs/SPEC_COMPLIANCE_MATRIX.md` after fixes.

## Phase 1: Consumer Join‑Time Gating
Status: complete
- Capture `join_time_ns` from Aeron image availability (subscription callback) instead of init time.
- Plumb join-time into `ConsumerState` and use it in announce filtering.
- Add tests for replay behavior (announce before join time is dropped only for MONOTONIC domain).

## Phase 2: Progress Hint Aggregation
Status: complete
- Add `progress_major_delta_units` to producer state/config.
- Apply per-consumer major-axis hints alongside interval/byte deltas (most aggressive within producer floors).
- Update `ConsumerHello` handling and producer progress emission tests.

## Phase 3: Optional Bridge Integrity (if you want full optional coverage)
Status: complete
- Implement CRC32C per chunk (policy gated) in bridge sender/receiver.
- Add tests verifying drop on checksum mismatch and passthrough when disabled.

## Phase 4: API / Structure Refactors (non‑blocking)
Status: complete
- Extracted shared encoder helper for `ConsumerConfig` across driver/producer/supervisor.
- `src/core` layout already segmented (logging/messages/qos/metadata); no structural changes required.
- Renamed the non‑agent discovery layer to `DiscoveryClient` to avoid confusion with `src/agents/discovery`.
- Unified `attach_*` / `request_attach_*` APIs via multiple dispatch on config types (`attach`/`request_attach`).
- Deduplicated metadata forwarding helpers shared between bridge and rate‑limiter.
- Migrated ad‑hoc state machines to Hsm:
  - Consumer mapping phase (UNMAPPED → MAPPED → FALLBACK) now transitions via `ConsumerMappingLifecycle`.
  - Producer driver reattach flow (pending attach → remap → active) now transitions via `ProducerDriverLifecycle`.

## Phase 5: Aeron Callbacks / Async Hooks
Status: complete
- Using `on_available_image` / `on_unavailable_image` callbacks for join-time and diagnostics.
- Async add_publication/subscription not required for current startup behavior.

## Phase 6: Docs & Matrix
Status: complete
- Updated USER_GUIDE / CONFIG_REFERENCE for join‑time gating and bridge integrity.
- Refreshed `docs/SPEC_COMPLIANCE_MATRIX.md` after fixes.
- Added Aeron callback usage note for join‑time gating guidance.
- Test checklist items covered in plan/test updates.

## Phase 7: Spec Traceability Lock + Matrix Coverage
Status: complete
- Generated `docs/SPEC_LOCK.toml` with hashes for all authoritative specs.
- Added `scripts/check_spec_lock.jl` and run it from `scripts/run_tests.jl` (CI gate).
- Filled `docs/SPEC_TRACEABILITY_MATRIX.md` with code/test references and status.
- Updated `docs/SPEC_COMPLIANCE_MATRIX.md` with traceability pointers.

## Phase 8: Hsm Migration for Remaining Ad‑hoc Lifecycles
Status: complete
- Bridge receiver assembly lifecycle (idle → assembling → complete/timeout) via Hsm.
- RateLimiter mapping binding lifecycle (unbound → bound → active) via Hsm.
