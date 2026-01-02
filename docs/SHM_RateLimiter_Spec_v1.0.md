# SHM Tensor Pool RateLimiter
## Specification (v1.0)

**Abstract**  
This document defines a rate-limiter agent that consumes frames from a source stream, applies a rate-limit policy, re-materializes accepted frames into a local SHM pool, and publishes `FrameDescriptor` messages on a new destination stream. This preserves the single-producer rule and keeps SHM ownership consistent.

**Key Words**  
The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHOULD”, “SHOULD NOT”, and “MAY” are to be interpreted as described in RFC 2119.

**Normative References**
- SHM Tensor Pool Wire Specification v1.1 (`docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`)
- SHM Driver Model Specification v1.0 (`docs/SHM_Driver_Model_Spec_v1.0.md`)

---

## 1. Scope

This specification defines:

- Decimation behavior for SHM Tensor Pool streams.
- Re-materialization into a destination SHM pool.
- Metadata forwarding for decimated outputs.

This specification does **not** modify SHM layout or wire formats; it defines agent behavior.

---

## 2. Roles

### 2.1 RateLimiter Agent (Normative)

The RateLimiter Agent is intended to run per-consumer. It consumes `FrameDescriptor` messages for a source stream, reads payloads from source SHM, and republishes selected frames to a destination stream using its own SHM pools.

---

## 3. Streams and IDs

- **Source Stream**: the input stream to decimate.
- **Destination Stream**: a distinct stream_id with its own SHM pools.

The rate limiter MUST NOT publish `FrameDescriptor` messages for the source stream and MUST only publish to the destination stream.

---

## 4. Rate Limiting Rules (Normative)

For each mapping, the rate limiter applies one of:

- **Rate-limit**: accept frames at most `max_rate_hz` (0 = unlimited). The rate limiter SHOULD publish the most recent frame available when the next rate slot opens.
- **Latest**: keep only the most recent frame observed since the last publish; any older frames seen in that interval are dropped.

Only one rate-limit policy is active per mapping. `rate_limiter.mode` applies to all mappings; per-mapping mode selection is not supported. If multiple policies are required, they MUST be expressed as distinct rate limiter instances.

The rate limiter MUST preserve `frame_id`/`seq` identity when republishing.

When operating per-consumer, the rate limiter MUST treat `ConsumerHello.max_rate_hz` as the authoritative rate limit for that consumer when `mode=rate_limit`. `ConsumerConfig` MAY override the rate limiter mode (e.g., force `latest`), but `max_rate_hz` is sourced from `ConsumerHello`. The rate limiter MUST NOT aggregate or apply policies across multiple consumers.

When `mode=latest`, `max_rate_hz` MUST be ignored.

For `rate_limit`, the first accepted frame after start or remap is eligible immediately, and the rate timer MUST reset on rate limiter restart and on source epoch change.

---

## 5. Re-materialization (Normative)

Upon accepting a source frame:

1. Validate source `epoch` and header/payload consistency per the wire spec.
2. Select a destination pool using configured mapping rules (e.g., smallest stride >= payload length).
3. Write payload bytes into the destination SHM pool.
4. Write `TensorSlotHeader256` into the destination header ring, preserving `frame_id`, `meta_version`, and `timestamp_ns`, and overriding `pool_id`/`payload_slot` for the destination pool.
5. Commit via the standard `commit_word` protocol.
6. Publish a destination `FrameDescriptor` on the destination stream.

If the destination pool cannot fit the payload, the rate limiter MUST drop the frame.

---

## 6. Metadata Forwarding (Normative)

When `rate_limiter.forward_metadata=true`, rate limiters MUST forward `DataSourceAnnounce` and `DataSourceMeta` from the source stream to the destination stream. The forwarded metadata MUST preserve `meta_version` and MUST rewrite `stream_id` to the destination stream_id for the mapping. When `rate_limiter.forward_metadata=false`, metadata MAY be omitted and consumers will lack metadata.

---

## 6.1 Progress and QoS Forwarding (Normative)

Rate limiters MAY forward `FrameProgress`; when enabled they SHOULD publish progress on `rate_limiter.control_channel`/`rate_limiter.dest_control_stream_id`. `FrameProgress.streamId` MUST be rewritten to the destination stream_id and `headerIndex` MUST refer to the destination header ring. Consumers MUST still treat `FrameDescriptor` as the canonical availability signal. All mappings share the same control channel/stream IDs; disambiguation is by `streamId`. The source control stream ID is shared across all mappings, and the rate limiter subscribes on `rate_limiter.control_channel`/`rate_limiter.source_control_stream_id`.

