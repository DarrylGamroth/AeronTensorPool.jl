# Wire Spec v1.1 Update Plan (Post-2026-01 Changes)

Authoritative source: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`. This plan captures the new delta set (SlotHeader/TensorHeader split, clock domain, per-consumer stream rules, progress metadata changes, and security checks).

## Phase 0: Audit and Alignment (no code changes) ☑
- Inventory all uses of `TensorSlotHeader`/`TensorSlotHeader256`, `FrameProgress.rowsFilled`, and `ShmPoolAnnounce.maxDims`.
- Identify all header parsing/writing call sites that must move to embedded `TensorHeader` inside `SlotHeader.headerBytes`.
- Locate all `ConsumerHello`/`ConsumerConfig` request/assign paths for per-consumer streams.
- Confirm SHM URI validation paths and filesystem/symlink protections.

## Phase 1: Schema and Codegen ☑
- ☑ Validate that `schemas/wire-schema.xml` matches the normative wire spec fields, IDs, and ordering.
- ☑ Regenerate SBE code from updated `schemas/wire-schema.xml`.
- ☑ Update any compile-time constants to use regenerated schema values (e.g., `TensorHeader.maxDims`).
- ☑ Remove old references to `TensorSlotHeader` and `FrameProgress.rowsFilled` in code/tests.

## Phase 2: SlotHeader/TensorHeader Write Path (Producer/Bridge/RateLimiter) ☑
- ☑ Replace header writes with:
  - `SlotHeader` fixed prefix fields.
  - `SlotHeader.headerBytes` varData containing encoded `TensorHeader`.
- ☑ Enforce `headerBytes` length validation (v1.1: 192 bytes including SBE header) during write.
- ☑ Write `progress_unit` and `progress_stride_bytes` in the embedded header.
- ☑ Update any `payload_offset` handling (v1.1: must remain 0).

## Phase 3: SlotHeader/TensorHeader Read Path (Consumer/Bridge/RateLimiter) ☑
- ☑ Parse `SlotHeader.headerBytes` as embedded SBE `TensorHeader` during seqlock reads.
- ☑ Drop if `headerBytes` length or template ID is invalid.
- ☑ Move dims/strides/major_order/dtype/progress fields to the embedded header.
- ☑ Update seqlock algorithm step ordering to include `headerBytes` parse before accept.

## Phase 4: Progress Semantics ☑
- Remove `FrameProgress.rowsFilled` usage.
- Enforce `progress_unit`/`progress_stride_bytes` consistency:
  - If `progress_unit != NONE`, `progress_stride_bytes` must be non-zero and consistent with layout.
  - Drop frames on inconsistencies.
- Update any progress forwarding/bridge logic to match spec.

## Phase 5: ShmPoolAnnounce Clock Domain ☑
- Add `announce_clock_domain` to announce encode/decode paths.
- Enforce monotonic join-time filtering only when `ClockDomain.MONOTONIC`.
- For `REALTIME_SYNCED`, apply freshness window based on receipt time only.
- Reject unsynchronized realtime (spec forbids it in v1.1).

## Phase 6: Per-Consumer Stream Request Rules ☑
- Update ConsumerHello encoding rules:
  - Requests are valid only when channel is non-empty AND stream_id is non-zero.
  - Reject non-empty channel with stream_id=0 and the inverse.
- Update driver handling to reject invalid requests and return shared streams.
- Update ConsumerConfig semantics (stream IDs are plain `uint32`, 0 = unassigned).

## Phase 7: SHM URI Security and Hugepage Rules ☑
- Enforce filesystem path-only semantics for `shm:file` (Windows named SHM out of scope).
- Add/verify no-follow open and post-open handle validation (TOCTOU/symlink protection).
- Reject `require_hugepages=true` on platforms without reliable verification.

## Phase 8: Tests, Examples, Benchmarks ☑
- Update unit tests for SlotHeader/TensorHeader, progress, and clock domain behavior.
- Update bridge/ratelimiter tests and examples to use SlotHeader + embedded TensorHeader.
- Update system benchmarks if they reference removed symbols.
- Re-run allocation tests to confirm no new allocations in hot paths.

## Phase 9: Documentation Sync ☑
- Update `docs/IMPLEMENTATION_PHASES.md` and any examples/diagrams to reflect SlotHeader/TensorHeader.
- Ensure spec-derived documentation is consistent with updated per-consumer stream rules and announce clock domain.

## Tooling / Commands
- Regenerate code: `julia --project -e 'using Pkg; Pkg.build("AeronTensorPool")'`
- Run tests: `julia --project -e 'using Pkg; Pkg.test()'`
