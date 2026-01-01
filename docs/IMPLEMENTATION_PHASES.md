# Implementation Phases (Wire + Driver Specs)

This plan sequences implementation work to match the Wire Spec v1.1 and the Driver Model Spec v1.0.
Each phase has clear deliverables and validation so tasks can be assigned and tracked.

References:
- Wire spec: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- Driver model: `docs/SHM_Driver_Model_Spec_v1.0.md`

## Phase 0 - Alignment and Defaults

Goals
- Align constants, layout, and codegen with the wire spec.
- Decide defaults for config and path layout.

Deliverables
- Shared constants (superblock size, slot bytes, magic, MAX_DIMS).
- Canonical path layout and containment checks (15.21a).
- SBE codegen task with fixed MAX_DIMS.
- Config schema (TOML + env overrides) and default paths.

Validation
- Unit tests for constants and path containment rules.
- Schema codegen in CI.

Spec refs
- Wire: 6-8, 15.21a

Status
- Complete (shared constants, canonical path helpers, config defaults, SBE codegen task).

## Phase 1 - SHM Core and Seqlock

Goals
- Implement mmap helpers and seqlock accessors.
- Implement ShmRegionSuperblock and TensorSlotHeader256 access in-place.

Deliverables
- SHM URI parsing and validation.
- mmap helpers for read/write.
- ShmRegionSuperblock read/write helpers.
- TensorSlotHeader256 write/read helpers.
- Seqlock helpers (begin write, commit, read begin/end).

Validation
- Unit tests for superblock validation and seqlock read rules.
- Drop cases for odd or unstable commit_word.

Spec refs
- Wire: 7.1, 8.1-8.3, 15.22

Status
- Complete (SHM IO helpers, superblock/header accessors, seqlock helpers, tests).

## Phase 2 - Producer Core Path

Goals
- Publish frames per the normative algorithm.
- Emit descriptors and optional progress.

Deliverables
- Producer init: create SHM regions, write superblocks, open Aeron pubs.
- Publish path: commit_word protocol, payload write, header fill, descriptor publish.
- Periodic announces, QoS, activity timestamp refresh.
- try_claim-based Aeron sending for small control messages.

Validation
- Frame identity (frame_id == seq) enforced.
- Descriptor/header_index mapping correct.
- No allocations in hot loop after init.

Spec refs
- Wire: 8.3, 9, 10.2, 15.19

Status
- Complete (producer init, publish path, announce/QoS cadence, try_claim for control).

## Phase 3 - Consumer Core Path

Goals
- Map SHM regions and read frames with seqlock.
- Implement modes and drop accounting.

Deliverables
- ShmPoolAnnounce handling and region validation.
- Descriptor handler with seqlock read, drop rules, and seq tracking.
- Modes: STREAM, LATEST, DECIMATED.
- Fallback logic when SHM is invalid or not supported.

Validation
- Unit tests for drops_gap and drops_late.
- Remap on epoch or layout mismatch.

Spec refs
- Wire: 10.1, 10.2, 15.19, 15.21, 15.22

Status
- Complete (mapping, seqlock read, mode handling, drops tracking, fallback handling).

## Phase 4 - Control Plane and QoS

Goals
- Implement ConsumerHello, ConsumerConfig, QosProducer, QosConsumer.
- Apply progress throttling rules.

Deliverables
- ConsumerHello publishing with progress hint aggregation.
- QosProducer/QosConsumer periodic publish.
- ConsumerConfig handling (mode and fallback URI).

Validation
- Progress emission gated by supports_progress.
- QoS counters track drops_gap and drops_late.

Spec refs
- Wire: 10.1, 10.4, 15.14, 15.18

Status
- Complete (ConsumerHello, ConsumerConfig, QosProducer/QosConsumer, progress floors).

## Phase 5 - Supervisor Agent

Goals
- Track liveness and issue policy changes.

Deliverables
- Subscriptions to announce and QoS streams.
- Liveness tracking and stale detection.
- ConsumerConfig issuance based on policy.

Validation
- Stale detection at 3-5x announce cadence.

Spec refs
- Wire: 10.5, 15.14

