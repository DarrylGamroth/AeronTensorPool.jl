# Wire Spec v1.1 Update Audit

Target: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md` (seq_commit + SlotHeader/TensorHeader rules).

## Call sites using SlotHeader/TensorHeader
- `src/core/messages.jl`: SlotHeader/TensorHeader aliases; `MAX_DIMS` derived from `TensorHeader.maxDims`.
- `src/shm/superblock.jl`: SlotHeader/TensorHeader wrappers and read/write helpers; uses `seq_commit`.
- `src/shm/seqlock.jl`: seqlock helpers name/semantics reference `commit_word` and `frame_id`.
- `src/shm/slots.jl`: `seq_commit` fields in slot view.
- Producer/consumer/bridge code and tests reference `frame_id`.
- Benchmarks and tools use SlotHeader/TensorHeader.

## Consumer validation and bounds checks (current)
- `src/agents/consumer/frames.jl`: checks `payload_offset != 0` (drops), `header.tensor.ndims` bounds, stride/layout checks, seq mismatch checks, and drop accounting.
- `src/agents/consumer/frames.jl`: uses `seq_commit` comparisons and `last_commit_words` for stability.

## Activity timestamp freshness
- `src/agents/consumer/mapping.jl`: uses announce freshness checks; confirm it uses `activity_timestamp_ns` (spec now mandates this field name).
- `src/agents/producer/init.jl` and `src/agents/producer/frames.jl`: refresh activity timestamps in superblocks; verify `activity_timestamp_ns` name is used.

## Test/bench artifacts to update
- Tests referencing SlotHeader/TensorHeader and `seq_commit`:
  - `test/test_tensor_slot_header.jl`
  - `test/test_allocations*.jl`
  - `test/test_consumer_seqlock.jl`
  - `test/test_driver_integration.jl`
- Benchmarks:
  - `bench/benchmarks.jl`
- Scripts/tools:
  - `scripts/tp_tool.jl`
  - `scripts/example_consumer.jl`

## Follow-up mapping for Phase 2+
Update all references to SlotHeader/TensorHeader and ensure explicit checks:
- `values_len_bytes` vs `stride_bytes` bounds drop.
- `ndims` must be `1..MAX_DIMS`.
- `payload_offset` must be 0 (v1.1).
