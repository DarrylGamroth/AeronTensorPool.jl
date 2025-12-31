# Implementation Guide (Wire v1.1 + Driver v1.0)

This guide maps the wire-level spec and driver model spec into concrete implementation steps.
It is implementation-oriented and references the specs for normative rules.

References:
- Wire spec: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- Driver model: `docs/SHM_Driver_Model_Spec_v1.0.md`

## 1. Scope and Roles

Wire-level roles:
- Producer: owns SHM regions and publishes descriptors/progress/QoS.
- Consumer: maps SHM regions and reads frames based on descriptors.
- Supervisor: aggregates QoS, issues ConsumerConfig.
- Bridge/Decimator: optional scaffolds.

Driver-model roles:
- SHM Driver: authoritative owner of SHM lifecycle, epochs, and URIs.
- Producer Client: attaches to driver and writes into driver-owned SHM.
- Consumer Client: attaches to driver and maps driver-owned SHM.

The wire spec is always in force. The driver model is optional and used when the deployment chooses a shared SHM driver.

## 2. Wire Spec Implementation Summary

SHM layout:
- Superblock size: 64 bytes, little-endian only (Wire 6-8).
- Header slots: 256 bytes per slot.
- Payload pools: fixed stride, same nslots as header ring.

Commit protocol:
- commit_word = (frame_id << 1) | 1 for WRITING.
- commit_word = (frame_id << 1) for COMMITTED.
- Use acquire/release semantics and seqlock read rules.

Producer flow (Wire 15.19):
1) Write commit_word WRITING.
2) Write payload bytes and ensure visibility.
3) Write header fields (except commit_word).
4) Write commit_word COMMITTED (release).
5) Publish FrameDescriptor; optionally FrameProgress.

Consumer flow (Wire 15.19):
1) Read commit_word (acquire); drop if odd.
2) Read header and payload.
3) Re-read commit_word (acquire); drop if changed or odd.
4) Accept only if header.frame_id == descriptor.seq.

Control plane:
- ShmPoolAnnounce informs mmap and validation.
- ConsumerHello advertises capabilities (progress hints).
- ConsumerConfig provides mode and fallback.
- QosProducer/QosConsumer report drops and liveness.

## 3. Driver Model Integration Summary

Driver responsibilities (Driver 3-4):
- Create, initialize, and own SHM backing files.
- Maintain epochs and layout_version.
- Enforce exclusive producer per stream.
- Publish ShmPoolAnnounce.

Attach protocol (Driver 4.2-4.4):
- Client sends ShmAttachRequest.
- Driver replies ShmAttachResponse with URIs, epoch, layout_version, lease_id.
- Clients validate required fields and fail closed on protocol errors.

Lease lifecycle (Driver 4.7-4.9):
- Keepalives extend lease; expiry or revoke forces detach.
- Driver publishes ShmLeaseRevoked and bumps epoch on producer lease loss.
- Clients stop using mappings and reattach on revoke/expiry.

## 4. Deployment Modes

Standalone mode:
- Producer owns SHM allocation and announces URIs directly.
- Consumers map SHM using announced URIs.

Driver mode:
- SHM Driver owns allocation and announces URIs.
- Producer/consumer attach with leases and must not create SHM files.

## 5. Path Layout and Containment (Wire 15.21a)

Consumers MUST map only the paths announced by the producer/driver.
Implement path containment checks before mmap:
- Require absolute paths.
- Canonicalize to realpath.
- Ensure path is within allowed_base_dirs.
- Reject non-regular files and unknown schemes.

Default layout (informative):
- `<shm_base_dir>/<namespace>/<producer_instance_id>/epoch-<E>/`
- `header.ring` and `payload-<pool_id>.pool`

## 6. Aeron Usage

Control plane:
- Use try_claim to write small messages and commit.
- Prefer separate stream IDs for control/descriptor/qos/metadata.

Subscriptions:
- Use FragmentAssembler per subscription.
- Decode SBE messages in-place and reuse decoders.

## 7. Timers and Work Loops

Use polled timers to manage periodic work:
- Announce cadence (1 Hz recommended).
- QoS cadence (1 Hz recommended).
- Driver keepalive cadence (default 1 Hz).

Fetch the clock once per duty cycle and pass now_ns through the work loop.

## 8. Type Stability and Allocation-Free Hot Paths

After initialization:
- Preallocate buffers for SBE messages and SHM reads.
- Avoid VarData/VarAscii parsing in hot loops.
- Reuse decoders for SHM headers and descriptors.
- Keep hot-path functions concrete and avoid dynamic dispatch.

## 9. Tooling and Tests

Tooling:
- CLI utilities for attach/detach/keepalive and control messages.
- Scripts to run producer/consumer/supervisor/driver.

Testing:
- Unit tests for SHM validation, seqlock behavior, URI parsing.
- Integration tests with embedded media driver.
- Allocation tests under load for producer and consumer loops.

## 10. References for Implementers

Specs:
- `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- `docs/SHM_Driver_Model_Spec_v1.0.md`

Project docs:
- `docs/OPERATIONAL_PLAYBOOK.md`
- `docs/INTEGRATION_EXAMPLES.md`
- `docs/USE_CASES.md`
