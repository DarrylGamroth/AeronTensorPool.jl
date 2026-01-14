# Implementation Plan: Traceability Remediation

Specs are authoritative. This plan tightens requirement‑to‑code/test mapping and closes any gaps surfaced by the traceability matrix.

## Phase 0: Scope + Lock
Status: complete
- Use the spec lock (`docs/SPEC_LOCK.toml`) as the authoritative version set.
- Use `docs/SPEC_TRACEABILITY_MATRIX.md` as the master mapping document.

## Phase 1: High‑Risk Requirements (Wire + Driver)
Status: complete
- Replace section‑level defaults with precise code/test references for:
  - Seqlock protocol (commit/verify/drop rules).
  - Schema gating (templateId, schemaId, version).
  - Descriptor ordering vs commit (publish only after commit).
  - Attach response required fields and nullValue handling.
- Verify each requirement has a direct unit/integration test reference; add missing tests if needed.

## Phase 2: Bridge/RateLimiter/Discovery/JoinBarrier Precision
Status: complete
- Bridge:
  - Chunk header validation, payload length cap, CRC policy, progress/QoS forwarding rules.
- RateLimiter:
  - Max‑rate handling, progress/QoS forwarding preconditions, mapping lifecycle.
- Discovery:
  - Expiry, epoch regression handling, schema gating.
- JoinBarrier:
  - Monotonicity enforcement and staleness handling for all modes.
- Replace defaults with explicit code/test refs for each normative clause.

## Phase 3: Traceability Gaps → Tests
Status: in progress
- Add a driver control schema gating test for Driver spec §137 (or adjust mapping if test already exists).
- Re‑scan for gaps after the new test is added.

## Phase 4: CI / Regression Safeguards
Status: pending
- Ensure `scripts/run_tests.jl` remains the single entry point for spec‑locked testing.
- Add a lightweight checklist in CI to block merges when spec lock or traceability matrix is stale.
