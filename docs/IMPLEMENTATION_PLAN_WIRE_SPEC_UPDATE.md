# Wire Spec v1.1 Update Plan

Scope: Align implementation with updates in `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md` (seq_commit, TensorSlotHeader, validation rules, activity timestamp freshness). This plan focuses on code + tests; generated SBE code is regenerated as needed.

## Phase 1: Gap Audit (no functional changes) ✅
- Inventory current code references to `TensorSlotHeader256`, `frame_id`, and commit word semantics; note all call sites that must switch to `TensorSlotHeader` and `seq_commit`.
- Verify consumer seqlock checks match the spec: LSB=1 means committed; `seq_commit >> 1` equals `FrameDescriptor.seq`.
- Locate all `header_index` validation and bounds checks; ensure out-of-range drops are enforced.
- Locate payload bounds checks: `values_len_bytes <= stride_bytes` and `payload_offset + values_len_bytes <= stride_bytes`.
- Confirm activity/announce freshness checks are based on `activity_timestamp_ns` (not `announce_timestamp_ns`).

## Phase 2: Core SHM Semantics Updates ✅
- Producer write path:
  - Use `seq_commit` encoding (`in_progress = seq << 1`, `committed = (seq << 1) | 1`).
  - Ensure release semantics on both stores and payload visibility before committed store.
  - Rename any header type usage to `TensorSlotHeader`.
  - Enforce `payload_offset == 0` in v1.1.
  - Zero-fill `dims[i]` and `strides[i]` for all `i >= ndims`.
- Consumer read path:
  - Validate `header_index` range before SHM access.
  - Seqlock: read `seq_commit` (acquire), check LSB=1, read header/payload, re-read `seq_commit` (acquire), ensure unchanged and `seq_commit >> 1 == FrameDescriptor.seq`.
  - Enforce `ndims in 1..MAX_DIMS`, `payload_offset == 0`, and bounds checks against `stride_bytes`.
  - Drop on mismatch and account for `drops_gap`/`drops_late` per current policy.

## Phase 3: Codec and Naming Alignment ✅
- Update any references from `TensorSlotHeader256` to `TensorSlotHeader` in code and tests.
- Ensure generated SBE constants (e.g., `maxDims`) are referenced rather than hard-coded.
- Regenerate SBE outputs from `schemas/wire-schema.xml` if codegen mismatches remain.

## Phase 4: Tests and Benchmarks ✅
- Update unit tests to match new semantics (`seq_commit`, `ndims`, `payload_offset`, header_index bounds).
- Add coverage for:
  - drop when `ndims=0` or `ndims > MAX_DIMS`
  - drop when `payload_offset != 0`
  - drop when `values_len_bytes > stride_bytes`
  - drop when `header_index` out of range
  - drop on `seq_commit` mismatch with `FrameDescriptor.seq`
- Update integration tests and examples to use the renamed header and `seq_commit` fields.
- Re-run allocation tests and throughput benchmarks.

## Phase 5: Documentation Sync ✅
- Update `docs/IMPLEMENTATION_PHASES.md` to mark these changes and current progress.
- Ensure any API docs or examples referencing `frame_id` or `TensorSlotHeader256` are updated.

## Tooling / Commands
- Regenerate all schemas via build step:
  - `julia --project -e 'using Pkg; Pkg.build("AeronTensorPool")'`
- Run tests:
  - `julia --project -e 'using Pkg; Pkg.test()'`
