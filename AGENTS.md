# Aeron Tensor Pool Agents (Julia)

Operational guidance for implementing the agents described in the SHM Tensor Pool spec (v1.1) using Julia (Aeron.jl, SBE.jl, Agent.jl). See the normative spec: [SHM_Aeron_Tensor_Pool.md](SHM_Aeron_Tensor_Pool.md). Key normative sections: algorithms (§15.19), state machines (§15.21), backend validation (§15.22). Roles map to the spec: producer (server/driver) owns SHM and publishes descriptors/control; consumer (client) maps SHM and subscribes. Packaging both roles together or separately is an implementation choice.

## Roles
- **Producer Agent**: Owns SHM regions, publishes `FrameDescriptor` (+ optional `FrameProgress`), and emits announce/metadata/QoS. Single writer for header/payload regions.
- **Supervisor Agent**: Tracks announces, epochs, and liveness; issues `ConsumerConfig`; aggregates QoS; can force modes (STREAM/LATEST/DECIMATED) and fallback URIs.
- **Consumer Agent**: Subscribes to descriptors (and optional progress), mmap SHM, validates superblocks, reads headers/payloads via seqlock.
- **Bridge Agent** (optional): Subscribes to descriptors + SHM, republishes payload over Aeron UDP or records to disk; used for remote/non-SHM consumers.
- **Decimator/Tap Agent** (optional): Consumes STREAM, republishes DECIMATED/LATEST; may suppress progress for dropped frames.

## Lifecycles (Agent.jl pattern)
- **Init**: load config; build SBE codecs; open Aeron client; allocate or mmap SHM (producer only); write/validate superblocks; start periodic timers.
- **Work loop**: poll Aeron, process inbound messages, perform role-specific work, emit outbound messages; avoid allocations in hot path.
- **Idle/backoff**: use `idlenanos` style backoff similar to Agrona; jitter timers to avoid synchronization spikes.
- **Shutdown**: stop publications/subscriptions; fsync and optionally unlink SHM on clean exit (producer); close Aeron client.

## Streams & Templates (align with spec)
- Descriptor: `FrameDescriptor` (IPC) — required for consumers/bridge/decimator.
- Control: `ShmPoolAnnounce`, `ConsumerHello`, `ConsumerConfig`, `ControlResponse`, optional `Heartbeat`.
- QoS: `QosProducer`, `QosConsumer`.
- Metadata: `DataSourceAnnounce`, `DataSourceMeta`, optional blob messages if added.
- Progress (optional): `FrameProgress` when consumers advertise `supports_progress=true`.

## Producer Agent specifics
- Allocate header ring (256-byte slots) and payload pools (fixed stride, same `nslots`), write superblocks, publish `ShmPoolAnnounce` (1 Hz recommended).
- v1.1 canonical identity: `frame_id` in the header, `FrameDescriptor.seq`, and any `FrameProgress.frame_id` MUST be equal for the same frame; producers must write them identically.
- Superblock: 64 bytes fixed; magic `TPOLSHM1` (0x544F504C53484D31 LE); include epoch, layout_version, pid, start_timestamp_ns, activity_timestamp_ns.
- On each frame (normative algorithm §15.19):
  1) `header_index = seq & (nslots - 1)`.
  2) `commit_word = (frame_id << 1) | 1` (store release/relaxed).
  3) Fill payload bytes; ensure visibility (flush DMA if needed).
  4) Fill header (frame_id=seq, shape/strides, pool/slot, meta_version, etc.).
  5) `commit_word = (frame_id << 1)` (store release).
  6) Publish `FrameDescriptor`; optionally `FrameProgress COMPLETE`.
- Progress throttling: emit only if any subscriber supports progress; apply min interval/byte deltas from consumers but not below producer floor (defaults: 250 µs interval, 64 KiB byte delta, rows delta unset).
- Activity timestamp: refresh `activity_timestamp_ns` in superblocks at announce cadence (1 Hz); supervisors timeout at 3–5× cadence.
- Epoch increment: bump on restart or layout change (nslots, slot size, stride classes, superblock size); reset seq/frame_id to 0.

