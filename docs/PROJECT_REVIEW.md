# Project Review (Aeron Tensor Pool)

This document summarizes the current implementation against the spec and highlights gaps and follow-on work.

## Spec Compliance
- Core producer/consumer/supervisor flows align with §15.19 and §15.21; SHM superblocks, seqlock protocol, and descriptor publishing are implemented and tested.
- Consumer validation follows §15.22 (URI scheme, hugepages, stride alignment) and rejects invalid regions; fallback is supported.
- Progress gating and QoS cadence follow spec guidance; FrameProgress remains optional.
- Canonical identity (frame_id == seq) is enforced; drops and resync logic are present.

Open points:
- Bridge/decimator are scaffold-only until a wire format is finalized.
- No explicit handling for big-endian platforms beyond SBE’s default (acceptable per spec note).

## Julia Style
- Mostly idiomatic: structs with concrete fields, explicit init functions, and separation of hot paths.
- Some shared helpers are manual rather than leveraging traits; acceptable for performance clarity.

## Naming Consistency
- Most naming aligns with roles and spec: `emit_*`, `poll_*`, `*_do_work!`.
- Agent wrappers are split per role; counter names follow AeronStat-style labels.
- Minor inconsistencies: `ProducerCounters` uses `frames_published`, `announce_emits` naming in state; could be normalized to `*_count` or `*_emits` consistently.

## Types and Multiple Dispatch
- Core types are concrete and avoid `Any` in hot paths.
- Multiple dispatch is used for encoders/decoders and helper functions; not heavily trait-based, which is fine for clarity and performance.
- Where `Union{Nothing, Vector{UInt8}}` is used (e.g., `header_mmap`), access is guarded to keep hot paths type-stable.

## Type Stability
- Hot paths are intended to be type-stable; allocation tests cover superblock/header encode/decode and descriptor encode.
- Seqlock read path in `try_read_frame!` uses concrete structs and vectors; no obvious dynamic dispatch.
- Agent counter updates are stable; SBE encoders are reused.

## Clock Usage
- `*_do_work!` fetches time once per duty cycle and passes it to timer polling.
- Within frame publish/read paths, timestamps are taken directly when needed; this is consistent with spec requirements.
- Periodic emits use the shared `now_ns` for timers but may call `Clocks.time_nanos` for message timestamps; acceptable.

## Error Handling
- Most errors result in drops and continue (consumer), or log and continue (supervisor).
- Init-time errors throw (e.g., invalid nslots, invalid URIs).
- Agent `on_close` uses a single try/catch to avoid secondary failures.

## Error Severity and Fatality
- Data plane errors are non-fatal by design; they increment counters and continue.
- Mapping or validation failures trigger remap or fallback; if fallback unavailable, consumer remains unmapped.
- No global fatal error policy; a failure to init remains fatal.

## Exception Hierarchy
- Not currently implemented. This is acceptable, but a lightweight hierarchy could improve diagnostics (e.g., `ShmValidationError`, `AeronInitError`).
- Recommendation: add only if operational tooling needs structured error classification.

## Allocation Behavior
- Hot-path encode/decode allocation tests exist; load tests show zero allocations in loops.
- End-to-end loops should be allocation-free after init except for occasional Aeron/JIT allocations and when new consumers remap.
- Per-consumer remap and fallback can allocate (mapping new regions), which is expected.

## Suggested Follow-on Phases
1) Phase 9 – Observability and Error Taxonomy
   - Optional exception hierarchy for init/mapping failures.
   - Structured logging fields and counter documentation.
2) Phase 10 – Bridge/Decimator Completion
   - Define wire format, implement full bridge/decimator tests.
3) Phase 11 – Operational Playbooks
   - Deployment profiles, tuning knobs, and troubleshooting guides.
