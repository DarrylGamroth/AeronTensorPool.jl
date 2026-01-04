# Aeron Tensor Pool Agents (Julia)

Reference implementation overview for the AeronTensorPool agents and control-plane wiring.
This document is authoritative for code organization and intended runtime structure; it should
match the current code layout in `src/` and the wire/driver specs in `docs/`.

## Specs and docs
- Wire spec: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- Driver model spec: `docs/SHM_Driver_Model_Spec_v1.0.md`
- Bridge spec: `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md`
- Implementation guide: `docs/IMPLEMENTATION.md`

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
- `src/control/`: control-plane primitives (proxies, pollers, shared runtime)
- `src/client/`: driver client API (attach/keepalive/detach polling)
- `src/driver/`: driver implementation (streams/leases/encoders/handlers)
- `src/agents/producer/`: producer agent
- `src/agents/consumer/`: consumer agent
- `src/agents/supervisor/`: supervisor agent
- `src/agents/bridge/`: bridge agent (UDP/IP payload forwarding)
- `src/agents/decimator/`: decimator agent
- `src/shm/`: SHM mapping, seqlock, superblock, slot helpers
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

### Decimator (optional)
- Applies decimation ratio to descriptors and republishes.

## Agent file structure (current)
Each agent follows the same organization for readability:
- `state.jl`: runtime/state structs
- `handlers.jl`: fragment handlers and message handling logic
- `init.jl`: init routines (Aeron setup, SHM mapping)
- `lifecycle.jl`: attach/remap/driver lifecycle handling
- `work.jl`: `*_do_work!` loop and timer polling
- `frames.jl`/`mapping.jl`/`proxy.jl` where applicable

## Control-plane API
- Use `with_claimed_buffer!` for Aeron publishes.
- `src/control/` houses proxies, pollers, and `ControlPlaneRuntime`.
- `src/client/driver_client.jl` provides `DriverClientState` + helper pollers.

## SHM utilities
- `src/shm/seqlock.jl`: seqlock read/write helpers
- `src/shm/superblock.jl`: `SuperblockFields`, read/write helpers
- `src/shm/slots.jl`: `TensorSlotHeader`, slot offsets, payload views
- `src/shm/uri.jl`: `ShmUri` parsing + validation

## Runtime loop conventions
- Fetch clock at top of each `*_do_work!` cycle; use cached time for the cycle.
- Use work_count rather than boolean flags for pollers.
- Prefer `try_claim` over `offer` for small control messages.

## Scripts
- `scripts/run_role.jl`: run a single role with a config
- `scripts/run_all.sh` / `scripts/run_all_driver.sh`: multi-role local runs
- `scripts/run_driver_smoke.jl`, `scripts/run_system_smoke.jl`: smoke tests
- `scripts/run_benchmarks.jl`: benchmark runner
- `scripts/tp_tool.jl`: control-plane CLI helpers

## Notes
- Bridge/decimator are optional; current focus is wire-level correctness and zero-allocation hot paths.
- Driver and client are both implemented in Julia; the driver is expected to remain in Julia even if
  a C client is added later.
