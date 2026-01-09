# Wire Spec Tightening Implementation Plan

Spec source: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md` (commit 52f026c). The spec is authoritative.

## Phase 0 - Baseline Review (complete when checked)
- [x] Locate all seqlock read paths that decode headerBytes and validate embedded headers.
- [x] Locate progress handling paths (FrameProgress, progress trackers).
- [x] Locate producer frame publish ordering (seq_commit vs FrameDescriptor).
- [x] Locate payload_slot range checks.
- [ ] Locate SHM epoch cleanup logic (driver/supervisor) for activity_timestamp_ns + PID liveness.

## Phase 1 - Embedded Header Validation
- [x] Julia: enforce schemaId + version + templateId + length for embedded TensorHeader.
- [x] C: enforce schemaId + version + templateId + length for embedded TensorHeader.
- [x] Add unit tests for invalid schemaId/version/templateId/length.

## Phase 2 - Payload Slot Range + Empty Payload
- [x] Julia: drop if payload_slot out of range for pool.
- [x] C: drop if payload_slot out of range for pool.
- [ ] Julia/C: if values_len_bytes == 0, skip payload reads (tests).

## Phase 3 - FrameDescriptor Publish Ordering
- [ ] Julia: assert FrameDescriptor publish after commit; add regression test.
- [ ] C: assert FrameDescriptor publish after commit; add regression test (if applicable).

## Phase 4 - Progress Rules
- [x] Julia: enforce payload_bytes_filled <= values_len_bytes.
- [x] Julia: enforce monotonic non-decreasing payload_bytes_filled within a frame.
- [x] C: same checks in progress handling.
- [x] Add tests for regression and bounds.

## Phase 5 - Epoch Cleanup Policy Tightening
- [x] Julia driver/supervisor: scan epoch dirs and unlink when activity_timestamp_ns is stale AND PIDs not active.
- [x] Add tests covering stale activity + dead PID cleanup.
- [x] Document behavior.

## Phase 6 - Validation
- [x] Run Julia tests + C tests.
- [ ] Update docs/IMPLEMENTATION.md if needed.