Rate limiters MAY forward or translate `QosProducer`/`QosConsumer` messages; when enabled they SHOULD publish them on `rate_limiter.qos_channel`/`rate_limiter.dest_qos_stream_id` and rewrite `streamId` to the destination stream_id. Other fields MAY be preserved for observability. All mappings share the same QoS channel/stream IDs; disambiguation is by `streamId`. The source QoS stream ID is shared across all mappings, and the rate limiter subscribes on `rate_limiter.qos_channel`/`rate_limiter.source_qos_stream_id`.

---

## 7. Liveness and Epochs (Normative)

- The rate limiter MUST treat a source epoch change as a remap boundary and drop in-flight frames until remap completes.
- The destination stream MUST use its own local epoch, incremented on rate limiter restart, independent of the source epoch.

---

## 8. RateLimiter Configuration (Informative)

The rate limiter is a separate application from the driver. The following keys define a minimal configuration surface.

Required keys:

- `rate_limiter.instance_id` (string): identifier for logging/diagnostics.
- `rate_limiter.descriptor_channel` (string): local IPC channel for destination `FrameDescriptor`.
- `rate_limiter.descriptor_stream_id` (uint32): destination descriptor stream ID.
- `mappings` (array): one or more stream mappings.

Optional keys and defaults:

- `rate_limiter.forward_metadata` (bool): forward metadata. Default: `true`.
- `rate_limiter.forward_progress` (bool): forward `FrameProgress`. Default: `false`.
- `rate_limiter.forward_qos` (bool): forward QoS messages. Default: `false`.
- `rate_limiter.mode` (string): `rate_limit` or `latest`. Default: `rate_limit`.
- `rate_limiter.max_rate_hz` (uint16): fallback publish rate when `ConsumerHello.max_rate_hz` is absent. Default: `0` (unlimited).
- `rate_limiter.control_channel` (string): local IPC control channel for forwarded progress. Default: `"aeron:ipc"`.
- `rate_limiter.source_control_stream_id` (uint32): source control stream ID to subscribe for `FrameProgress`. Default: `0` (disabled).
- `rate_limiter.dest_control_stream_id` (uint32): destination control stream ID for forwarded `FrameProgress`. Default: `0` (disabled).
- `rate_limiter.qos_channel` (string): local IPC QoS channel. Default: `"aeron:ipc"`.
- `rate_limiter.source_qos_stream_id` (uint32): source QoS stream ID to subscribe. Default: `0` (disabled).
- `rate_limiter.dest_qos_stream_id` (uint32): destination QoS stream ID for forwarded QoS. Default: `0` (disabled).

When `rate_limiter.forward_progress=true`, `rate_limiter.source_control_stream_id` and `rate_limiter.dest_control_stream_id` MUST be nonzero; otherwise the rate limiter MUST fail fast or disable progress forwarding with an error. When `rate_limiter.forward_qos=true`, `rate_limiter.source_qos_stream_id` and `rate_limiter.dest_qos_stream_id` MUST be nonzero; otherwise the rate limiter MUST fail fast or disable QoS forwarding with an error. Forwarding MUST NOT start when required IDs are zero.

Each `mappings` entry:

- `source_stream_id` (uint32)
- `dest_stream_id` (uint32)
- `profile` (string): destination profile name or pool mapping policy.
- `max_rate_hz` (uint16, optional): per-mapping fallback when `ConsumerHello.max_rate_hz` is absent. Default: inherit `rate_limiter.max_rate_hz`.
- `metadata_stream_id` (uint32, optional): destination metadata stream_id. Default: `dest_stream_id`.

Example config: `docs/examples/rate_limiter_config_example.toml`.

---

## 9. Bridge Interplay (Informative)

Rate limiters are composable with the bridge:

- **Bridge → RateLimiter**: bridge re-materializes a remote stream locally; rate limiter consumes the local stream and publishes a rate-limited destination stream.
- **RateLimiter → Bridge**: rate limiter publishes a rate-limited destination stream locally; bridge forwards that stream to remote hosts.

No special protocol is required; rate limiters and bridges only interact through standard streams and SHM pools.
