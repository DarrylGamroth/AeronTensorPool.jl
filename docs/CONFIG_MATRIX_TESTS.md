# Config-Matrix Integration Coverage

This checklist tracks configuration permutations implied by the specs and maps each to
integration tests. Update this file when config keys or optional behaviors change.

Requirements-to-tests checklist: `docs/SPEC_TRACEABILITY_MATRIX.md` (use Status=Gap for
any uncovered MUST/SHOULD requirement).

Status legend:
- Covered: exercised by tests listed.
- Gap: missing explicit integration coverage; add a test or document verification.

| Area | Axis | Permutations | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| Driver attach | publishMode | REQUIRE_EXISTING | `test/test_driver_attach.jl` | Covered |  |
| Driver attach | publishMode | EXISTING_OR_CREATE (create path) | `test/test_driver_reuse_existing_shm.jl`, `test/test_driver_shm_permissions.jl` | Covered | Internal create path covered. |
| Driver attach | publishMode | EXISTING_OR_CREATE (attach protocol) |  | Gap | Add control-plane attach test to exercise dynamic create. |
| Driver attach | desiredNodeId | 0 / explicit | `test/test_driver_desired_node_id.jl` | Covered |  |
| Driver attach | expectedLayoutVersion | match / mismatch | `test/test_driver_expected_layout_version.jl` | Covered |  |
| Driver attach | require_hugepages | allow / require | `test/test_driver_attach.jl` | Covered | Reject path covered when hugepages unavailable. |
| Driver policies | reuse_existing_shm | false / true | `test/test_driver_reuse_existing_shm.jl` | Covered | Default false exercised broadly. |
| Driver policies | cleanup_shm_on_exit | false / true | `test/test_driver_cleanup_shm.jl` | Covered |  |
| Producer/consumer | supports_progress | false / true | `test/test_producer_progress_emit.jl` | Covered | False is default in most integration tests. |
| Producer/consumer | progress hints | interval / delta units | `test/test_producer_progress_hints.jl` | Covered |  |
| Producer/consumer | per-consumer streams | off / on | `test/test_per_consumer_streams.jl`, `test/test_driver_per_consumer_streams.jl` | Covered |  |
| Producer/consumer | mode | STREAM / RATE_LIMITED | `test/test_consumer_rate_limited.jl`, `test/test_rate_limiter_end_to_end.jl` | Covered |  |
| Producer/consumer | fallback URI | invalid primary / fallback | `test/test_consumer_remap_fallback.jl` | Covered |  |
| Bridge | forward_metadata | off / on | `test/test_bridge_integration.jl` | Covered |  |
| Bridge | forward_progress | off / on | `test/test_bridge_progress_mapping.jl` | Covered | Off is default in most bridge tests. |
| Bridge | forward_qos | off / on | `test/test_bridge_qos_forwarding.jl` | Covered |  |
| Bridge | integrity_crc32c | off / on | `test/test_bridge_integrity.jl` | Covered |  |
| Bridge | max_payload_bytes | within / exceed | `test/test_bridge_max_payload_bytes.jl` | Covered |  |
| Discovery | provider/registry | provider / registry | `test/test_discovery_integration.jl`, `test/test_discovery_multihost.jl`, `test/test_discovery_end_to_end.jl` | Covered |  |
| RateLimiter | forward_progress | off / on | `test/test_rate_limiter_end_to_end.jl`, `test/test_rate_limiter_config_validation.jl` | Gap | Forwarding enabled path not integrated; validation covered. |
| RateLimiter | forward_qos | off / on | `test/test_rate_limiter_end_to_end.jl`, `test/test_rate_limiter_config_validation.jl` | Gap | Forwarding enabled path not integrated; validation covered. |
| JoinBarrier | mode | sequence / timestamp / latest | `test/test_join_barrier_sequence.jl`, `test/test_join_barrier_timestamp.jl`, `test/test_join_barrier_latest.jl` | Covered |  |
| TraceLink | tracing | off / on | `test/test_tracelink.jl`, `test/test_bridge_tracelink_chunks.jl` | Covered |  |
