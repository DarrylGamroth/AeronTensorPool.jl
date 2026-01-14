# Bridge TraceId v1.1 Implementation Plan

Spec reference (authoritative): `docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md`

Goal: implement `BridgeFrameChunk.traceId` propagation and v1.1 validation rules, including schemaId guard on payload channel and relaxed chunk sizing (non‑overlapping slices).

---

## Phase 0: Schema + codegen
- Add `traceId` to `schemas/bridge-schema.xml` (field id=12, optional, nullValue=0).
- Regenerate `src/gen/ShmTensorpoolBridge.jl` via `deps/build.jl`.

Status: completed.

## Phase 1: Sender traceId propagation
- Extend `BridgeChunkFill` to carry `trace_id`.
- Populate `BridgeFrameChunk.traceId` from upstream `FrameDescriptor.traceId`.

Status: completed.

## Phase 2: Receiver traceId enforcement
- Track `trace_id` in `BridgeAssembly`.
- Validate `traceId` consistency across all chunks; drop and reset on mismatch.
- Use `trace_id` from chunk header when publishing local `FrameDescriptor`.

Status: completed.

## Phase 3: Payload channel schemaId guard
- Validate `MessageHeader.schemaId` before decoding `BridgeFrameChunk` on payload channel.

Status: completed.

## Phase 4: Chunk validation alignment
- Relax strict chunk offset/length checks.
- Enforce non‑overlap and `sum(chunkLength) == payloadLength`.
- Keep MTU/max chunk checks and header length checks from v1.1.

Status: completed.

## Phase 5: Tests
- Add a traceId bridge test (traceId propagates into rematerialized descriptor).
- Add a mismatch test (traceId differs across chunks ⇒ drop).

Status: completed.
