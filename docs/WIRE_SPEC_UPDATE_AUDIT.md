# Wire Spec v1.1 Update Audit

Target: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md` (seq_commit + TensorSlotHeader renames and validation rules).

## Call sites using legacy header name or frame_id/commit_word
- `src/core/messages.jl`: `TensorSlotHeader256` alias; `MAX_DIMS` derived from it.
- `src/shm/superblock.jl`: `TensorSlotHeader256` wrappers and read/write helpers; uses `frame_id`, `commit_word`.
- `src/shm/seqlock.jl`: seqlock helpers name/semantics reference `commit_word` and `frame_id`.
- `src/shm/slots.jl`: `commit_word`/`frame_id` fields in slot view.
- Producer/consumer/bridge/decimator code and tests reference `frame_id`.
- Benchmarks and tools use `TensorSlotHeader256`.

## Consumer validation and bounds checks (current)
- `src/agents/consumer/frames.jl`: checks `payload_offset != 0` (drops), `header.ndims > max_dims` (drops), stride/layout checks, seq mismatch checks, and drop accounting.
- `src/agents/consumer/frames.jl`: uses `header.frame_id` and `seqlock_frame_id` comparisons; also uses `last_commit_words` (commit word stability).
- Missing explicit check for `header_index` range in the frame read path (spec now requires drop).
- Missing explicit `values_len_bytes <= stride_bytes` bounds check (spec now requires drop).

## Activity timestamp freshness
- `src/agents/consumer/mapping.jl`: uses announce freshness checks; confirm it uses `activity_timestamp_ns` (spec now mandates this field name).
- `src/agents/producer/init.jl` and `src/agents/producer/frames.jl`: refresh activity timestamps in superblocks; verify `activity_timestamp_ns` name is used.

## Test/bench artifacts to update
- Tests referencing `TensorSlotHeader256` and `frame_id`:
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
Update all references to `TensorSlotHeader` and `seq_commit` and introduce explicit checks:
- `header_index` bounds drop.
- `values_len_bytes` vs `stride_bytes` bounds drop.
- `ndims` must be `1..MAX_DIMS`.
- `payload_offset` must be 0 (v1.1).
