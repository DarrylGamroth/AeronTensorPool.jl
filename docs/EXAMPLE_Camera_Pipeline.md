# Camera Pipeline Example (3 Cameras, Driver Model)

This example shows a concrete deployment using the Driver Model with three cameras producing raw frames and three processing tasks producing derived frames. It assumes the wire spec is `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md` and the driver spec is `docs/SHM_Driver_Model_Spec_v1.0.md`.

Related config example: `docs/examples/driver_camera_example.toml`.

## Overview

- 3 camera producers: `cam1`, `cam2`, `cam3`
- 3 processing stages: `proc1`, `proc2`, `proc3`
- Each processing stage consumes one camera stream and produces a new stream.
- The driver owns SHM pools and creates them on-demand via `publishMode=EXISTING_OR_CREATE`.

## Stream IDs

- Raw camera streams: `stream_id = 1001, 1002, 1003`
- Processed streams: `stream_id = 2001, 2002, 2003`

## Driver Pool Profiles (example policy)

Driver configuration includes fixed pool profiles per stream type:

- **raw_profile**
  - `header_nslots = 1024`
  - payload pools:
    - `pool_id=1`: `stride_bytes = 1 MiB`
    - `pool_id=2`: `stride_bytes = 4 MiB`
- **processed_profile**
  - `header_nslots = 512`
  - payload pools:
    - `pool_id=1`: `stride_bytes = 512 KiB`
    - `pool_id=2`: `stride_bytes = 2 MiB`

The driver chooses a profile based on stream namespace or a configured policy (e.g., stream_id range).

Example sizing:
- 1920x1080 gray16 is ~4 MiB, fits `pool_id=2` in raw_profile.
- Processed outputs are smaller, fitting processed_profile pools.

## Attach and Create (Control Plane)

Each producer/consumer attaches using `ShmAttachRequest`:

- Camera producer `cam1`:
  - `stream_id=1001`
  - `role=PRODUCER`
  - `publishMode=EXISTING_OR_CREATE`
- Processor `proc1`:
  - `stream_id=1001` as `CONSUMER`
  - `stream_id=2001` as `PRODUCER`

The driver responds with `ShmAttachResponse` containing the pool URIs, `epoch`, and `leaseId`. All URIs must pass wire-spec validation.

## Camera Producer Flow (per camera)

1. Attach as PRODUCER on `stream_id=1001`.
2. Wait for `ShmPoolAnnounce` (optional if response provides full URIs).
3. For each frame:
   - Compute `header_index = seq & (nslots - 1)`.
   - Choose the smallest pool with `stride_bytes >= payload_length`.
   - Write payload to the pool slot.
   - Write header fields in `TensorSlotHeader256`.
   - Commit `commit_word` and publish `FrameDescriptor`.

## Processor Flow (per pipeline stage)

Processor `proc1` consumes from `stream_id=1001` and produces to `stream_id=2001`.

1. Attach as CONSUMER to `stream_id=1001`.
2. Attach as PRODUCER to `stream_id=2001`.
3. Loop:
   - Poll `FrameDescriptor` on `stream_id=1001`.
   - Read header/payload using the seqlock protocol.
   - Process the pixels to a new output buffer (owned by `stream_id=2001` pools).
   - Publish `FrameDescriptor` on `stream_id=2001`.
   - Do not "release" input buffers; the source producer overwrites slots per the protocol.

## Consumer Flow (downstream)

Any downstream consumer attaches to `stream_id=2001..2003` and uses the same seqlock read protocol to read processed frames.

## Revocation and Recovery

- If a producer lease expires or is revoked, the driver emits `ShmLeaseRevoked` followed by `ShmPoolAnnounce` with a bumped `epoch`.
- Consumers drop in-flight frames, unmap, and wait for the new announce.

## Sequence (simplified)

```
cam1                 driver                proc1
 | ShmAttachRequest  |                      |
 |------------------>|                      |
 | ShmAttachResponse |                      |
 |<------------------|                      |
 |                    | ShmPoolAnnounce     |
 |                    |-------------------->|
 | FrameDescriptor   |                      |
 |------------------>| (via Aeron stream)   |
 |                    |                      |
 |                    |  (proc1 reads SHM)   |
 |                    |  (proc1 writes SHM)  |
 |                    |  FrameDescriptor    |
 |                    |<--------------------|
```
