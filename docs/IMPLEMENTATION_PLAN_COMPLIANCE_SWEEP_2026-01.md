# Implementation Plan: Compliance Sweep (2026-01)

Specs are authoritative. This sweep reviewed the latest `docs/SHM_*.md` specs against code/tests and refreshed the compliance matrix.

## Phase 0: Sweep Summary
Status: complete
- Reviewed all authoritative specs listed in `docs/SPEC_LOCK.toml`.
- Updated `docs/SPEC_COMPLIANCE_MATRIX.md` date and noted that no new gaps were found.

## Phase 1: Optional Documentation Improvements
Status: pending
- Document the “headless producer” behavior (descriptor publish skipped when no subscribers) in the user guide or operational notes.
- Note that this behavior is implementation guidance (not a normative requirement) and does not change wire compatibility.

## Phase 2: Optional API Ergonomics Checkpoint
Status: pending
- Quick API pass for any new duplicates introduced since last sweep (attach variants, per-consumer stream helpers).
- Only act if a concrete ergonomic issue is found; otherwise mark complete without changes.

## Phase 3: Optional Hsm Refactor Checkpoint
Status: pending
- Re-verify no ad-hoc state machines were introduced since the last Hsm migration.
- If none found, mark complete without changes.

