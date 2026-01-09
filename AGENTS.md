# Aeron Tensor Pool Agents (Julia)

Reference implementation overview for the AeronTensorPool agents and control-plane wiring.
This document is authoritative for code organization and intended runtime structure; it should
match the current code layout in `src/` and the wire/driver specs in `docs/`.

## Specs and docs
- Wire spec: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- Driver model spec: `docs/SHM_Driver_Model_Spec_v1.0.md`
- Bridge spec: `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md`
- Discovery spec: `docs/SHM_Discovery_Service_Spec_v_1.0.md`
- Rate limiter spec: `docs/SHM_RateLimiter_Spec_v1.0.md`
- Implementation guides: `docs/IMPLEMENTATION.md`, `docs/IMPLEMENTATION_GUIDE.md`
- Stream ID conventions (authoritative for defaults/ranges): `docs/STREAM_ID_CONVENTIONS.md`

## Design constraints
- Steady-state must be type-stable and zero-allocation after initialization.
- Preallocate buffers and avoid runtime dispatch in hot paths.
- Use seqlock protocol for header/payload consistency.
- Use `with_claimed_buffer!` + SBE encoders for Aeron publishes (no offer+copy in hot paths).

## Key packages
- Aeron.jl: Context/Client, publications/subscriptions, FragmentAssembler, poll
- SBE.jl: generated codecs (wrap!/wrap_and_apply_header!, Encoder/Decoder accessors, groups)
- Clocks.jl: MonotonicClock + CachedEpochClock
- Agent.jl: agent loop + poller patterns (optional)
- Hsm.jl: driver state machine (used for driver lifecycle/lease tracking)

## Repository layout (current)
- `src/aeron/`: Aeron helpers (try_claim, assemblers, counters)
- `src/control/`: control-plane primitives (proxies, pollers, shared runtime)
- `src/client/`: driver client API (attach/keepalive/detach polling)
- `src/config/`: TOML/env config loading and path resolution
- `src/timers/`: polled timers and timer sets
- `src/agents/driver/`: driver implementation (streams/leases/encoders/handlers)
- `src/agents/producer/`: producer agent
- `src/agents/consumer/`: consumer agent
- `src/agents/supervisor/`: supervisor agent
- `src/agents/bridge/`: bridge agent (UDP/IP payload forwarding)
- `src/agents/discovery/`: discovery provider + registry agents
- `src/shm/`: SHM mapping, seqlock, superblock, slot helpers
- `src/discovery/`: discovery client/types/validation
- `src/core/`: shared types/constants/messages/errors

## Agent roles (v1.1)

### Producer
- Owns SHM header ring + payload pools; publishes descriptors + QoS + metadata.
- Publishes: `ShmPoolAnnounce`, `FrameDescriptor`, optional `FrameProgress`, `QosProducer`, `DataSourceAnnounce`, `DataSourceMeta`.
- Subscribes: `ConsumerHello` and `QosConsumer` (control/QoS stream).
- Core loop: write payload → header → commit seqlock → publish descriptor.

### Consumer
- Owns subscriptions; maps SHM read-only.
- Publishes: `ConsumerHello`, `QosConsumer`.
- Subscribes: `FrameDescriptor`, optional `FrameProgress`, `ShmPoolAnnounce`, `ConsumerConfig`, `DataSourceMeta`.
- Core loop: poll descriptor → seqlock read → validate → process → QoS tracking.

### Supervisor
- Observes producers/consumers; may issue `ConsumerConfig` updates.
- Publishes: `ConsumerConfig` (control plane).
- Subscribes: `ShmPoolAnnounce`, `ConsumerHello`, `QosProducer`, `QosConsumer`.
- Core loop: liveness checks + QoS aggregation.

### Driver
- Owns control-plane SHM attach/detach/lease lifecycle; issues `ShmPoolAnnounce`.
- Publishes: `ShmAttachResponse`, `ShmDetachResponse`, `ShmLeaseRevoked`, `ShmDriverShutdown`.
- Subscribes: `ShmAttachRequest`, `ShmDetachRequest`, `ShmLeaseKeepalive`, `ShmDriverShutdownRequest`.
- Core loop: control-plane poll + timer-driven lease and announce handling.

