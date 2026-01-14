# Implementation Plan: Test Cleanup & Coverage Gaps

Specs are authoritative. This plan addresses gaps and test‑suite hygiene identified in the test review.

## Phase 0: Coverage Gaps (Spec‑critical)
Status: complete
- Add join‑time gating tests:
  - MONOTONIC: drop announces older than join_time.
  - REALTIME_SYNCED: ignore join‑time gating and rely on freshness.
- Add producer progress hint aggregation tests for `progress_major_delta_units` (multiple consumers, most aggressive within floors).
- Add JoinBarrier monotonic enforcement tests:
  - non‑monotonic input timestamps => reject stream.
  - non‑monotonic output `out_time` / `out_seq` => reject output.

## Phase 1: Test Helper Refactor
Status: complete
- Add shared helper(s) to build `ShmPoolAnnounce` and `FrameDescriptor` test messages.
- Replace manual announce/descriptor construction in tests with helper usage.
- Ensure helpers track schema changes by using generated codec constants.

## Phase 2: Integration Test Clarity
Status: complete
- Reviewed integration tests; current files already isolate features with clear focus.

## Phase 3: Optional Coverage
Status: complete
- Added checksum success/failure tests for bridge integrity.

## Phase 4: Docs & Matrix
Status: complete
- Updated `docs/SPEC_COMPLIANCE_MATRIX.md` after new coverage.
- Test checklist notes captured in review plan.