Status
- Complete (announce/QoS subscriptions, liveness tracking, ConsumerConfig emission).

## Phase 6 - Driver Model Core

Goals
- Implement the external SHM Driver and attach protocol.
- Keep the client protocol surface C-friendly for the planned C client.
- Organize code into shared, client, and driver modules.

Deliverables
- Driver agent with exclusive producer enforcement per stream.
- ShmAttachRequest/Response handling and validation.
- ShmLeaseKeepalive processing with expiry.
- ShmDetachRequest/Response handling.
- ShmLeaseRevoked publishing and epoch bump rules.
- Driver TOML/env configuration surface per Driver Spec §16.
- Driver shutdown notice and QoS telemetry (Aeron counters).

Validation
- Protocol error handling: fail closed on missing fields or null sentinels.
- Lease expiry triggers epoch bump and announce.

Spec refs
- Driver: 2-4, 6-7

Status
- Complete (QoS/shutdown extensions and tests added).

## Phase 7 - Driver Integration (Producer/Consumer)

Goals
- Make producer/consumer operate in driver-managed mode.

Deliverables
- Producer/consumer attach flows and lease tracking.
- Client configuration is API-only (no TOML or environment variables).
- Driver-provided URIs and layout_version overrides.

Validation
- Reattach on lease revoke or expiry.
- No SHM creation outside the driver in driver mode.

Spec refs
- Driver: 3-4, 4.7, 4.9
- Wire: 15.21, 15.21a

Status
- Complete (driver-aware producer/consumer flows, lease revoke reattach, integration tests for driver mode).

## Phase 8 - Tooling and Ops

Goals
- Provide CLI tools and operational docs.

Deliverables
- CLI utilities for attach/detach/keepalive and control-plane messages.
- Run scripts for producer/consumer/supervisor/driver roles.
- Operational playbook for hugepages, Aeron dir, and GC monitoring.
  - Standalone mode runs the SHM driver embedded in-process (analogous to embedded Aeron media driver usage).

Validation
- Tooling exercises driver protocol end-to-end.

Spec refs
- Driver: 4.5
- Wire: 15.13

Status
- Complete (driver CLI utilities, driver run scripts, and ops notes updated).

## Phase 9 - Tests and Compliance

Goals
- Comprehensive spec compliance tests.

Deliverables
- Unit tests for SHM validation and seqlock rules.
- Integration tests for producer/consumer/supervisor flow.
- Driver protocol integration tests with lease expiry.
- Allocation tests for hot paths.

Validation
- End-to-end test with embedded media driver.
- Allocation budget stays flat after init.

Spec refs
- Wire: 15.13
- Driver: 4.7, 4.7a

Status
- Complete (driver protocol lease-expiry test added; system smoke test available via TP_RUN_SYSTEM_SMOKE).

## Phase 10 - Documentation and Examples

Goals
- Provide usage examples and integration guidance.

Deliverables
- Producer/consumer examples (standalone and driver mode).
- Driver deployment example.
- BGAPI2-style buffer handoff example.
- Docstrings for public APIs.

Validation
- Documenter build passes with examples.

Spec refs
- Wire: 1-5 (informative)
- Driver: 1-2 (informative)

Status
- Complete (driver/standalone examples, deployment notes, and public API docstrings updated).

## Phase 11 - Optional Features

Goals
- Prepare optional bridge and decimator scaffolding.

Deliverables
- Bridge/decimator scaffolds and TODO notes until formats exist.
- Optional UDP payload format placeholder.

Validation
- Scaffolds compile; no operational dependency.

Spec refs
- Wire: 12

Status
- In progress (bridge schema added; sender/receiver scaffolds with chunking, assembly, announce forwarding, metadata forwarding, and QoS forwarding; rematerialization TODO).

## Driver Implementation Checklist (decided)

- Implement driver config per Driver Spec §16 (TOML surface + env overrides).
- Client API is task-based proxies with a response poller (Aeron-style).
- Control-plane mapping follows driver config: control/announce/qos channels + stream IDs.
- Tests must include driver protocol integration and end-to-end driver-mode smoke test.
