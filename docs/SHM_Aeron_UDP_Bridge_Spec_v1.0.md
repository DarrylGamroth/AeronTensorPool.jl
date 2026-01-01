# SHM Tensor Pool Aeron-UDP Bridge
## Specification (v1.0)

**Abstract**  
This document defines a bridge protocol for transporting SHM Tensor Pool frames over `aeron:udp` between hosts. The bridge reads frames from a local SHM pool and re-materializes them into a remote host's SHM pool, then publishes standard `FrameDescriptor` messages locally. This enables remote consumers to use the same wire specification without attaching to a remote driver.

**Key Words**  
The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHOULD”, “SHOULD NOT”, and “MAY” are to be interpreted as described in RFC 2119.

**Normative References**
- SHM Tensor Pool Wire Specification v1.1 (`docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`)
- SHM Driver Model Specification v1.0 (`docs/SHM_Driver_Model_Spec_v1.0.md`)

---

## 1. Scope

This specification defines:

- UDP bridge streams for transporting frame headers and payload bytes.
- Re-materialization behavior into a remote SHM pool.
- Required constraints for chunking, ordering, and loss handling.

This specification does **not** change the SHM layout or local wire protocol; it defines a transport bridge between hosts.

---

## 2. Roles

### 2.1 Bridge Sender (Normative)

The Bridge Sender reads frames from a local SHM pool as a consumer and publishes bridge payload chunks over `aeron:udp`.

### 2.2 Bridge Receiver (Normative)

The Bridge Receiver subscribes to bridge payload chunks, reconstructs frames, writes them into local SHM pools as a producer, and publishes local `FrameDescriptor` messages for local consumers.

---

## 3. Transport Model

- The bridge uses Aeron UDP channels (e.g., `aeron:udp?endpoint=...`).
- Multicast (`aeron:udp?endpoint=...|group=...`) is supported and MAY be used for one-to-many fan-out.
- The bridge does not expose the SHM Driver over the network; each host runs its own driver with local SHM pools.
- The bridge is lossy: if any chunk is missing, the frame is dropped.

---

## 4. Streams and IDs

For each bridged `stream_id`, the bridge uses:

- **Bridge Payload Stream**: `BridgeFrameChunk` messages over UDP.
- **Local Descriptor Stream** (receiver side): standard `FrameDescriptor` on IPC or local channel.

Stream ID assignment is deployment-specific. A common pattern is to reserve a UDP stream ID range for bridge payloads, distinct from local descriptor/control streams.

---

## 5. Bridge Frame Chunk Message (Normative)

The bridge transports frames as a sequence of chunks. Each chunk carries a small header plus a byte slice of the frame payload. The first chunk includes the serialized `TensorSlotHeader256` so the receiver can reconstruct metadata without access to remote SHM.

### 5.1 Message Fields

`BridgeFrameChunk` fields:

- `streamId : u32`
- `epoch : u64` (source epoch)
- `seq : u64` (frame identity; equals `frame_id`)
- `chunkIndex : u32` (0-based)
- `chunkCount : u32`
- `chunkOffset : u32` (offset into payload)
- `chunkLength : u32`
- `payloadLength : u32` (total payload bytes)
- `headerIncluded : Bool` (TRUE only for `chunkIndex==0`)
- `headerBytes[256]` (present only when `headerIncluded=TRUE`)
- `payloadBytes` (varData)

### 5.2 Chunking Rules

- `chunkCount` MUST be >= 1.
- For `chunkIndex==0`, `headerIncluded` MUST be TRUE and `headerBytes` MUST contain the full 256-byte `TensorSlotHeader256`.
- For `chunkIndex>0`, `headerIncluded` MUST be FALSE.
- `chunkOffset` and `chunkLength` MUST describe a non-overlapping slice of the payload.
- The sum of all `chunkLength` values MUST equal `payloadLength`.
- Chunks SHOULD be sized to fit within the configured MTU for the UDP channel to avoid fragmentation.
- Implementations SHOULD size chunks to allow Aeron `try_claim` usage (single buffer write) and avoid extra copies.
- When `headerIncluded=TRUE`, `headerBytes` length MUST be 256. When `headerIncluded=FALSE`, `headerBytes` length MUST be 0.
- `payloadBytes` length MUST equal `chunkLength`.

