# Spec Compliance Plan (Sorted by Severity)

This plan is derived from `docs/SPEC_COMPLIANCE_MATRIX.md`. It orders work from highest to lowest severity and references the specific matrix rows.

Severity legend:
- Critical: direct spec violation with security/correctness impact.
- High: protocol mismatch or missing required behavior.
- Medium: partial compliance or unverified behavior in normative sections.
- Low: optional/operational guidance gaps.

---

## Critical

0) Review spec schema changes and regenerate codecs (wire/control/bridge/discovery) (done)
- Reason: schema changes must be applied before code changes.
- Required: review spec appendix sections for schema deltas, update `wire-schema.xml` (and related schema files), then regenerate SBE outputs.
- Verify: generated constants, template IDs, and block lengths match the spec.
  - Status: updated `schemas/wire-schema.xml` and regenerated codecs (`src/gen/ShmTensorpoolControl.jl`).

1) Fix canonical SHM directory layout (Wire §15.21a.3) (done)
- Matrix: `SHM_Tensor_Pool_Wire_Spec_v1.2.md` → 15.21a.3 (Noncompliant)
- Issue: current layout uses `<shm_base_dir>/<namespace>/<producer_instance_id>/epoch-<epoch>/payload-<pool_id>.pool` instead of `tensorpool-${USER}/<namespace>/<stream_id>/<epoch>/<pool_id>.pool`.
- Required: update `src/shm/paths.jl` (and all call sites) to match spec layout and filenames.
- Verify: update tests/examples and any path-based validation logic.

2) Enforce consumer path containment validation (Wire §15.21a.5) (done)
- Matrix: `SHM_Tensor_Pool_Wire_Spec_v1.2.md` → 15.21a.5 (Noncompliant / Not implemented)
- Issue: consumer mappings do not perform canonical realpath containment checks or no-follow opens.
- Required: add consumer-side containment/realpath checks, no-follow open + fstat validation, and fail-closed behavior where unavailable.
- Verify: add tests for path traversal, symlink swap, non-regular file rejection.

---

## High

3) Implement RATE_LIMITED consumer mode or remove from API (Wire §11) (done)
- Matrix: `SHM_Tensor_Pool_Wire_Spec_v1.2.md` → 11 (Partial / Noncompliant)
- Issue: STREAM only; RATE_LIMITED not implemented.
- Required: implement rate-limited flow (per-consumer streams or policy), or explicitly deprecate in API/docs if out-of-scope.
- Verify: tests for accepted/declined rate-limit behavior and local drop fallback.

4) Align driver filesystem policy with wire spec (Driver §9) (done)
- Matrix: `SHM_Driver_Model_Spec_v1.0.md` → 9 (Noncompliant due to 15.21a)
- Issue: driver policy depends on canonical layout + containment rules.
- Required: update driver path creation and validation to the canonical layout, and reflect in driver docs/config.
- Verify: driver integration tests and on-disk layout check.

---

## Medium

5) Validate normative algorithms step-by-step (Wire §15.18)
- Matrix: `SHM_Tensor_Pool_Wire_Spec_v1.2.md` → 15.18 (Needs Review)
- Issue: algorithms implemented but not fully validated against spec steps.
- Required: add a test matrix to cover each normative step for producer/consumer/driver.
- Status: Done (seqlock encoding + header validation tests cover normative steps).

6) Expand overwrite/drop accounting (Wire §15.4)
- Matrix: `SHM_Tensor_Pool_Wire_Spec_v1.2.md` → 15.4 (Needs Review)
- Issue: drops_gap/drops_late tracked but not fully attributed per spec guidance.
- Required: align counters and expose drop causes; update QoS as needed.
- Status: Done (drops_gap/drops_late aligned; tests cover drop paths).

7) Formalize consumer state machine (Wire §15.12 / §15.21)
- Matrix: `SHM_Tensor_Pool_Wire_Spec_v1.2.md` → 15.12/15.21 (Needs Review)
- Issue: consumer lifecycle not formally modeled.
- Required: add explicit consumer state machine or document conformance with existing flow.
- Status: Done (consumer phase tracked with UNMAPPED/MAPPED/FALLBACK + tests).

8) Security/permissions hardening (Wire §15.10 / Discovery §12)
- Matrix: Wire 15.10 (Needs Review), Discovery 12 (Needs Review)
- Issue: platform parity and policy enforcement incomplete.
- Required: implement full policy enforcement and documented defaults for Linux/macOS/Windows.
- Status: Done (restrictive SHM permissions enforced + discovery advisory policy documented).

9) Discovery multi-host/fleet validation (Discovery §8)
- Matrix: `SHM_Discovery_Service_Spec_v_1.0.md` → 8 (Needs Review)
- Issue: registry supports endpoints but fleet behavior unverified.
- Required: add tests for multi-host discovery flows.
- Status: Done (multi-host registry tests added).

---

## Low

10) Integrity checks for bridge (Bridge §5.4)
- Matrix: `SHM_Aeron_UDP_Bridge_Spec_v1.0.md` → 5.4 (Needs Review)
- Issue: no checksum validation.
- Required: decide whether to add checksums or keep best-effort integrity as-is.

11) Deployment/liveness guidance validation (Wire §15.14)
- Matrix: Wire 15.14 (Needs Review)
- Issue: operational guidance not fully validated.
- Required: add operator tests or validation checklist mapping.
- Status: Done (validation checklist in OPERATIONAL_PLAYBOOK).

---

## Not Implemented (Deferred Specs)

The following specs are drafts and intentionally unimplemented; keep as backlog items:
- `SHM_Join_Barrier_Spec_v1.0.md`
- `SHM_RateLimiter_Spec_v1.0.md`
- `SHM_Service_Control_Plane_Spec_v1.0.md`
- `SHM_TraceLink_Spec_v1.0.md`
- `AeronTensorPool_Data_Product_Service_spec_draft_v_0.md`
- `AeronTensorPool_Data_Recorder_spec_draft_v_0.md`
