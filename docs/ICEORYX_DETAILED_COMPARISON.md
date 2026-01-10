# AeronTensorPool vs Iceoryx/Iceoryx2 (Detailed)

This document provides a deep architecture comparison between the current
AeronTensorPool design and the Iceoryx family (v1.x and Iceoryx2). It focuses
on zero-allocation hot paths and SHM semantics.

Sources are local to:
- `AeronTensorPool-docs.jl/docs/*` (current specs)
- `../iceoryx/doc/*`, `../iceoryx/README.md` (Iceoryx v1)
- `../iceoryx2/README.md`, `../iceoryx2/doc/*`, `../iceoryx2/examples/*` (Iceoryx2)

## Executive Summary

- AeronTensorPool (ATP) uses a seqlock-protected header ring + payload pools and
  lossy overwrite semantics. Control plane is Aeron + SBE (optional if you swap
  it out), with a driver managing epochs and leases.
- Iceoryx v1 uses RouDi as a central daemon, shared memory pools of fixed-size
  chunks, and loan/return chunk semantics. Consistency is ensured by ownership
  and queues, not seqlock. Discovery and ports are managed centrally.
- Iceoryx2 is a Rust-core rewrite with service-oriented IPC and zero-copy focus.
  It adds a service discovery service and enforces `ZeroCopySend` for payload
  types. Some details differ from v1 and are still evolving.

## AeronTensorPool Architecture (Current)

Data plane (from `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`):
- SHM header ring with fixed 256-byte slots.
- Payload pools with fixed stride; v1.1 maps `payload_slot = header_index`.
- Seqlock commit protocol to guard header/payload consistency.
- Consumers poll `FrameDescriptor`, then read slot/payload.
- Lossy overwrite: producers never wait; consumers drop on instability.

Control plane:
- Aeron messages with SBE encoding for announce/attach/QoS/metadata.
- Driver model (`docs/SHM_Driver_Model_Spec_v1.0.md`) manages SHM allocation,
  epochs, leases, and authoritative `ShmPoolAnnounce`.

Discovery:
- Optional provider/registry; driver is authority for attach and URIs.

Liveness:
- Lease keepalives, epoch bump on producer loss, and activity timestamps.

## Iceoryx v1 Architecture

### Components and Roles

From `../iceoryx/doc/website/concepts/architecture.md`:
- `iceoryx_posh` handles POSIX SHM IPC.
- `popo` is the user API for publishers/subscribers/clients/servers.
- `mepoo` is the memory pool subsystem (MemoryManager, SharedPointer).
- `capro` implements the canonical protocol pattern used to connect ports.
- RouDi is the middleware daemon managing ports and shared memory.

### Shared Memory Model

From `../iceoryx/doc/shared-memory-communication.md`:
- A system uses a management segment and one or more user segments.
- Segments are partitioned into mempools of equally sized chunks.
- Producers reserve (loan) a chunk; the smallest fitting chunk size is used.
- Delivery places a pointer to the chunk into each subscriber queue.
- Consumers must release chunks; chunks return to pool after all consumers
  indicate they are done.

### Chunk Layout

From `../iceoryx/doc/design/chunk_header.md`:
- Each chunk has a `ChunkHeader` followed by payload; optional user-header
  is supported with alignment and offset rules.
- `ChunkHeader` includes originId, sequenceNumber, chunkSize, payload size,
  payload alignment, and user header metadata.
- A back-offset is stored to recover the header from the user payload pointer.

### QoS and Backpressure

From `../iceoryx/doc/website/concepts/qos-policies.md`:
- Queue capacity and history options control buffering and late-join behavior.
- Policies define blocking vs discard on full queues.
- Producer/subscriber matching includes policy compatibility.

### Discovery and Control Plane

From `../iceoryx/doc/design/draft/service-discovery.md` (draft) and
`../iceoryx/doc/website/concepts/architecture.md`:
- RouDi mediates discovery and port management.
- Runtime `findService` uses IPC to query RouDi and receive results.
- Service discovery design is centered on RouDi and shared memory segments.

## Iceoryx2 Architecture

### Core Positioning

From `../iceoryx2/README.md`:
- Rust-core, zero-copy, lock-free IPC.
- Service-oriented architecture, supports pub/sub, events, request-response.

### Discovery and Daemons

From `../iceoryx2/doc/release-notes/iceoryx2-v0.6.0.md`:
- Introduces a "service discovery service" for updates in the service landscape.
- Adds CLI to launch the service discovery service.

From `../iceoryx2/doc/how-to-write-end-to-end-tests.md`:
- Example `health_monitoring_central_daemon` suggests a central daemon for
  health monitoring in some deployments.

### Zero-Copy Type Safety

