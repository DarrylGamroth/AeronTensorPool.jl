# Implementation Phases (Aeron Tensor Pool, Julia)

This plan sequences implementation into concrete phases with deliverables, validation, and spec links.
It assumes SBE codecs are already generated in `src/gen` and favors minimal dependencies.

## Dependency Decisions (pre-review)

These decisions should be made before deeper implementation work begins.

- SBEDomainMapper.jl: Defer for v1.1. We already have SBE.jl codecs, and the initial agents can use direct encoders/decoders for tight control and zero-allocation. Revisit later if we want schema-aligned domain structs, publishing proxies, or standardized adapters.
- Hsm.jl: Defer unless agent lifecycle becomes complex. Agent.jl + explicit state enums is sufficient for v1.1. Introduce Hsm.jl only if we need hierarchical states, richer transitions, or formalized event handling across roles.
- RtcFramework.jl: Use as a reference only. Patterns for PollerRegistry usage and FragmentAssembler adapters are valuable, and its PolledTimer is a good model for zero-allocation timeouts, but we should not take a dependency yet. We can mirror its timer and adapter structure inside this repo.

## Phase 0 - Baseline and Alignment

Goals
- Confirm constants and layout assumptions match the spec.
- Define the minimal config surface and shared constants.

Status
- Complete (constants, configs, and TimerSet-based polled timers integrated for periodic work).

Deliverables
- Shared constants module (superblock size, slot bytes, magic, layout_version, MAX_DIMS).
- Config structs for Producer/Consumer/Supervisor (URIs, stream IDs, nslots, stride classes, cadences).
- Timer utility selection (PolledTimer-style scheduler for periodic announces/QoS).
- Decision log for dependency choices (this document).

Validation
- Static checks for power-of-two nslots and stride alignment.
- Compile-time assertions for MAX_DIMS matching the generated schema.

Spec refs
- `docs/SHM_Aeron_Tensor_Pool.md` sections 6-8, 15.1, 15.5, 15.8, 15.22

## Phase 1 - SHM Utilities and Superblock IO

Goals
- Build SHM URI parsing, validation, and mmap helpers.
- Implement superblock read/write for producers and consumers.

Deliverables
- `parse_shm_uri`, `validate_uri`, `mmap_shm` helpers.
- Superblock write (producer) and validate (consumer) helpers.
- Atomic commit_word load/store wrappers with acquire/release.

Validation
- Unit tests for URI parsing and unknown-param rejection.
- Superblock validation tests (magic/layout/epoch/region_type/stride/nslots).

Spec refs
- 7.1, 15.1, 15.22

Status
- Complete (helpers + unit tests in place).

## Phase 2 - Producer Core Path (SHM + Descriptor)

Goals
- Implement producer init, SHM allocation, and publish loop.

Deliverables
- Producer init: allocate header/pool files, write superblocks, open Aeron pubs.
- Frame publish path: commit_word protocol, payload write, header fill, descriptor publish.
- Periodic announce, QoS, and activity timestamp refresh.

Validation
- Producer publishes descriptors with correct seq/header_index mapping.
- commit_word transitions: WRITING -> COMMITTED with release semantics.

Spec refs
- 8.1-8.2, 10.2.1, 15.19

Status
- Complete (producer init + publish path + announce/QoS cadence).

## Phase 3 - Consumer Core Path (Mapping + Seqlock Read)

Goals
- Implement consumer mapping, frame validation, and seqlock read.

Deliverables
- On ShmPoolAnnounce: validate + mmap regions, cache epoch.
- Descriptor handler: seqlock read and payload extraction.
- Drop accounting: drops_gap and drops_late tracking.
- Mode handling: STREAM / LATEST / DECIMATED.

Validation
- Drop on odd/unstable commit_word.
- Drop on frame_id != descriptor.seq.
- Remap on epoch/layout mismatch.

Spec refs
- 10.2.1, 11, 15.19, 15.21

Status
- Complete (mapping, seqlock read, mode handling, drops accounting with max_outstanding_seq_gap resync, header validation including nslots power-of-two and epoch checks, commit_word frame_id consistency, dtype-aware stride inference with min stride checks, payload_offset validation, enum decode safety, announce-time superblock revalidation with PID change handling, fallback handling).

## Phase 4 - Control Plane and QoS

Goals
- Implement ConsumerHello, QosConsumer, QosProducer, and ShmPoolAnnounce cadence.

Deliverables
- ConsumerHello (supports_progress, progress hints).
- QosProducer/QosConsumer periodic emissions.
- Optional ConsumerConfig handling (mode changes, fallback_uri).

Validation
- QoS counters updated correctly.
- Progress hints aggregated at producer without violating floors.

Spec refs
- 10.1, 10.4, 15.14, 15.18

Status
- Complete (ConsumerHello with nullValue encoding for absent progress hints, QosProducer/QosConsumer, ConsumerConfig handling, producer progress floors enforced).