### Bridge (optional)
- Re-materializes or forwards payloads over Aeron UDP/IPC using `BridgeFrameChunk`.
- Publishes: `BridgeFrameChunk`, forwarded control/QoS/metadata (if enabled).
- Subscribes: `FrameDescriptor`, `ShmPoolAnnounce`, control/QoS/metadata as configured.

### Discovery Provider (optional)
- Advisory inventory for available streams; does not grant attach authority.
- Publishes: `DiscoveryResponse`.
- Subscribes: `ShmPoolAnnounce`, metadata (as configured), `DiscoveryRequest`.

### Discovery Registry (optional)
- Aggregates multiple driver endpoints and serves discovery requests.
- Publishes: `DiscoveryResponse`.
- Subscribes: `ShmPoolAnnounce`, metadata, `DiscoveryRequest`.

### RateLimiter (optional)
- Consumes a source stream, rate-limits, re-materializes into local SHM, republishes on a destination stream.
- Publishes: `FrameDescriptor`, optional `FrameProgress`, forwarded metadata/QoS (if enabled).
- Subscribes: `FrameDescriptor`, `FrameProgress`, QoS/metadata as configured.

## Agent file structure (current)
Each agent follows the same organization for readability:
- `state.jl`: runtime/state structs
- `handlers.jl`: fragment handlers and message handling logic
- `init.jl`: init routines (Aeron setup, SHM mapping)
- `lifecycle.jl`: attach/remap/driver lifecycle handling
- `work.jl`: `*_do_work!` loop and timer polling
- `frames.jl`/`mapping.jl`/`proxy.jl` where applicable
- Bridge adds `assembly.jl` and `adapters.jl` for payload forwarding

## Control-plane API
- Use `with_claimed_buffer!` for Aeron publishes.
- `src/control/` houses proxies, pollers, and `ControlPlaneRuntime`.
- `src/client/driver_client.jl` provides `DriverClientState` + helper pollers.
- `src/discovery/discovery_client.jl` provides discovery request/response helpers.

## SHM utilities
- `src/shm/seqlock.jl`: seqlock read/write helpers
- `src/shm/superblock.jl`: `SuperblockFields`, read/write helpers
- `src/shm/slots.jl`: `TensorSlotHeader`, slot offsets, payload views
- `src/shm/uri.jl`: `ShmUri` parsing + validation

## Runtime loop conventions
- Fetch clock at top of each `*_do_work!` cycle; use cached time for the cycle.
- Use work_count rather than boolean flags for pollers.
- Prefer `try_claim` over `offer` for small control messages.

## Integration pitfalls (recent findings)
- Mixed schema traffic: control/QoS/metadata can share a channel; always guard on `MessageHeader.schemaId` (or `DriverMessageHeader.schemaId`) before decoding to avoid SBE template/schema mismatch errors.
- Embedded TensorHeader decode: `SlotHeader.headerBytes` includes a `MessageHeader`; use the default `TensorHeaderMsg.wrap!` when decoding (and `wrap_and_apply_header!` only on the write path).
- Regenerate codecs after spec/schema edits: run `julia --project -e 'using Pkg; Pkg.build(\"AeronTensorPool\")'` to avoid stale schema/version mismatches.
- Producer startup: wait for descriptor publication connectivity before sending frames; `try_claim` returns `-1` when no consumer is connected.
- Julia naming: prefer fully qualified names in tests and agent code to avoid ambiguity from unqualified imports.

## Scripts
- `scripts/run_role.jl`: run a single role with a config
- `scripts/run_all.sh` / `scripts/run_all_driver.sh`: multi-role local runs
- `scripts/run_driver.jl`: run the driver from a config
- `scripts/run_driver_smoke.jl`, `scripts/run_system_smoke.jl`: smoke tests
- `scripts/run_benchmarks.jl`: benchmark runner
- `scripts/run_tests.jl` / `scripts/run_tests.sh`: test runners
- `scripts/tp_tool.jl`: control-plane CLI helpers

## Codegen
- Regenerate SBE codecs with `julia --project -e 'using Pkg; Pkg.build("AeronTensorPool")'`.

## Notes
- Bridge, discovery, and rate limiter are optional; current focus is wire-level correctness and zero-allocation hot paths.
- Driver and client are both implemented in Julia; the driver is expected to remain in Julia even if
  a C client is added later.
