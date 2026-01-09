# Julia Implementation Conformance Matrix

This report audits the Julia implementation against the normative requirements in:
- `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- `docs/SHM_Driver_Model_Spec_v1.0.md`
- `docs/SHM_Discovery_Service_Spec_v_1.0.md`
- `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md`

Status legend:
- **Implemented**: requirement enforced in Julia code.
- **Partial**: some aspects covered; gaps remain.
- **Not Implemented**: missing behavior in Julia implementation.
- **N/A (client-only/driver-only)**: requirement applies to a different component.

## Driver Model Spec (driver-side requirements)

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §4 | Attach response includes required fields; nulls rejected on OK | **Implemented** | `src/agents/driver/leases.jl`, `src/agents/driver/encoders.jl` |
| §4 | `poolNslots == headerNslots` and pool URI presence | **Implemented** | `src/agents/driver/leases.jl`, `src/agents/driver/streams.jl` |
| §4 | Correlation id echoed unchanged | **Implemented** | `src/agents/driver/handlers.jl`, `src/agents/driver/encoders.jl` |
| §5 | Lease keepalive / expiry enforcement | **Implemented** | `src/agents/driver/runtime.jl`, `src/agents/driver/leases.jl` |
| §6 | Reject duplicate attach per client/role/stream | **Implemented** | `src/agents/driver/leases.jl` |
| §6 | Detach idempotent and best-effort | **Implemented** | `src/agents/driver/leases.jl`, `src/agents/driver/encoders.jl` |
| §6 | Revoke leases on shutdown and emit revoke | **Implemented** | `src/agents/driver/leases.jl`, `src/agents/driver/encoders.jl` |
| §7 | Epoch bump on layout change or restart | **Implemented** | `src/agents/driver/streams.jl`, `src/agents/driver/config.jl` |
| §10 | Driver shutdown message handling and policy | **Implemented** | `src/agents/driver/leases.jl`, `src/agents/driver/lifecycle_handlers.jl` |
| §11 | Producer-only / consumer-only per stream | **Implemented** | `src/agents/driver/streams.jl`, `src/agents/driver/leases.jl` |
| §16 | Config defaults and validation | **Implemented** | `src/agents/driver/config.jl` |
| §16 | SHM policy: hugepages enforcement | **Implemented** | `src/agents/driver/config.jl`, `src/agents/driver/streams.jl` |

## Driver Model Spec (client-side requirements)

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §4 | Clients MUST treat driver URIs as authoritative | **Implemented** | `src/client/attach.jl`, `src/agents/consumer/mapping.jl`, `src/agents/producer/shm.jl` |
| §4 | Reject missing/null required fields on OK | **Implemented** | `src/control/driver_client.jl`, `src/client/attach.jl` |
| §5 | Send keepalives; failure is fatal | **Implemented** | `src/agents/consumer/pollers.jl`, `src/agents/producer/agent.jl` |
| §6 | No concurrent attach for same stream/role | **Implemented** | `src/control/driver_client.jl` |
| §6 | Handle `ShmLeaseRevoked` / shutdown | **Implemented** | `src/control/driver_client.jl`, `src/agents/consumer/lifecycle.jl` |
| §9 | Schema version compatibility | **Implemented** | `src/control/driver_client.jl`, `src/agents/consumer/handlers.jl` |
| §10 | Stop using SHM on shutdown | **Implemented** | `src/agents/consumer/lifecycle.jl`, `src/agents/producer/agent.jl` |
| §11 | Per-consumer stream requests | **Implemented** | `src/agents/consumer/handlers.jl`, `src/agents/driver/handlers.jl` |

## Wire Spec (consumer/producer requirements)

### Attach + SHM validation

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §15.21a / §15.22 | Validate SHM URI scheme/params | **Implemented** | `src/shm/uri.jl`, `src/agents/consumer/mapping.jl` |
| §15.22 | Hugepage validation and policy | **Implemented** | `src/shm/linux.jl`, `src/agents/consumer/mapping.jl` |
| §15.22 | Stride power-of-two and page-size multiple | **Implemented** | `src/shm/slots.jl`, `src/agents/consumer/mapping.jl` |
| §7.1 | Superblock validation (magic/layout/epoch/region_type) | **Implemented** | `src/shm/superblock.jl`, `src/agents/consumer/mapping.jl`, `src/agents/producer/shm.jl` |

### Descriptor + seqlock path

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §15.19 | Seqlock read protocol (odd/retry/change/drop) | **Implemented** | `src/agents/consumer/frames.jl` |
| §15.19 | Drop if header index invalid or epoch mismatch | **Implemented** | `src/agents/consumer/frames.jl` |
| §15.19 | Validate `payload_offset == 0` | **Implemented** | `src/agents/consumer/frames.jl` |
| §15.19 | Validate `values_len_bytes <= stride_bytes` | **Implemented** | `src/agents/consumer/frames.jl` |
| §15.19 | Parse `headerBytes` as TensorHeader SBE | **Implemented** | `src/agents/consumer/frames.jl`, `src/shm/slots.jl` |
| §15.19 | Validate `ndims` in 1..MAX_DIMS | **Implemented** | `src/agents/consumer/frames.jl` |
| §15.19 | Validate strides for major order | **Implemented** | `src/agents/consumer/frames.jl` |
| §15.19 | Progress stride validation | **Implemented** | `src/agents/consumer/frames.jl` |

### Producer requirements

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §15.19 | Commit protocol (write odd, fill, write even) | **Implemented** | `src/agents/producer/frames.jl`, `src/shm/seqlock.jl` |
| §15.19 | `header_index = seq & (nslots-1)` | **Implemented** | `src/agents/producer/frames.jl` |
| §15.19 | `payload_offset = 0` | **Implemented** | `src/agents/producer/frames.jl` |
| §15.19 | Drop if no pool fits payload | **Implemented** | `src/agents/producer/frames.jl` |
| §15.19 | Zero-fill dims/strides beyond ndims | **Implemented** | `src/shm/slots.jl` |

### Announce/QoS/Progress/Metadata

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §9 | ShmPoolAnnounce soft-state + freshness | **Implemented** | `src/agents/consumer/handlers.jl`, `src/agents/consumer/lifecycle.jl` |
| §10.3 | FrameProgress handling (optional) | **Implemented** | `src/agents/consumer/handlers.jl` |
| §12 | QosProducer/QosConsumer send | **Implemented** | `src/agents/producer/agent.jl`, `src/agents/consumer/pollers.jl` |
| §12 | QoS monitoring receive path | **Implemented** | `src/client/qos_monitor.jl` |
| §13 | Metadata publish/consume | **Implemented** | `src/client/metadata.jl`, `src/agents/producer/handlers.jl` |

### Per-consumer streams & rate limiting

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §10.1.3 | Per-consumer stream request/validation | **Implemented** | `src/agents/consumer/handlers.jl`, `src/agents/driver/handlers.jl` |
| §14 | RATE_LIMITED mode with maxRateHz | **Implemented** | `src/agents/consumer/lifecycle.jl`, `src/agents/driver/handlers.jl` |

## Discovery Service Spec

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §3 | NullValue handling for optional request fields | **Implemented** | `src/agents/discovery/handlers.jl` |
| §3 | `response_channel` / `response_stream_id` included | **Implemented** | `src/agents/discovery/handlers.jl` |
| §4 | Response status + error message handling | **Implemented** | `src/agents/discovery/handlers.jl` |
| §5 | Filtering / tag matching | **Implemented** | `src/agents/discovery/handlers.jl` |

## UDP Bridge Spec

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §7–§10 | Descriptor/payload bridging + mapping | **Implemented** | `src/agents/bridge/sender.jl`, `src/agents/bridge/receiver.jl` |
| §9–§10 | QoS + FrameProgress forwarding | **Implemented** | `src/agents/bridge/proxy.jl`, `src/agents/bridge/adapters.jl` |
| §11 | Bridge schema usage | **Implemented** | `src/agents/bridge/adapters.jl`, `src/agents/bridge/state.jl` |

## Summary

- Driver: lease lifecycle, attach/detach, shutdown, and policy enforcement are implemented and covered by integration tests (see `test/test_driver_*`).
- Consumer/producer: SHM validation, seqlock protocol, and header parsing are implemented in the hot path; allocation-free tests cover critical loops.
- Discovery and bridge services are implemented with dedicated agents and exercised by integration tests and examples.

## Recommended next actions

1) Expand integration tests to cover driver shutdown + reattach scenarios for the bridge path.
2) Add targeted tests for consumer rate-limit streams using per-consumer channels end-to-end.
