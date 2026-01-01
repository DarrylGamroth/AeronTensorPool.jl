# SHM Tensor Pool Decimator
## Specification (v1.0)

**Abstract**  
This document defines a decimator agent that consumes frames from a source stream, applies a decimation policy, re-materializes accepted frames into a local SHM pool, and publishes `FrameDescriptor` messages on a new destination stream. This preserves the single-producer rule and keeps SHM ownership consistent.

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

### 2.1 Decimator Agent (Normative)

The Decimator Agent is intended to run per-consumer. It consumes `FrameDescriptor` messages for a source stream, reads payloads from source SHM, and republishes selected frames to a destination stream using its own SHM pools.

---

## 3. Streams and IDs

- **Source Stream**: the input stream to decimate.
- **Destination Stream**: a distinct stream_id with its own SHM pools.

The decimator MUST NOT publish `FrameDescriptor` messages for the source stream and MUST only publish to the destination stream.

---

## 4. Decimation Rules (Normative)

For each mapping, the decimator applies one of:

- **Every-N**: accept every Nth frame (`decimation = N`, where `N >= 1`).
- **Latest**: keep only the most recent frame in a polling cycle (optional).

If multiple policies are configured, the decimator MUST apply them in the order listed and MAY drop frames early.

The decimator MUST preserve `frame_id`/`seq` identity when republishing.

When operating per-consumer, the decimator MAY honor `ConsumerHello`/`ConsumerConfig` settings for the consumer it serves, treating those as its local decimation policy. It MUST NOT aggregate or apply policies across multiple consumers.

---

## 5. Re-materialization (Normative)

Upon accepting a source frame:

1. Validate source `epoch` and header/payload consistency per the wire spec.
2. Select a destination pool using configured mapping rules (e.g., smallest stride >= payload length).
3. Write payload bytes into the destination SHM pool.
4. Write `TensorSlotHeader256` into the destination header ring, preserving `frame_id`, `meta_version`, and `timestamp_ns`, and overriding `pool_id`/`payload_slot` for the destination pool.
5. Commit via the standard `commit_word` protocol.
6. Publish a destination `FrameDescriptor` on the destination stream.

If the destination pool cannot fit the payload, the decimator MUST drop the frame.

---

## 6. Metadata Forwarding (Normative)

Decimators MUST forward `DataSourceAnnounce` and `DataSourceMeta` from the source stream to the destination stream. The forwarded metadata MUST preserve `meta_version` and MUST rewrite `stream_id` to the destination stream_id for the mapping.

---

## 7. Liveness and Epochs (Normative)

- The decimator MUST treat a source epoch change as a remap boundary and drop in-flight frames until remap completes.
- The destination stream MUST use its own local epoch, incremented on decimator restart, independent of the source epoch.

---

## 8. Decimator Configuration (Informative)

The decimator is a separate application from the driver. The following keys define a minimal configuration surface.

Required keys:

- `decimator.instance_id` (string): identifier for logging/diagnostics.
- `decimator.descriptor_channel` (string): local IPC channel for destination `FrameDescriptor`.
- `decimator.descriptor_stream_id` (uint32): destination descriptor stream ID.
- `mappings` (array): one or more stream mappings.

Optional keys and defaults:

- `decimator.forward_metadata` (bool): forward metadata. Default: `true`.
- `decimator.mode` (string): `every_n` or `latest`. Default: `every_n`.

Each `mappings` entry:

- `source_stream_id` (uint32)
- `dest_stream_id` (uint32)
- `profile` (string): destination profile name or pool mapping policy.
- `decimation` (uint32): N for every-N policy. Default: `1`.
- `metadata_stream_id` (uint32, optional): destination metadata stream_id. Default: `dest_stream_id`.

Example config: `docs/examples/decimator_config_example.toml`.
