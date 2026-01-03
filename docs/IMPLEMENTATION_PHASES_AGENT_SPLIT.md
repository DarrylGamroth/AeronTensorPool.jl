# Agent Logic Split Phases

Goal: split large `logic.jl` files into clearer adapter/proxy/mapping/frames units while preserving public API and zero‑allocation hot paths. This is a code-organization refactor only.

Terminology:
- Adapter: subscription poll + fragment assembly + decode + dispatch glue.
- Handler: per-message function (e.g., `handle_shm_pool_announce!`).
- Proxy: outbound encoder + `try_claim`/`offer` helpers.

## Scope
- Agents: consumer, producer, bridge, supervisor (optional), driver (no changes expected).
- Keep existing public function names and call sites stable unless explicitly noted.
- Preserve allocation-free behavior in hot paths; re-run allocation tests after each phase.

## Phase A0: Baseline and Guardrails
Status: completed.
- Confirm current test/benchmark baselines (record in `docs/BENCHMARK_BASELINE.md` if needed).
- Identify hot-path functions to avoid moving across modules unless required.
- Add or update brief module-level comments describing adapter/proxy roles per agent.

## Phase A1: Consumer Split
Status: completed.
- Create files:
  - `src/agents/consumer/mapping.jl` (map/remap/validate SHM, superblock checks, fallback).
  - `src/agents/consumer/frames.jl` (seqlock reads, `try_read_frame!`, view shaping).
  - `src/agents/consumer/proxy.jl` (emitters and outbound encoders).
- Move functions without changing signatures.
- Update `src/agents/consumer/consumer.jl` includes in dependency order.
- Ensure handler/adapters in `handlers.jl` still call into `mapping`/`frames` correctly.
- Run unit tests for consumer and allocation tests.

## Phase A2: Producer Split
Status: completed.
- Create files:
  - `src/agents/producer/shm.jl` (mmap + superblock initialization).
  - `src/agents/producer/frames.jl` (frame publish, header write, seqlock, pool select).
  - `src/agents/producer/proxy.jl` (announce/QoS/progress/config emitters).
- Keep `handlers.jl` as adapter and `logic.jl` as orchestration.
- Update `src/agents/producer/producer.jl` includes.
- Run producer tests and allocation checks.

## Phase A3: Bridge Split
Status: completed.
- Create files:
  - `src/agents/bridge/sender.jl` (sender init, chunking, forwarders).
  - `src/agents/bridge/receiver.jl` (receiver init, assembly, publish to SHM).
  - `src/agents/bridge/assembly.jl` (chunk assembly state + helpers).
  - `src/agents/bridge/proxy.jl` (control/QoS/progress/metadata emitters).
  - `src/agents/bridge/adapters.jl` (FragmentAssembler builders, pollers).
- Keep `logic.jl` as orchestration/glue or replace with thin `bridge.jl` + `state.jl` if cleaner.
- Re-run bridge integration tests.

## Phase A4: Supervisor (Optional)
Status: not needed (kept as-is).
- If desired, move emitters to `proxy.jl`; otherwise keep as-is.
- Ensure no API or behavior changes.

## Phase A5: Documentation and Consistency
Status: completed.
- Update `docs/IMPLEMENTATION.md` with adapter/proxy structure for agents.
- Update `docs/REFACTOR_TRACKER.md` or add a note in `docs/IMPLEMENTATION_PHASES.md` referencing this split plan.
- Ensure any developer docs (e.g., `INTEGRATION_EXAMPLES.md`) still point to correct locations.

## Phase A6: Final Validation
Status: completed.
- Run full test suite and allocation checks.
- Confirm no new allocations in hot paths.
- Record results in `docs/BENCHMARK_BASELINE.md` if changed.
