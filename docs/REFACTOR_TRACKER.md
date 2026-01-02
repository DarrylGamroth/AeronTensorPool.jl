# Refactor Tracker

This tracker lists refactor candidates identified during project review. Items are grouped by area with a short rationale and suggested scope. No code changes implied; this is a planning aid.

## SHM Utilities (Step 1)
- Split `src/shm/shm_io.jl` into focused files.
  - Rationale: seqlock, URI parsing, hugepage checks, path helpers, and encoder wrappers are co-located.
  - Scope: `shm/seqlock.jl`, `shm/paths.jl`, `shm/uri.jl`, `shm/slots.jl`, `shm/superblock.jl`.
  - Risk: minimal if `AeronTensorPool.jl` includes are updated in order.
- Add explicit OS boundary for SHM backends (Linux-first, extensible).
  - Rationale: keep current implementation scoped to Linux/Posix while leaving room for memfd/Windows/macOS.
  - Scope: introduce a small backend interface (e.g., `open_shm`, `mmap_shm`, `mmap_existing`, `check_hugepages`) and provide Linux implementation in `shm/linux/*.jl`.
  - Notes: defer memfd/Windows/macOS support, but keep entry points isolated for later swap-in.
  - Risk: low if kept as an internal abstraction.
  - Status: done.

## Top-Level Module Layout (Step 2)
- Consolidate per-role includes into submodules or role-level entrypoints.
  - Rationale: `src/AeronTensorPool.jl` include list is long and flat.
  - Scope: create `agents/producer/producer.jl` (includes state/handlers/logic), same for consumer/supervisor/driver/bridge/decimator.
  - Risk: low; mostly include order changes.
  - Status: done.

## Core and Types (Step 3)
- Split `src/core/constants.jl` into `constants.jl`, `types.jl`, and `messages.jl`.
  - Rationale: current file mixes constants, SBE aliases, config structs, and runtime types.
  - Scope: move `PayloadPoolConfig`, `ProducerConfig`, `ConsumerSettings`, `SuperblockFields`, `TensorSlotHeader`, `PayloadSlice`, `ConsumerFrameView`, `ShmUri` into `types.jl`; keep SBE aliases and template ids in `messages.jl`; keep numeric constants in `constants.jl`.
  - Risk: export list churn; requires updates to `src/AeronTensorPool.jl` include order.
  - Status: done.

## Naming Consistency (Step 4)
- Rename mutable runtime configs to avoid conflicts with SBE message names.
  - Rationale: `ConsumerConfig` vs `ConsumerConfigMsg` is easy to confuse.
  - Scope: rename `ConsumerConfig` -> `ConsumerSettings` (or `ConsumerRuntimeConfig`); adjust exports and docstrings.
  - Risk: API change; requires downstream updates and docs.
  - Status: done.

## Agent Runtime Structure (Step 5)
- Introduce shared control-plane runtime struct for common pubs/subs/buffers/claims.
  - Rationale: producer/consumer/supervisor/driver share repeated Aeron resources and buffer fields.
  - Scope: new `src/agents/common/runtime.jl` with shared fields; update per-agent `*Runtime` to embed or compose it.
  - Risk: medium; touches many agent states and init paths.
  - Status: done.

## Client Driver Loop (Step 6)
- Replace internal polling loops (`await_attach!`) with externally driven polling.
  - Rationale: keeps time fetch at top of duty cycle and avoids hidden loops.
  - Scope: accept `now_ns` provider or require caller-driven polling; document usage.
  - Risk: API change for client helpers.
  - Follow-up: move `await_attach!` to test helpers (or mark internal) to keep the public API minimal.
  - Status: done (await_attach! moved to test helper, public export removed).

## SHM Pool Lookup (Future)
- Replace `Dict{UInt16, Vector{UInt8}}` with dense vector when pool ids are compact.
  - Rationale: avoids hash lookups in hot paths; simpler indexing.
  - Scope: convert `payload_mmaps` and `pool_stride_bytes` to `Vector{Union{Nothing, ...}}` or `Vector{...}` with `pool_id` offset.
  - Risk: medium; mapping/validation updates needed.
  - Status: future enhancement (defer unless hot-path profiling warrants change).

## Tests and Bench (Step 7)
- Normalize test setup into shared helper functions (embedded driver, client).
  - Rationale: reduce boilerplate and keep client ownership consistent.
  - Scope: extend `test/helpers_aeron.jl` with `with_driver_and_client` pattern.
  - Risk: low; affects test readability only.
  - Status: done.

## Documentation (Ongoing)
- Update implementation docs to match refactor if API names change.
  - Rationale: prevents drift between code and spec docs.
  - Scope: `docs/IMPLEMENTATION.md`, `docs/IMPLEMENTATION_GUIDE.md`, `docs/IMPLEMENTATION_PHASES.md`.
  - Risk: low, but should follow code changes.

## Driver Control Plane Responses (Deferred)
- Consider per-client response channels for driver control responses.
  - Rationale: avoid broadcasting responses to all clients; scales better and aligns with Aeron patterns.
  - Scope: add optional `response_channel`/`response_stream_id` to attach/keepalive/detach requests; driver publishes responses to those when present; shared control channel remains fallback unless a protocol bump mandates responses.
  - Risk: protocol change; may require versioning if made mandatory later.

## API Shape (kwargs vs positional)
- Review public API for keyword argument use and consistency.
  - Rationale: kwargs improve clarity for optional parameters, but can add call-site overhead and inconsistency.
  - Scope: audit exported functions (init_*, emit_*, poll_*, publish_frame!, try_read_frame!, driver client API) and classify:
    - Required parameters → positional.
    - Optional parameters with safe defaults → kwargs.
    - Hot-path calls → prefer positional or small structs for options to avoid kwargs overhead.
  - Risk: potential API changes; requires doc updates and test adjustments.
  - Audit snapshot (current):
    - `init_driver(config; client)` → required `client` currently kwarg; candidate for positional.
    - `init_supervisor(config; client)` → required `client` currently kwarg; candidate for positional.
    - `init_producer(config; client)` → required `client` currently kwarg; candidate for positional.
    - `init_consumer(config; client)` → required `client` currently kwarg; candidate for positional.
    - `init_producer_from_attach(config, attach; driver_client = nothing, client)` → `driver_client` optional, `client` required; consider positional `client` and keep `driver_client` kw.
    - `init_consumer_from_attach(config, attach; driver_client = nothing, client)` → same as above.
    - `init_driver_client(client, control_channel, control_stream_id, client_id, role; keepalive_interval_ns=...)` → good use of kw for optional interval.
    - `emit_consumer_config!(state, consumer_id; use_shm, mode, decimation, payload_fallback_uri)` → good use of kw for optional config overrides.
    - `emit_driver_shutdown!(state, reason=..., error_message="")` → optional args; kw ok (or keep positional defaults).
    - `poll_driver_responses!(poller, fragment_limit=DEFAULT_FRAGMENT_LIMIT)` → default optional; kw ok.
    - `publish_frame!(state, payload, shape, strides, dtype, meta_version)` → all positional; ok for hot path.
    - `payload_slot_view(state, pool_id, slot; len=-1)` → kw optional; ok.
