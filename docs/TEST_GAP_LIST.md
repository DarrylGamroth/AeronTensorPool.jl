# Spec-Compliance Test Gaps

This document lists known gaps in test coverage for spec compliance. The spec is authoritative.

## Julia (test/)
- [x] Control-plane schema gating (Wire Spec §15, Driver Spec §10) covered by `test/test_control_schema_gating.jl` and `test/test_consumer_schema_gating.jl`.
- [x] Attach backoff timing (Driver Spec §10) covered by `test/test_attach_backoff.jl`.
- [x] Attach response validation completeness (Driver Spec §10) covered by `test/test_driver_attach_required_fields.jl`.
- [x] Discovery gating (Discovery Spec §6/§7) covered by `test/test_discovery_schema_gating.jl`.
- [x] Bridge publish ordering (Bridge Spec §7/§9) covered by `test/test_bridge_publish_ordering.jl`.
- [x] Bridge header validation (Bridge Spec §7) covered by `test/test_bridge_header_validation.jl`.
- [x] Consumer edge validation (Wire Spec §15.19):
  - `payload_offset != 0` drop covered by `test/test_consumer_payload_offset_invalid.jl`.
  - `payload_slot != header_index` drop covered by `test/test_consumer_payload_slot_mismatch.jl`.
  - Mixed template IDs on descriptor/control streams covered by `test/test_consumer_schema_gating.jl`.

## C (c/tests)
- [x] Seqlock failure modes (Wire Spec §15.19) covered by `c/tests/tp_seqlock_drop_test.c`.
- [x] Epoch remap behavior (Wire Spec §15.21) covered by `c/tests/tp_epoch_remap_test.c`.
- [x] SHM validation (Wire Spec §15.22) covered by `c/tests/tp_shm_validation_fallback_test.c` (stride + hugepage enforcement).
- [x] Control-plane schema gating (Driver Spec §10) covered by `c/tests/tp_control_schema_gating_test.c`.
- [x] Attach backoff/timer behavior (Driver Spec §10) covered by `c/tests/tp_attach_backoff_test.c`.
- [x] Attach required field validation (Driver Spec §10) covered by `c/tests/tp_attach_required_fields_test.c`.
- [x] Per-consumer stream assignment validation (Driver Spec §9) covered by `c/tests/tp_per_consumer_streams_test.c`.
- [x] Lease revoke handling (Driver Spec §10) covered by `c/tests/tp_lease_revoke_reattach_test.c`.
- [x] Discovery schema gating (Discovery Spec §6/§7) covered by `c/tests/tp_discovery_gating_test.c`.

## Suggested Test Artifacts
- Julia:
  - `test/test_control_schema_gating.jl`
  - `test/test_driver_attach_required_fields.jl`
  - `test/test_attach_backoff.jl`
  - `test/test_discovery_schema_gating.jl`
  - `test/test_bridge_publish_ordering.jl`
  - `test/test_bridge_header_validation.jl`
  - `test/test_consumer_payload_offset_invalid.jl`
  - `test/test_consumer_payload_slot_mismatch.jl`
- C:
  - `c/tests/tp_seqlock_drop_test.c`
  - `c/tests/tp_epoch_remap_test.c`
  - `c/tests/tp_shm_validation_fallback_test.c`
  - `c/tests/tp_control_schema_gating_test.c`
  - `c/tests/tp_attach_required_fields_test.c`
  - `c/tests/tp_attach_backoff_test.c`
  - `c/tests/tp_per_consumer_streams_test.c`
  - `c/tests/tp_lease_revoke_reattach_test.c`
  - `c/tests/tp_discovery_gating_test.c`
