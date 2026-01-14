# Implementation Plan: Review Findings

Specs are authoritative. This plan addresses gaps and refactors identified in the review.

## Phase 0: JoinBarrier Review Corrections (Spec Compliance)
- Enforce monotonic input timestamps for TimestampJoinBarrier; reject streams with decreasing timestamps.
- Track output `out_time` monotonicity per output stream and reject non‑monotonic outputs.
- Track output `out_seq` monotonicity per output stream for SequenceJoinBarrier.
- Add tests for monotonic enforcement (sequence + timestamp).
- Update `docs/SPEC_COMPLIANCE_MATRIX.md` after fixes.

## Phase 1: Consumer Join‑Time Gating
- Capture `join_time_ns` from Aeron image availability (subscription callback) instead of init time.
- Plumb join-time into `ConsumerState` and use it in announce filtering.
- Add tests for replay behavior (announce before join time is dropped only for MONOTONIC domain).

## Phase 2: Progress Hint Aggregation
- Add `progress_major_delta_units` to producer state/config.
- Apply per-consumer major-axis hints alongside interval/byte deltas (most aggressive within producer floors).
- Update `ConsumerHello` handling and producer progress emission tests.

## Phase 3: Optional Bridge Integrity (if you want full optional coverage)
- Implement CRC32C per chunk or per frame (policy gated, optional flag) in bridge sender/receiver.
- Add tests verifying drop on checksum mismatch and passthrough when disabled.

## Phase 4: API / Structure Refactors (non‑blocking)
- Extract shared encoder helpers for `ConsumerConfig` to avoid duplication across driver/producer/supervisor.
- Clarify `src/core` boundaries (split logging/messages/qos/metadata into more focused modules).
- Rename the non‑agent discovery layer (e.g., `discovery_client`) to avoid confusion with `src/agents/discovery`.
- Unify `attach_*` / `request_attach_*` APIs via multiple dispatch on config types.
- Deduplicate metadata forwarding helpers shared between bridge and rate‑limiter.
- **Hsm migration candidates (explicit):**
  - Consumer mapping phase (UNMAPPED → MAPPED → FALLBACK): consolidate remap/reject/teardown transitions.
  - Producer driver reattach flow (pending attach → remap → active): codify lease revocation, retries, and drain behavior.

## Phase 5: Aeron Callbacks / Async Hooks
- Use `on_available_image` / `on_unavailable_image` callbacks for join-time and diagnostics.
- Optional: on_available_counter / on_unavailable_counter hooks for metrics if needed.
- Decide whether async add_publication/subscription is warranted (only if startup latency or blocking is a problem).

## Phase 6: Docs & Matrix
- Update USER_GUIDE / CONFIG_REFERENCE if semantics change (join‑time, progress hints).
- Refresh `docs/SPEC_COMPLIANCE_MATRIX.md` after each phase.
- Add a short Aeron callback usage note (image available/unavailable) for join‑time gating guidance.
- Add a focused test checklist for join‑time replay and JoinBarrier monotonicity.
