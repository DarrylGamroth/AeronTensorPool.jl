# RateLimiter Implementation Plan (v1.0)

Spec reference: `docs/SHM_RateLimiter_Spec_v1.0.md` (authoritative).

Goal: Implement a RateLimiter agent that consumes source descriptors/SHM, applies per-consumer rate limits, re-materializes accepted frames into destination SHM pools, and republishes `FrameDescriptor` + optional metadata/progress/QoS per spec.

---

## Phase 0: Survey and scaffolding
- Review current agents for reusable components (consumer read path, producer claim/commit path, metadata forwarders, control/qos pollers).
- Decide module and file placement (likely `src/agents/ratelimiter/` with `RateLimiter.jl`, `state.jl`, `agent.jl`, `receiver.jl`, `config.jl`, `encoders.jl`, `handlers.jl`).
- Add config TOML example under `config/` and document usage.
- Add a plan tracker section to mark status per phase.

Status: completed.

Implementation notes:
- Current implementation enforces a single consumer per mapping; additional `ConsumerHello` updates are ignored.

---

## Phase 1: Config + wiring
- Implement `RateLimiterConfig` and mapping struct with required/optional keys.
- Add config loader for rate limiter (similar style to bridge/driver loaders).
- Validate config invariants:
  - `forward_progress=true` requires nonzero source/dest control IDs.
  - `forward_qos=true` requires nonzero source/dest QoS IDs.
  - `mappings` not empty; mapping stream_ids present.
- Expose constructor defaults per spec (§8).

Status: completed.

---

## Phase 2: Core state + Aeron setup
- Create `RateLimiterState` with:
  - Aeron client, pubs/subs (descriptor, control, QoS, metadata).
  - Per-mapping state: source stream id, dest stream id, rate limit, dest producer state, source consumer state (read-only SHM).
  - Timers (rate slots) and cached clock usage (single `fetch!` per cycle).
- Initialize destination SHM pools and superblocks for each mapping (own producer identity).
- Initialize source subscriptions:
  - Descriptor stream for each mapping.
  - Optional control/QoS streams if forwarding enabled.

Status: completed.

---

## Phase 3: Rate limiting + re-materialization
- Implement mapping-level accept/drop policy:
  - `max_rate_hz == 0` => unlimited.
  - Otherwise accept at most 1 frame per slot; publish most recent frame available when slot opens.
  - Reset timer on start and on source epoch change.
- On accept:
  - Seqlock read source header+payload (reuse consumer helpers).
  - Select destination pool (smallest stride >= payload length).
  - `try_claim_slot!` in destination producer; drop if claim fails.
  - Write payload and slot header, commit, publish destination `FrameDescriptor`.
  - Preserve `meta_version` and `timestamp_ns`; copy `seq` from source.
- Ensure all drop paths are non-blocking and allocation-free after init.

Status: completed.

---

## Phase 4: Metadata / Progress / QoS forwarding
- Metadata forwarding (when enabled):
  - Subscribe source metadata stream; republish announce/meta with `stream_id` rewritten to destination stream.
  - Honor per-mapping `metadata_stream_id` override.
- Progress forwarding (optional):
  - Subscribe source control stream; republish `FrameProgress` on dest control stream.
  - Rewrite `stream_id` to destination; preserve `seq`, `frame_id`, payload fields.
- QoS forwarding (optional):
  - Subscribe source QoS stream; republish QoS on dest QoS stream.
  - Rewrite `stream_id` to destination; preserve remaining fields.

Status: completed.

---

## Phase 5: Agent integration + lifecycle
- Implement agent hooks (`Agent.on_start`, `Agent.do_work`, `Agent.on_close`).
- Use `PolledTimer` for rate slots and periodic tasks.
- Ensure shutdown and resource cleanup aligns with other agents.

Status: completed.

---

## Phase 6: Tests
- Unit tests:
  - Rate limiter accepts/drops per `max_rate_hz`.
  - Rematerialization writes correct headers and payloads.
  - Source epoch change resets rate timer.
  - Forwarding paths rewrite `stream_id` correctly.
- Integration tests:
  - Producer -> RateLimiter -> Consumer (same process, embedded driver).
  - Optional: progress/QoS forwarding on/off.
- Allocation tests on hot paths after initialization.

Status: completed.

---

## Phase 7: Examples + docs
- Add `scripts/example_rate_limiter.jl` (or integrate into existing examples).
- Document usage in `USER_GUIDE.md` and reference config file in `config/`.
- Add to `AGENTS.md` and update stream ID conventions if needed.

Status: completed.
