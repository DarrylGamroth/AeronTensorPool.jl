## Bridge Implementation Phases

The bridge specification is the authoritative source of truth; this plan only tracks implementation work.

### Status Snapshot
- Bridge sender/receiver core is implemented (chunking, rematerialization, metadata/QoS/progress forwarding).
- `BridgeSystemAgent` supports multiple mappings with per-mapping counters.
- Config loader validates `BridgeConfig` + mappings and enforces MTU/chunk sizing rules.
- Integration tests cover progress remap, assembly timeout, backpressure, and discovery visibility.

### Spec Update Mapping (Bridge v1.0 refresh)
- §4 stream allocation alignment: **implemented**. Added `dest_stream_id_range`, allocation for `dest_stream_id=0`, and overlap checks.
- §5.2 chunk validation: **implemented**. Sender populates `chunkOffset`/`chunkLength`; receiver validates offsets/lengths and per-chunk size limits.
- §6 rematerialization: **implemented**. Receiver drops chunks whose epoch mismatches the latest forwarded announce before assembly.
- §7.1 metadata forwarding: **implemented**. Stream id rewrite and `meta_version` preservation present in sender/receiver proxy.
- §7.2 control channel: **implemented**. Control channel uses wire schema messages and gated by `forward_qos`/`forward_progress`.
- §9 progress forwarding: **implemented**. Receiver derives the local header index from `frame_id` before publish.
- §10 defaults: **implemented**. Config loader defaults match spec; chunk sizing uses MTU minus 128 and caps with `max_chunk_bytes`.

Status: pending audit.

### Implementation Tasks (from audit)
Status: completed.

### Phase 0: Spec Alignment Checklist
- Map each normative requirement in `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md` to a code path or TODO.
- Identify gaps in:
  - `forward_qos`/`forward_progress` gating.
  - HeaderIndex mapping/validation for FrameProgress.
  - Announce forwarding rules and rewriting.
  - Assembly timeout behavior and recovery.
  - Discovery integration visibility (what discovery should see for bridged streams).
  - Backpressure behavior on `try_claim` failures.
  - Error handling policy for invalid chunks.
  - Schema/version compatibility handling (reject vs warn).
  - Discovery registry visibility expectations (provider vs registry).
  - Logging policy (INFO/WARN) for invalid chunks, backpressure, and version mismatches.
- Produce a short checklist table with spec section → implementation file/function.

Spec mapping (key items):
- §7.2/§10 control channel forwarding: `src/agents/bridge/adapters.jl`, `src/agents/bridge/proxy.jl`.
- §8 chunking rules: `src/agents/bridge/sender.jl`, `src/agents/bridge/assembly.jl`.
- §9 progress rewrite/remap: `src/agents/bridge/proxy.jl`, `src/agents/bridge/receiver.jl`.
- §9 invalid config/drop behavior: `src/core/validation.jl`, `src/agents/bridge/receiver.jl`.
- §11 schema usage: `src/gen/ShmTensorpoolBridge.jl`, `src/agents/bridge/*`.

Status: completed.

### Phase 1: Config + Validation Hardening
- Validate bridge config and mappings:
  - Enforce `source_control_stream_id`/`dest_control_stream_id` when `forward_qos` or `forward_progress` is true.
  - Validate `payload_channel`, `payload_stream_id`, `control_channel`, and `control_stream_id` nonzero.
  - Validate per-mapping `source_stream_id`/`dest_stream_id` uniqueness and no feedback loops.
  - Validate MTU/chunk sizing (chunk_bytes <= mtu-derived max if configured).
  - Validate `max_payload_bytes` against pool strides and system limits.
- Add a validation helper for bridge config (similar to discovery validation).
- Ensure config defaults match spec and docs/examples.

Status: completed.

### Phase 2: Sender Compliance
- Gate forwarding by config flags:
  - Only forward QoS/FrameProgress when enabled.
  - Only forward metadata when enabled (already partially enforced by presence of metadata pub).
- Ensure ShmPoolAnnounce forwarding:
  - Stream ID rewrite to `dest_stream_id`.
  - Preserve epoch/layout and use MAX_DIMS from the schema constant.
  - Forward payload pool entries unchanged except stream ID.
- Verify header/payload chunking:
  - Enforce headerBytes presence only on first chunk.
  - Validate `chunkCount` and `payloadLength` derivation against spec.
- Ensure per-consumer control/descriptor streams honor rate limiting (max_rate_hz) when forwarding descriptors.

Status: completed.

### Phase 3: Receiver Compliance + Robustness
- Apply forwarded ShmPoolAnnounce for validation:
  - Validate payload pool stride/pool IDs before rematerialization.
  - Enforce `layout_version` checks per spec; MAX_DIMS is fixed by the schema constant.
- FrameProgress forwarding on receiver:
  - Rewrite `stream_id` to `dest_stream_id`.
  - Validate or derive local header index from `frame_id`; drop if mismatched per spec.
- Assembly timeout:
  - On timer expiry, drop partial assembly and reset cleanly.
  - Ensure epoch/seq change resets assembly immediately.
- Ensure all SBE decoding respects field order and handles missing header correctly.
- Define error handling policy:
  - Invalid chunks → drop and optionally reset assembly (documented behavior).
- `try_claim` failures → drop with counter, avoid retries in hot path.

Status: completed.

### Phase 4: Multi-Mapping Bridge Agent
- Implement a `BridgeSystemAgent` (or equivalent) that:
  - Loads `BridgeSystemConfig` with N mappings.
  - Builds per-mapping sender/receiver states sharing one Aeron client.
  - Polls subscriptions per mapping with clear work accounting.
  - Provides counters per mapping (prefix with `dest_stream_id` or mapping name).
- Keep existing `BridgeAgent` as a single-mapping convenience wrapper.
- Decide whether per-mapping senders/receivers should share pubs/subs or allocate separate ones.
- Define shutdown ordering for multi-mapping agent cleanup.

Status: completed.

### Phase 5: Tests + Examples
- Add integration tests:
  - Forwarded announce → receiver validation.
  - QoS/FrameProgress forwarding with derived header index.
  - Assembly timeout drop/reset path.
  - Bidirectional mappings with feedback loop protection.
  - Discovery integration: ensure bridged streams can be discovered via the Discovery service and that forwarded announces/metadata are visible to discovery.
  - Backpressure: simulate `try_claim` failures and assert counters/behavior.
- Add metrics tests (chunks sent/dropped, assemblies reset, frames rematerialized).
- Add allocation-free checks for bridge sender/receiver hot paths.
- Add a multi-mapping example config and runner script.
- Extend bridge benchmarks (optional) for chunking and rematerialization throughput.
  - Implemented: `scripts/run_benchmarks.jl --bridge` or `scripts/run_benchmarks.jl --bridge-runners`.

Status: completed (benchmarks added).

### Phase 6: Docs + Ops
- Update `docs/IMPLEMENTATION.md` Bridge section with:
  - Multi-mapping setup instructions.
  - Config validation rules and error behavior.
  - Operational notes (MTU, chunk sizing, control channel usage).
  - Discovery visibility expectations for bridged streams.
  - Document schema/version compatibility expectations.
- Add a short CLI/tooling note for bridge status/health inspection.
- Add a short troubleshooting section for common bridge misconfigurations.

Status: completed.
