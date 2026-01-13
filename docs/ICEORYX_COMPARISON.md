# AeronTensorPool vs Iceoryx/Iceoryx2

This document provides an architecture-level comparison between the current
AeronTensorPool design (as defined in the wire/driver/bridge specs) and the
Iceoryx family. For a deeper, source-backed analysis, see
`docs/ICEORYX_DETAILED_COMPARISON.md`.

## Baseline: AeronTensorPool Architecture (Current)

Data plane:
- SHM header ring + payload pools with fixed stride sizes.
- Seqlock commit protocol for header/payload consistency.
- Consumers poll FrameDescriptor (Aeron) then read SHM slot.
- Zero-allocation hot path after initialization.

Control plane:
- Aeron IPC/UDP control messages (attach, announce, QoS, metadata).
- Driver model: authoritative driver issues SHM URIs, epochs, leases.
- Schema: SBE for wire and SHM (SlotHeader + embedded TensorHeader).

Discovery:
- Optional discovery provider/registry.
- Driver is the authority for attach, epochs, and SHM URIs.

Failure handling:
- Epoch changes are hard remap boundaries.
- Slot overwrite/drop model: no blocking, consumers drop on instability.
- Liveness by announces, lease keepalives, and activity timestamps.

## Iceoryx (v1.x) Architecture Overview

Data plane:
- SHM-based pub/sub using fixed-size memory pools.
- Publishers loan chunks from a shared pool, write data, then publish.
- Subscribers receive chunks via shared-memory queues; zero-copy on read.
- Chunk lifecycle uses reference counting/loan/return rather than seqlocks.

Control plane:
- Central daemon (RouDi) manages shared memory, ports, and discovery.
- Participants register with RouDi; RouDi assigns memory pools and manages
  service availability.
- Introspection and health tooling is built-in.

Discovery:
- Provided by RouDi (centralized).
- Service discovery within the host; no network transport by default.

Failure handling:
- RouDi monitors participant liveness and reclaims resources.
- Chunk ownership and port state avoid torn reads without seqlocks.

## Iceoryx2 Architecture (High-Level)

This section summarizes the known directional changes:
- Rust-first implementation focused on safety and modularity.
- Retains zero-copy SHM transport focus.
- Evolving architecture; may reduce central daemon reliance.

NOTE: Verify details against upstream Iceoryx2 docs before making final
decisions.

## Detailed Comparison Matrix

Legend:
- ATP = AeronTensorPool (current)
- IOX = Iceoryx v1.x
- IOX2 = Iceoryx2 (verify details)

| Dimension | ATP | IOX | IOX2 |
| --- | --- | --- | --- |
| Core transport | Aeron control-plane + SHM data plane | SHM pub/sub with RouDi coordination | SHM pub/sub, Rust-first |
| Data plane | Seqlock header ring + payload pools | Loaned chunk buffers | Loaned chunk buffers |
| Hot path allocations | None after init | None after init | None after init |
| Consistency model | Seqlock, overwrite/drop | Chunk ownership + queues | Chunk ownership + queues |
| Backpressure | None (lossy overwrite) | Configurable queue depth; drop or overwrite per policy | Similar to IOX |
| Discovery | Optional; driver authoritative | RouDi centralized discovery | Likely decentralized/leaner (verify) |
| Control plane | Aeron IPC/UDP | RouDi IPC | Likely IPC with service discovery (verify) |
| Memory pools | Fixed stride pools per payload size | Fixed-size chunk pools | Fixed-size chunk pools |
| Header layout | SBE-defined SlotHeader + TensorHeader | Application-defined payload structs | Application-defined payload structs |
| Schema/typing | SBE for control + SHM | None mandated (POD structs) | None mandated (POD structs) |
| Cross-host | Via bridge/UDP | Not native (requires separate transport) | Not native (verify) |
| Multi-producer | Exclusive producer per stream (driver model) | Multiple pubs per service, controlled by RouDi | Similar (verify) |
| Liveness | Leases + announces + epochs | RouDi supervision | Likely node-based supervision (verify) |
| Epoch/remap | Explicit epoch boundaries | Not explicit; RouDi resets shared memory | Not explicit; verify |
| Failure recovery | Remap on epoch change | Port cleanup + shared memory reset | Verify |
| QoS/metrics | QoS messages, counters | Introspection ports + tooling | Verify |
| Language support | Julia + any Aeron/SBE language | C/C++ + bindings | Rust + C/C++ bindings (verify) |
| Determinism | Explicit overwrite/drop | Queue-based; can block or drop | Similar to IOX |
| Operational footprint | Aeron + SHM + driver | RouDi + SHM | Lighter (goal), verify |

## Architectural Decision Details

### 1) Consistency and Safety

ATP:
- Uses seqlock to protect header/payload consistency.
- Consumers retry/drop on instability; no blocking.

IOX:
- Uses chunk ownership and reference counting.
- Consumers receive stable chunks; no seqlock needed.

Tradeoff:
- Seqlock offers simple overwrite semantics and minimal coordination.
- Chunk ownership provides safe snapshots but implies pool and queue
  management overhead.

### 2) Memory Management

ATP:
- Pools are sized by stride; payload slot = header index in v1.2.
- Overwrite is allowed; consumers must tolerate drops.

IOX:
- Pools are sized by chunk size; publishers loan and return buffers.
- No overwrite; allocation fails if pool exhausted (policy dependent).

Tradeoff:
- ATP is optimized for steady high-rate streaming with drops.
- IOX is optimized for bounded queueing and strict ownership.

### 3) Control Plane and Discovery

ATP:
- Driver manages SHM, epochs, leases, and URIs.
- Discovery/registry is optional and can be replaced.

IOX:
- RouDi is a mandatory central daemon.
- Discovery and port management are centralized.

Tradeoff:
- ATP allows more flexible deployment models.
- IOX provides a simpler single-service authority at the cost of a mandatory
  daemon and fixed control plane.

### 4) Schema and Serialization

ATP:
- SBE for control-plane and SHM layout.
- Strict validation with schemaId/version checks.

IOX:
- No mandated wire schema; payload is application-defined POD.
- Schema validation is application-level.

Tradeoff:
- ATP provides language-neutral interoperability by default.
- IOX offers more flexibility but less built-in wire-level compatibility.

### 5) Cross-Host Transport

ATP:
- Native bridge over Aeron UDP for cross-host flows.
- Retains SHM semantics on each host.

IOX:
- SHM only; cross-host requires external transport.

Tradeoff:
- ATP can extend to multi-host without changing data plane.
- IOX remains host-local unless combined with another transport.

## If Aeron/SBE Are Optional

If you remove Aeron/SBE but keep the ATP layout:
- Replace control plane with a lightweight protocol (JSON/HTTP or custom).
- Keep SHM + seqlock for the zero-alloc hot path.
- Choose a lightweight discovery approach (file registry or UDP beacons).

If you adopt Iceoryx:
- Drop seqlock and header ring; use chunk loan/return.
- Align your tensor header to a POD struct and use IOX loaned chunks.
- Accept RouDi as the authority and align lifecycle to its model.

## Verification Checklist (Iceoryx2)

The following details should be confirmed against upstream docs:
- Whether Iceoryx2 retains a central daemon (RouDi equivalent).
- Exact discovery mechanism and service registry model.
- Support for request/response patterns in addition to pub/sub.
- Memory pool configuration and chunk lifecycle semantics.
- Introspection and liveness model.
