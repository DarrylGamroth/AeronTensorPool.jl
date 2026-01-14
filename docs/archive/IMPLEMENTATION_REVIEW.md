# Implementation Review (Julia vs Specs)

Date: 2025-01-12

This review checks the Julia implementation against the authoritative specs:
- `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- `docs/SHM_Driver_Model_Spec_v1.0.md`
- `docs/SHM_Discovery_Service_Spec_v_1.0.md`
- `docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md`
- `docs/SHM_RateLimiter_Spec_v1.0.md`

Goal: confirm **full** conformance for the Julia reference implementation, identify gaps, and flag correctness risks (including Aeron connection handling).

## Summary

- Core wire protocol (seqlock, header bytes validation, descriptor flow) is implemented and consistent.
- Driver attach/lease/epoch management is implemented and aligned with the driver spec.
- Discovery provider/registry is implemented and matches the discovery spec.
- Bridge appears implemented with metadata/progress forwarding.
- **RateLimiter is not implemented** (spec exists, no agent).
- A few **spec features are present in schema/config but not fully enforced** (see findings).

## Findings

### Critical
- **RateLimiter spec not implemented**: There is a full spec (`docs/SHM_RateLimiter_Spec_v1.0.md`), but no corresponding agent/module in `src/agents/`. This means the reference implementation is not complete relative to the published specs.

### High
- **Fresh announce gating after attach is not enforced**:  
  The spec requires clients to ignore stale announces and to treat `ShmPoolAnnounce` as soft-state. When attaching via driver response, a fresh announce should still be required for liveness (spec wording: attach MAY provide authoritative snapshot, but consumers MUST require a fresh announce before trusting periodic liveness).  
  Current behavior: consumer maps immediately from `ShmAttachResponse` and will process descriptors as soon as SHM is mapped. There is no explicit “fresh announce seen” gate before processing descriptors.

### Medium
- **Progress major delta units ignored by producer**:  
  ConsumerHello includes `progressMajorDeltaUnits` but producer only uses interval and byte delta. The spec describes a major-axis delta hint; producer should incorporate it (min over all consumers, bounded by producer floor).

- **Driver announce clock domain is fixed to MONOTONIC**:  
  Driver always emits `announceClockDomain = MONOTONIC` and uses monotonic timestamps. Spec allows REALTIME_SYNCED when deployments need cross-host alignment. No config toggle exists.

- **Layout version is hardcoded to 1**:  
  Driver attaches/announces always emit `layoutVersion = 1`. This is consistent with the current v1.1 schema, but there is no configuration or constant in code to track bumps (spec: layout changes should bump `layout_version` and epoch). Consider making layout version a constant derived from schema or config.

### Low
- **Consumer mode is effectively unused**:  
  `Mode.RATE_LIMITED` exists in config and QoS messages, but `should_process` always returns true. If mode is meant to drive drop/decimation behavior, it is not implemented. If mode is now informational only, the docs/spec should state that.

- **Connection status helpers may be misused by callers**:  
  `consumer_connected`/`producer_connected` use Aeron `is_connected` and could be interpreted as readiness gates. In core logic they are not used, which is good. We should document these as observability only (no correctness gating).

## Aeron connection handling (startup ordering)

The core publish path uses `with_claimed_buffer!` (try-claim) and does **not** gate correctness on Aeron `is_connected`. This is correct for producer/consumer startup ordering and aligns with the spec requirement that clients can come and go.

However:
- `consumer_connected` / `producer_connected` expose connection status for applications; if apps gate on these, they may delay or skip valid operations. This should be documented as advisory only.

## Spec coverage by area

### Wire spec (v1.1)
Implemented:
- Seqlock protocol and commit semantics.
- Slot header + embedded TensorHeader with MessageHeader validation.
- Descriptor and payload mapping logic with drop rules.
- Announce freshness window and clock domain handling in consumer.
- QoS and metadata streams and helpers.

Gaps / mismatches:
- Producer ignores `progressMajorDeltaUnits` hint.
- Consumer mode logic not applied (mode is currently informational).
- No support for REALTIME_SYNCED clock domain in driver announces.

### Driver spec (v1.0)
Implemented:
- Attach/keepalive/detach control plane.
- Lease lifecycle and revocations.
- Epoch bump and SHM provisioning.
- Epoch GC (policy config present).

Potential mismatches:
- Layout version constant is fixed; no config-driven bump.
- Fresh announce gating after attach not enforced.

### Discovery spec (v1.0)
Implemented:
- Provider and registry agents.
- Request filtering (stream_id, producer_id, data_source_id/name, tags).
- Response encoding with pools/URIs.

### Bridge spec (v1.0)
Implemented (based on code structure):
- Sender/receiver, chunking, rematerialization.
- Optional forward metadata/progress/QoS.

Note: not fully re-validated line-by-line against spec in this review; recommend a targeted check if bridge is mission-critical.

### RateLimiter spec (v1.0)
Not implemented (no agent/module).

## Recommendations

1. **Implement RateLimiter agent** or remove/mark spec as “planned” if not part of the reference implementation.
2. **Add a “fresh announce seen” gate** for consumers after attach before treating descriptors as trusted.
3. **Honor `progressMajorDeltaUnits`** in producer progress policy.
4. **Add config/constant for layout version** and wire it into driver announce/attach responses.
5. **Document Aeron connection status helpers** as advisory to avoid misuse by applications.

## Files reviewed (selected)

- Consumer seqlock path: `src/agents/consumer/frames.jl`
- Slot header/tensor decode: `src/shm/superblock.jl`
- Driver announces/attach responses: `src/agents/driver/encoders.jl`
- Driver attach/lease handling: `src/agents/driver/leases.jl`
- Consumer mapping & announce handling: `src/agents/consumer/mapping.jl`
- Producer claim/commit paths: `src/agents/producer/frames.jl`
- Discovery provider/registry: `src/agents/discovery/*`
- Bridge sender/receiver/proxy: `src/agents/bridge/*`
- Connection status helpers: `src/client/handles.jl`