## Phase 5 - Supervisor Agent

Goals
- Track producer/consumer liveness and issue ConsumerConfig.

Deliverables
- Subscriptions to announce/QoS/control streams.
- Liveness tracking using announce/activity timestamps.
- ConsumerConfig issuance and logging.

Validation
- Stale detection using 3-5x announce interval.
- Correct handling of epoch changes and re-registrations.

Spec refs
- 10.5, 15.14, 15.16

Status
- Complete (announce/QoS subscriptions, liveness tracking using announce/QoS/hello timestamps, ConsumerConfig emission, integration test coverage).

## Phase 6 - Optional Bridge and Decimator

Goals
- Provide fallback and downsampled streams.

Deliverables
- Bridge: scaffold only; no on-wire format for payload/descriptor defined yet.
- Decimator: scaffold only; republish subset once a format is defined.

Validation
- Preserve seq/frame_id identity.
- Only republish committed frames.

Spec refs
- 12, 15.20

Status
- Scaffolded (waiting on bridge/decimator message format).

## Phase 7 - Testing and Tooling

Goals
- Ensure spec compliance and regression safety.

Deliverables
- Unit tests for SHM validation, seqlock behavior, epoch remap.
- Integration test harness for producer/consumer loopback (IPC).

Validation
- Spec checklist from 15.13 satisfied.

Spec refs
- 15.13

Status
- Complete (unit + Aeron embedded driver integration tests in place, including remap/fallback and seqlock drops; CLI tooling tested and can send ConsumerConfig).

## Phase 7b - End-to-End System Bring-up

Goals
- Enable a complete multi-process system test (producer + consumer + supervisor).

Deliverables
- Runner wiring for AgentRunner vs invoker mode in a real process (startup/shutdown, signal handling).
- Configuration loader (TOML + env overrides) for each role.
- Launch scripts or CLI tooling to start producer/consumer/supervisor with consistent URIs/stream IDs.
- E2E smoke test harness: launch embedded or external media driver, create SHM pools, send real frames, verify QoS/liveness.
- Cleanup/shutdown behavior for SHM files and Aeron directory in test runs.

Validation
- A full system test can be run from a single command and completes without manual setup.

Spec refs
- 15.13, 15.14, 15.22

Status
- Complete (config loader + env overrides, role runner, and in-process system smoke test harness are implemented).

## Phase 8 - Perf and Ops Hardening

Goals
- Reach steady-state zero-allocation and deployment readiness.

Deliverables
- Preallocation audit and @allocated checks in hot paths.
- CPU pinning/NUMA guidance (docs).
- Optional Aeron counters integration for metrics.

Validation
- Perf profile shows zero allocations in steady state.
- Drops and liveness behave under load.

Spec refs
- 15.7a, 15.14, 15.17

Status
- Complete (allocation load checks plus optional GC monitoring added, perf/ops hardening guidance documented).

## Phase 9 - Observability and Error Taxonomy

Goals
- Add structured error types where helpful and improve operational diagnostics.

Deliverables
- Optional exception hierarchy (e.g., SHM validation errors, Aeron init errors).
- Structured logging fields and counter documentation.
- Review and consolidate error handling behavior across agents.

Validation
- Error paths produce actionable diagnostics without fatal crashes.

Status
- Complete (error taxonomy added, logging guidance updated).

## Phase 10 - Bridge/Decimator Completion

Goals
- Implement bridge/decimator once on-wire format is defined.

Deliverables
- Bridge/decimator message format, full implementation, and tests.

Status
- Deferred (no wire format defined yet; optional UDP format can be added when spec is ready).

## Phase 11 - Operational Playbooks

Goals
- Provide deployment profiles and troubleshooting guidance.

Deliverables
- Ops runbook, tuning matrix, and failure playbook.
- Health checks and counter-based alerting guidance.

Status
- Complete (ops playbook, health checks, and troubleshooting guidance added).

## Phase 12 - Documentation and API Guide

Goals
- Provide comprehensive API docs, docstrings, and integration examples.

Deliverables
- Docstrings for all public functions and types.
- Documenter.jl configuration for generated docs.
- Integration guides (BGAPI2 buffer registration, invoker-mode hosting).
- Public API index and examples referencing the spec.

Status
- Complete (docstrings added; Documenter site scaffolding added; integration docs linked).

## Phase 13 - Benchmarking and Performance Characterization

Goals
- Provide repeatable benchmarks for throughput, latency, and allocation behavior.

Deliverables
- Benchmark suite (e.g., BenchmarkTools) covering producer/consumer/supervisor loops.
- End-to-end throughput/latency benchmarks with embedded media driver.
- Allocation regression tests under sustained load.
- Benchmark reporting scripts and baseline numbers.

Status
- Complete (benchmark suite and scripts added; system benchmark optional).
