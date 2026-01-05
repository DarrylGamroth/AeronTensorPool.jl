# SHM Tensor Pool User Guide

This guide is an end-to-end, practical walkthrough for using the SHM Tensor Pool system. It complements the formal specs by explaining the typical workflow and what a user or integrator actually needs to do.

**Normative references**
- Wire spec: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- Driver model: `docs/SHM_Driver_Model_Spec_v1.0.md`
- Discovery: `docs/SHM_Discovery_Service_Spec_v_1.0.md`
- Bridge: `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md`

---

## 1. Concepts at a glance

- **Producer** writes data into shared memory (SHM) and publishes `FrameDescriptor`.
- **Consumer** reads descriptors and loads payload data directly from SHM.
- **Driver** owns SHM, leases, epochs, and emits `ShmPoolAnnounce`.
- **Discovery** is optional; it provides a read‑only index of streams.
- **Bridge** is optional; it repackages SHM frames for remote hosts.

---

## 2. Typical topology

```
Local host
  ┌─────────┐     ┌────────────┐
  │Producer │ --> │ SHM Driver │ --> ShmPoolAnnounce / Attach
  └─────────┘     └────────────┘
       |                ^
       v                |
  SHM pools        Consumer attach
       |                |
       v                |
  ┌─────────┐  <- FrameDescriptor
  │Consumer │
  └─────────┘
```

Remote host? Add a bridge to re-materialize SHM locally.

---

## 3. Startup order and liveness

You can start **producer** and **consumer** in any order.

- **Producer first:** emits `ShmPoolAnnounce`; consumers attach when they see it.
- **Consumer first:** waits for a *fresh* `ShmPoolAnnounce` (or successful attach response) before mapping SHM.

The system is soft‑state; liveness is based on periodic announcements and activity timestamps.

---

## 4. Discovery (optional)

If you run a discovery service:

1. Client sends `DiscoveryRequest` with filters and a response channel.
2. Discovery returns `DiscoveryResponse` with stream metadata + driver control endpoint.
3. Client attaches to the driver (not to discovery).

Discovery is advisory only; you still validate epochs/layout via `ShmPoolAnnounce`.

---

## 5. Attach flow (Driver mode)

Both producer and consumer attach via the driver control plane:

```
Client -> ShmAttachRequest (driver control channel)
Driver -> ShmAttachResponse (epoch + URIs + lease_id)
Client -> ShmPoolAnnounce (freshness check) -> map SHM
```

In code (see `scripts/example_producer.jl` / `scripts/example_consumer.jl`):
- Create a driver client (`init_driver_client`) and wait for control connectivity.
- Send attach request and poll until `code=OK`.
- Initialize agent state with `init_producer_from_attach` or `init_consumer_from_attach`.

The driver enforces exclusive producer leases and handles epoch changes.

---

## 6. Publishing data (Producer)

Producer loop (typical path):
1. Fill payload and header via `offer_frame!` (preferred).
2. `offer_frame!` handles the seqlock (`seq_commit`) and publishes `FrameDescriptor` on success.

---

## 7. Consuming data (Consumer)

Consumer loop (typical path):
1. Initialize with `init_consumer_from_attach`, then build a descriptor assembler.
2. Register hooks (see `ConsumerHooks`) to process `ConsumerFrameView`.
3. The consumer agent polls descriptors, performs the seqlock checks, and invokes hooks on valid frames.

If you need custom validation, use the `ConsumerFrameView` (header + payload view) from the hook.

Never block on incomplete frames; drop and continue.

---

## 8. Metadata and `meta_version`

Metadata is published separately:
- `DataSourceAnnounce` advertises the source + `meta_version`.
- `DataSourceMeta` contains the actual metadata payload.

Frames carry `meta_version` so consumers can interpret payloads correctly.

---

## 9. Per-consumer streams (optional)

Consumers can request per‑consumer descriptor/control streams in `ConsumerHello`.

If accepted:
- Producer publishes `FrameDescriptor` on that per‑consumer channel.
- `FrameProgress` (if enabled) also goes to the per‑consumer control channel.
- Consumer still listens to the **shared control stream** for other messages.

If declined, consumer stays on the shared streams.

---

## 10. Rate-limited delivery

Use `mode=RATE_LIMITED` with `max_rate_hz` in `ConsumerHello`.

If the producer cannot honor a per‑consumer stream:
- It may decline and the consumer must drop locally.

For shared reduced-rate streams, use the RateLimiter agent.

---

## 11. Bridge (remote consumers)

If a consumer is on another host:
1. A bridge reads from local SHM.
2. It republishes payloads and descriptors on UDP.
3. A receiving bridge re‑materializes SHM locally.

Consumers attach locally to the receiver’s SHM, not to the remote producer.

---

## 12. Failure handling

- **Driver down**: attach fails; wait and retry.
- **Epoch change**: unmap, drop in‑flight frames, remap on new announce.
- **Lease revoked**: stop using SHM immediately, reattach.

---

## 13. Minimal integration checklist

- [ ] Driver running with control + announce channels configured
- [ ] Producer attached and publishing `ShmPoolAnnounce`
- [ ] Consumer attached and mapped SHM
- [ ] Descriptor subscription active
- [ ] `seq_commit` checks enforced
- [ ] Metadata subscribed if needed

---

## 14. Where to go next

- Driver configuration: `docs/IMPLEMENTATION.md`
- Wire details: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- Discovery: `docs/SHM_Discovery_Service_Spec_v_1.0.md`
- Bridge: `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md`