From `../iceoryx2/doc/release-notes/iceoryx2-v0.6.0.md`:
- Payload and user header types must implement `ZeroCopySend`.

### Request/Response Patterns

From `../iceoryx2/doc/user-documentation/request-response.md`:
- Request/response uses loaned samples with a `ZeroCopyConnection`.
- Client loans a request, server receives, loans a response, sends, and both
  sides explicitly drop when done.

## Detailed Comparison Matrix

Legend:
- ATP = AeronTensorPool
- IOX = Iceoryx v1
- IOX2 = Iceoryx2 (based on local docs; some details still evolving)

| Dimension | ATP | IOX | IOX2 |
| --- | --- | --- | --- |
| Data plane | Header ring + payload pools | Chunk pools + loan/return | Chunk pools + loan/return |
| Consistency | Seqlock + overwrite/drop | Ownership + queues | Ownership + queues |
| Hot path allocations | None after init | None after init | None after init |
| Backpressure | None; drop/overwrite | Policy-driven block/drop | Policy-driven block/drop |
| Header metadata | SBE SlotHeader + TensorHeader | ChunkHeader + user header | Payload type + optional user header |
| Payload layout | Fixed stride slots | Chunk size chosen per type | Chunk size chosen per type |
| Discovery | Optional registry; driver authoritative | RouDi-managed discovery | Service discovery service (v0.6.0) |
| Control plane | Aeron + SBE | RouDi IPC | Rust-core services; CLI for discovery |
| Authority | Driver owns epochs/URIs | RouDi owns ports/segments | Service discovery service + node model |
| Liveness | Lease keepalive + epoch bump | RouDi supervision | Health monitoring daemon example |
| Cross-host | UDP bridge (optional) | Not native (needs gateway) | Not native (not shown in docs) |
| Multi-producer | Exclusive per stream (driver) | Multiple publishers per service | Multiple publishers per service |
| Schema checks | SchemaId/version checks | Not mandated | Type trait (`ZeroCopySend`) |
| QoS | QoS messages, counters | Queue/history policies | Similar patterns (details evolving) |
| Language support | Julia + SBE languages | C/C++ (+ bindings) | Rust + C/C++ + Python |
| Failure recovery | Remap on epoch change | Port cleanup via RouDi | Node/daemon cleanup (example) |

## Architecture Tradeoffs (Detailed)

### Consistency and Safety

ATP:
- Seqlock provides atomic commit state; consumers drop on instability.
- Overwrite is allowed without waiting.

IOX/IOX2:
- Chunk ownership ensures consumers see stable data.
- No seqlock; consistency enforced by loan/return and queues.

Implication:
- ATP favors high-rate streams with tolerance for drops.
- IOX favors bounded queues with backpressure control.

### Memory and Layout

ATP:
- Fixed slot size; payload stride chosen by pool size class.
- v1.1 uses `payload_slot = header_index` for simplicity.

IOX:
- Fixed-size chunk pools; smallest fitting chunk size is used.
- ChunkHeader supports a user header and alignment rules.

IOX2:
- Similar loaned-chunk model with type traits enforcing SHM-safe types.

Implication:
- ATP layout is predictable and optimized for fixed stride classes.
- IOX layout is optimized for typed payloads and optional headers.

### Control Plane and Discovery

ATP:
- Driver issues leases and epochs; discovery is optional.
- Control plane can be swapped if Aeron/SBE are removed.

IOX:
- RouDi is central for discovery and port management.
- Runtime queries RouDi over IPC for findService.

IOX2:
- Service discovery service introduced (v0.6.0).
- Central daemon appears in health monitoring examples.

Implication:
- ATP offers more modular control-plane choices.
- IOX has a fixed daemon-centric model.

### QoS and Backpressure

ATP:
- Lossy overwrite; QoS metrics are advisory.

IOX:
- Queue full policies: block or discard.
- History and late-join behavior is configurable.

IOX2:
- Similar pub/sub patterns with loaned samples.

Implication:
- ATP is simpler for high-throughput streaming.
- IOX provides more knobs for bounded memory and delivery guarantees.

## Decision Guidance

Choose ATP when:
- You want strict control over SHM layout and zero-allocation hot paths.
- Lossy overwrite is acceptable for throughput.
- You want a modular control plane and optional cross-host bridge.

Choose IOX/IOX2 when:
- You want a full SHM IPC framework with built-in discovery.
- You prefer chunk ownership semantics over seqlock.
- You want integrated tooling (introspection, QoS options) out of the box.

## Notes on Iceoryx2 Evolution

Iceoryx2 is actively evolving. Some control-plane and discovery details are
present in release notes but not fully documented in this repo. If you want
absolute parity in this comparison, use the iceoryx2 book or upstream API
docs to confirm any operational details beyond what is cited above.