## Consumer Agent specifics
- Map SHM URIs from `ShmPoolAnnounce`; backend validation (§15.22): reject unknown schemes, verify hugepages if `require_hugepages=true`, validate stride_bytes is power-of-two and multiple of page size.
- Validate superblocks: magic=`TPOLSHM1`, layout_version, epoch, nslots, slot_bytes=256, stride_bytes, region_type, pool_id, little-endian only.
- State machine (§15.21): UNMAPPED → MAPPED(epoch); remap on epoch change, drop all in-flight frames on transition.
- On `FrameDescriptor` (normative algorithm §15.19): validate epoch, compute header_index, seqlock protocol:
  1) Read `commit_word` (acquire); odd? DROP.
  2) Read header + payload.
  3) Re-read `commit_word` (acquire); changed or odd? DROP (count `drops_late`).
  4) Accept only if commit_word unchanged, even, AND header `frame_id` == `FrameDescriptor.seq`; otherwise DROP.
- Track `drops_gap` (seq gaps) and `drops_late` (seqlock failures) for `QosConsumer`; optional `max_outstanding_seq_gap` (default: 256 frames) to trigger resync.
- Modes:
  - STREAM: process all descriptors.
  - LATEST: keep newest only (evict older pending work).
  - DECIMATED: process every Nth (per `decimation`); MAY ignore progress for dropped frames.
- Remap on epoch/layout mismatch (§15.19 remap algorithm); fallback to payload_fallback_uri if provided and SHM rejected.
- FrameDescriptor remains the canonical “frame available” signal; consumers MUST NOT treat `FrameProgress` (including COMPLETE) as a substitute. Producers MAY omit `FrameProgress` entirely.

## Supervisor Agent specifics
- Subscribe to announce/QoS/metadata; detect stale `activity_timestamp_ns` or missing announces; command remap.
- Issue `ConsumerConfig` (mode, decimation, fallback URIs); arbitrate consumer IDs and detect collisions.
- Aggregate QoS to flag slow/stale consumers or producer issues; optionally instruct bridge usage for remote nodes.

## Bridge Agent specifics
- Subscribe to descriptors + SHM; validate commit_word; republish payload over Aeron UDP (or other scheme) with its own descriptors/QoS.
- Preserve seq/frame identity; maintain epoch/layout_version for the bridge stream.
- Maintain commit_word discipline on read before republishing; drop frames that fail seqlock or identity checks (frame_id vs seq) to avoid propagating torn data.
- Remap on epoch change; drop in-flight frames on transition; publish bridge-side epoch/layout in its own announces.

## Testing checklist (§15.13)
- Superblock/URI validation fails closed (magic/layout/version/endianness; reject unknown schemes; enforce hugepage/stride rules from §15.22).
- Seqlock prevents torn reads; commit_word monotonic; drop if commit_word regresses or frame_id != FrameDescriptor.seq.
- Epoch change triggers remap; drop in-flight frames; header_index reuse guarded by frame_id==seq.
- Progress gating: none emitted when no subscriber supports it; throttling respected (interval/byte/row deltas).
- Fallback path works when SHM invalid/unsupported (unknown scheme, failed hugepage validation, bad stride_bytes).
- Magic `TPOLSHM1` (0x544F504C53484D31 LE) required; mismatches force remap/reject.

## Operational defaults (tunable)
- Announce cadence: 1 Hz; liveness timeout: 3–5× cadence.
- Progress defaults: interval 250 µs, bytes delta 64 KiB, rows delta unset.
- Header/pool `nslots`: power-of-two sized to cover worst consumer latency × rate with safety factor 2–4.
- Payload stride classes: choose per deployment (e.g., 1 MiB, 4 MiB, 16 MiB on hugepages).

## Dependencies (Julia)
- Aeron.jl for Aeron IPC/UDP publications/subscriptions.
- SBE.jl for code-generated codecs (control plane + SHM composites).
- Agent.jl for single-threaded agents with predictable lifecycle/backoff.
- Mmap stdlib for SHM mapping; ensure correct permissions (umask, group).

## Notes
- SHM layout is little-endian and POD-only; do not store language-managed pointers.
- Keep `TensorSlotHeader256`/superblock structs exactly as in the spec; regenerate SBE bindings when schema changes.
- Pin agents and place SHM on the correct NUMA node when latency matters; set restrictive file modes for SHM paths.
