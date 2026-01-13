# TraceLink Implementation Plan (v1.0)

Spec references (authoritative):
- `docs/SHM_TraceLink_Spec_v1.0.md`
- `docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md` (FrameDescriptor `trace_id`)
- `docs/SHM_Driver_Model_Spec_v1.0.md` (nodeId in attach response)

Goal: Implement TraceLink (trace IDs + TraceLinkSet control-plane messages) as an optional, best‑effort provenance layer with zero‑allocation hot paths after init.

---

## Phase 0: Spec + schema alignment
- Review TraceLink spec and Wire spec references to ensure all required fields/messages are captured.
- Add TraceLink SBE schema (schemaId=904, templateId=1 for TraceLinkSet) under `schemas/trace-link-schema.xml`.
- Verify `FrameDescriptor.trace_id` exists in control schema (already present in `ShmTensorpoolControl`).
- Update `deps/build.jl` to generate `src/gen/ShmTensorpoolTraceLink.jl`.
- Add generated module include/use in `src/AeronTensorPool.jl`.

Status: completed.

---

## Phase 1: Core trace ID generation
- Add `SnowflakeId.jl` dependency (uses Agrona‑compatible layout).
- Implement a `TraceIdGenerator` wrapper (node_id + SnowflakeId generator).
- Define `trace_id` helpers:
  - `next_trace_id!(generator)` (root frames).
  - `reuse_trace_id(parent_trace_id)` (1→1 stages).
  - `new_trace_id_from_parents!(generator, parents)` (N→1 stages).
- Ensure generator is type‑stable and preallocated after init.

Status: completed.

---

## Phase 2: Node ID acquisition
- Use `ShmAttachResponse.nodeId` when present (Driver Model §4.2).
- Allow explicit node ID configuration in API (for standalone mode or static allocation).
- Add helper to resolve node ID precedence:
  1. Explicit config (if provided)
  2. Driver attach response nodeId (if provided)
  3. Error if tracing enabled and node ID missing

Status: completed.

---

## Phase 3: TraceLinkSet encoding/decoding
- Implement TraceLinkSet encoder/decoder wrappers using new schema.
- Add helper to publish TraceLinkSet over control plane (best‑effort, non‑blocking).
- Enforce spec rules:
  - schemaId=904, templateId=1
  - `parents[]` non‑zero and unique
  - `stream_id/epoch/seq/trace_id` match output frame descriptor

Status: completed.

---

## Phase 4: Producer/consumer integration
- Producer:
  - Populate `FrameDescriptor.trace_id` via optional `trace_id` argument on publish/commit helpers.
  - For 1→1 frames: callers reuse upstream trace ID.
  - For N→1 frames: callers mint new trace ID and emit TraceLinkSet.
- Consumer:
  - Read `trace_id` (no behavioral change).
  - Provide callback hooks for trace metadata if needed.
- Add API helpers:
  - `enable_tracing!(producer_state; node_id, generator)`
  - `trace_id_for_output!(...)` and `emit_tracelink!(...)`

Status: in progress.

---

## Phase 5: Tests
- Unit tests:
  - Snowflake ID monotonicity and node ID embedding.
  - TraceLinkSet encode/decode + parent validation.
  - `trace_id` propagation for 1→1 and N→1.
- Integration tests:
  - Producer emits trace_id + TraceLinkSet in multi‑input mock join.
- Allocation tests:
  - Trace ID generation and TraceLinkSet emission are zero‑alloc after init.

Status: in progress.

---

## Phase 6: Docs + examples
- Add a short TraceLink usage example (root, 1→1, N→1) to `USER_GUIDE.md`.
- Document node ID resolution rules and driver attach behavior.
- Add a small script under `scripts/` demonstrating TraceLinkSet emission.

Status: pending.