### 5.3 Loss Handling

If any chunk is missing or inconsistent, the receiver MUST drop the frame and MUST NOT publish a `FrameDescriptor` for it.

---

## 6. Receiver Re-materialization (Normative)

Upon receiving all chunks for a frame:

1. Validate `streamId`, `epoch`, `seq`, and chunk consistency.
2. Select the local payload pool and slot using configured mapping rules (e.g., smallest stride >= `payloadLength`).
3. Write payload bytes into the selected local SHM payload pool.
4. Write the `TensorSlotHeader256` into the local header ring (with `frame_id` and `seq` preserved), but override `pool_id` and `payload_slot` to match the local mapping.
5. Commit via the standard `commit_word` protocol.
6. Publish a local `FrameDescriptor` on the receiver's descriptor stream.

The receiver MUST treat `headerBytes.frame_id` as the canonical frame identity and MUST ensure it matches `seq`.

---

## 7. Descriptor Semantics (Normative)

The bridge receiver publishes a standard `FrameDescriptor` for the re-materialized frame. `headerIndex` and `payloadSlot` refer to the receiver's local SHM pools.

Bridge senders MUST NOT publish local `FrameDescriptor` messages over UDP; only `BridgeFrameChunk` messages are carried over the bridge transport.

---

## 7.1 Metadata Forwarding (Normative)

Bridge instances MUST forward `DataSourceAnnounce` and `DataSourceMeta` from the source stream to the receiver host. Forwarded metadata MUST preserve `stream_id` and `meta_version` to keep re-materialized frames consistent with local consumers.

---

## 8. Liveness and Epochs

- The bridge MUST treat an epoch change on the source stream as a remap boundary.
- If `epoch` changes, the receiver MUST drop any in-flight bridge frames and wait for new frames with the new epoch.

---

## 9. Control and QoS (Informative)

Bridge instances MAY forward or translate `QosProducer`/`QosConsumer` messages, but this is optional. A minimal bridge only handles payload and local descriptor publication.

---

## 10. Bridge SBE Schema (Normative)

```
<?xml version="1.0" encoding="UTF-8"?>
<sbe:messageSchema xmlns:sbe="http://fixprotocol.io/2016/sbe"
                   package="shm.tensorpool.bridge"
                   id="902"
                   version="1"
                   semanticVersion="1.0"
                   byteOrder="littleEndian">

  <types>
    <composite name="messageHeader">
      <type name="blockLength" primitiveType="uint16"/>
      <type name="templateId"  primitiveType="uint16"/>
      <type name="schemaId"    primitiveType="uint16"/>
      <type name="version"     primitiveType="uint16"/>
    </composite>

    <composite name="varDataEncoding">
      <type name="length"  primitiveType="uint32" maxValue="1073741824"/>
      <type name="varData" primitiveType="uint8" length="0"/>
    </composite>

    <enum name="Bool" encodingType="uint8">
      <validValue name="FALSE">0</validValue>
      <validValue name="TRUE">1</validValue>
    </enum>
  </types>

  <sbe:message name="BridgeFrameChunk" id="1">
    <field name="streamId"       id="1" type="uint32"/>
    <field name="epoch"          id="2" type="uint64"/>
    <field name="seq"            id="3" type="uint64"/>
    <field name="chunkIndex"     id="4" type="uint32"/>
    <field name="chunkCount"     id="5" type="uint32"/>
    <field name="chunkOffset"    id="6" type="uint32"/>
    <field name="chunkLength"    id="7" type="uint32"/>
    <field name="payloadLength"  id="8" type="uint32"/>
    <field name="headerIncluded" id="9" type="Bool"/>
    <data  name="headerBytes"    id="10" type="varDataEncoding"/>
    <data  name="payloadBytes"   id="11" type="varDataEncoding"/>
  </sbe:message>

</sbe:messageSchema>
```
