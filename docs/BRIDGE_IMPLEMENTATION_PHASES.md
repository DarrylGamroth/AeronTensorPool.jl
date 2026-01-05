## Bridge Implementation Phases

The bridge specification is the authoritative source of truth; this plan only tracks implementation work.

### Status Snapshot
- Bridge sender/receiver core is implemented (chunking, rematerialization, metadata/QoS/progress forwarding hooks).
- BridgeAgent exists but only supports a single mapping per agent instance.
- Config loader supports `BridgeConfig` + mappings, but no multi-mapping runner/agent wiring.

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

### Phase 1: Config + Validation Hardening
- Validate bridge config and mappings:
  - Enforce `source_control_stream_id`/`dest_control_stream_id` when `forward_qos` or `forward_progress` is true.
  - Validate `payload_channel`, `payload_stream_id`, `control_channel`, and `control_stream_id` nonzero.
  - Validate per-mapping `source_stream_id`/`dest_stream_id` uniqueness and no feedback loops.
  - Validate MTU/chunk sizing (chunk_bytes <= mtu-derived max if configured).
  - Validate `max_payload_bytes` against pool strides and system limits.
- Add a validation helper for bridge config (similar to discovery validation).
- Ensure config defaults match spec and docs/examples.

### Phase 2: Sender Compliance
- Gate forwarding by config flags:
  - Only forward QoS/FrameProgress when enabled.
  - Only forward metadata when enabled (already partially enforced by presence of metadata pub).
- Ensure ShmPoolAnnounce forwarding:
  - Stream ID rewrite to `dest_stream_id`.
  - Preserve epoch/layout/max_dims.
  - Forward payload pool entries unchanged except stream ID.
- Verify header/payload chunking:
  - Enforce headerBytes presence only on first chunk.
  - Validate `chunkCount` and `payloadLength` derivation against spec.
- Ensure per-consumer control/descriptor streams honor rate limiting (max_rate_hz) when forwarding descriptors.

### Phase 3: Receiver Compliance + Robustness
- Apply forwarded ShmPoolAnnounce for validation:
  - Validate payload pool stride/pool IDs before rematerialization.
  - Enforce `max_dims` and `layout_version` checks per spec.
- FrameProgress forwarding on receiver:
  - Rewrite `stream_id` to `dest_stream_id`.
  - Validate or remap `headerIndex` to local mapping; drop if mismatched per spec.
- Assembly timeout:
  - On timer expiry, drop partial assembly and reset cleanly.
  - Ensure epoch/seq change resets assembly immediately.
- Ensure all SBE decoding respects field order and handles missing header correctly.
- Define error handling policy:
  - Invalid chunks → drop and optionally reset assembly (documented behavior).
  - `try_claim` failures → drop with counter, avoid retries in hot path.

### Phase 4: Multi-Mapping Bridge Agent
- Implement a `BridgeSystemAgent` (or equivalent) that:
  - Loads `BridgeSystemConfig` with N mappings.
  - Builds per-mapping sender/receiver states sharing one Aeron client.
  - Polls subscriptions per mapping with clear work accounting.
  - Provides counters per mapping (prefix with `dest_stream_id` or mapping name).
- Keep existing `BridgeAgent` as a single-mapping convenience wrapper.
- Decide whether per-mapping senders/receivers should share pubs/subs or allocate separate ones.
- Define shutdown ordering for multi-mapping agent cleanup.

### Phase 5: Tests + Examples
- Add integration tests:
  - Forwarded announce → receiver validation.
  - QoS/FrameProgress forwarding with headerIndex mapping.
  - Assembly timeout drop/reset path.
  - Bidirectional mappings with feedback loop protection.
  - Discovery integration: ensure bridged streams can be discovered via the Discovery service and that forwarded announces/metadata are visible to discovery.
  - Backpressure: simulate `try_claim` failures and assert counters/behavior.
- Add metrics tests (chunks sent/dropped, assemblies reset, frames rematerialized).
- Add allocation-free checks for bridge sender/receiver hot paths.
- Add a multi-mapping example config and runner script.
- Extend bridge benchmarks (optional) for chunking and rematerialization throughput.

### Phase 6: Docs + Ops
- Update `docs/IMPLEMENTATION.md` Bridge section with:
  - Multi-mapping setup instructions.
  - Config validation rules and error behavior.
  - Operational notes (MTU, chunk sizing, control channel usage).
  - Discovery visibility expectations for bridged streams.
  - Document schema/version compatibility expectations.
- Add a short CLI/tooling note for bridge status/health inspection.
- Add a short troubleshooting section for common bridge misconfigurations.
