# Driver Spec v1.0 Update Plan

This plan tracks code changes required to conform to `docs/SHM_Driver_Model_Spec_v1.0.md`. The spec is authoritative.

## Phase 1: Control-Plane Semantics

- **Client ID uniqueness**: reject attach if `clientId` already attached for a role/stream; ensure error code `REJECTED` and diagnostic message.
- **Attach response completeness**: enforce required fields for `code=OK`, set non-null values in driver responses.
- **Null sentinels**: ensure optional fields use explicit `nullValue` sentinels when absent.
- **Response codes**: align `UNSUPPORTED`, `INVALID_PARAMS`, `REJECTED`, `INTERNAL_ERROR` mapping to spec cases.
- **Lease ID uniqueness**: ensure `leaseId` never reused within driver process lifetime.

## Phase 2: Lease Lifecycle and Revocation

- **Lease keepalive**: enforce expiry and grace intervals; update driver policies if needed.
- **Revocation emission**: emit `ShmLeaseRevoked` for detach/expire/revoke, including reason and role.
- **Epoch bump on producer revoke/expire**: ensure `epoch` increments and `ShmPoolAnnounce` is emitted promptly.
- **Consumer handling**: on `ShmLeaseRevoked`, stop using SHM immediately and reattach; wait for epoch-bumped announce when producer is revoked.
- **Client keepalive failures** (§4.4): treat keepalive send failure as fatal and reattach.

## Phase 3: Attach/Detach Validation

- **MaxDims handling**: require `maxDims=0` in requests; driver ignores nonzero and returns schema constant.
- **Header/pool constraints**: enforce `poolNslots == headerNslots` and reject mismatches.
- **URI validation**: driver validates all URIs before sending; clients validate and drop on error.
- **Hugepages policy**: enforce `HUGEPAGES`/`STANDARD`/`UNSPECIFIED` behavior per spec.
- **Detach idempotence** (§4.9): ensure detach is idempotent and always emits `ShmLeaseRevoked`.
- **Concurrent attach** (§4.8): reject concurrent attach requests for same stream/role from a client.

## Phase 3b: Stream ID Allocation Ranges (Spec §11)

- **Dynamic stream allocation**: implement `driver.stream_id_range` when `policies.allow_dynamic_streams=true`.
- **Per-consumer stream ranges**: implement `driver.descriptor_stream_id_range` and `driver.control_stream_id_range`.
- **Range validation**: enforce non-overlapping ranges and exclude control/announce/QoS/static stream IDs.
- **Range exhaustion behavior**: decline per-consumer stream requests with empty channel/zero stream ID.

## Phase 4: Schema Version and Compatibility

- **Schema version checks**: reject higher schema version; return `UNSUPPORTED`.
- **Protocol error handling**: client fail-closed on malformed OK responses, reattach.

## Phase 4b: Driver Failure and Startup Behavior

- **Driver restart** (§10): on driver failure, clients MUST treat SHM as stale and reattach after restart; driver MUST bump epoch before reissuing leases.
- **Startup policy** (§14): support optional delete/recreate behavior; enforce epoch rules before issuing leases.
- **Driver failure handling** (§10): implement explicit epoch bump and announce emission on restart, plus client-side remap/reattach tests.

## Phase 4c: Directory Layout and Namespacing

- **Canonical layout** (§15): ensure driver-created paths follow canonical layout and include namespace/instance id to avoid collisions.

## Phase 4d: Canonical Driver Config Surface

- **Config completeness** (§17): ensure all required keys/defaults are implemented, including announce/QoS defaults and stream ID ranges.
- **Env overrides**: verify env override naming rules (uppercase, dot → underscore).
- **Defaults audit** (§17): verify defaults in `driver/config.jl` match the spec exactly (channels, stream IDs, base dirs, policies).

## Phase 4e: Control-Plane Transport

- **Control channel usage** (§4.5): ensure all control-plane messages are on the configured control stream (or documented alternative).

## Phase 5: Tests and Examples

- **Unit tests**: add tests for attach field completeness, null sentinels, duplicate client IDs.
- **Integration tests**: add revoke + epoch bump behavior tests, detach idempotence.
- **Examples**: ensure default consumer ID avoids collisions and attach retries work with new rules.
- **Protocol error tests** (§4.7a): drop attach on required-field null/empty URI and reattach.
- **Control-plane sequence** (§4.10): optional integration test mirroring the normative sequence (informative).

## Phase 6: Docs and Migration

- **Update user guide**: document lease lifecycle, revocation behavior, and attach error codes.
- **Migration notes**: highlight required client behaviors (fail-closed, reattach on protocol errors).

## Progress

- Phase 1: complete (client ID uniqueness, response completeness, null sentinels, publish-mode UNSUPPORTED).
- Phase 2: complete (revocation emission, keepalive handling, producer epoch bump on revoke/expire, client keepalive failure).
- Phase 3: complete (hugepages policy, maxDims handling, payload pool validation, detach idempotence per spec).
- Phase 3b: complete (dynamic stream ID ranges, per-consumer stream ranges, range validation, decline on exhaustion).
- Phase 4: complete (driver schema version checks, fail-closed attach mapping).
- Phase 4b: complete (restart epoch bump behavior validated).
- Phase 4c: complete (canonical layout already in driver paths).
- Phase 4d: complete (defaults/env overrides aligned with spec).
- Phase 4e: complete (control-plane messages on configured control stream).
- Phase 5: complete (attach completeness, per-consumer allocation, restart epoch tests).
- Phase 6: complete (guidance and migration notes updated).
