# Spec Compliance Matrix

This document audits each specification document section-by-section and records **implementation presence** and **correctness**. The specs are authoritative; this matrix reflects the Julia implementation status as of the current branch.

Status legend:
- Implemented: behavior present.
- Partial: behavior present but incomplete.
- Not implemented: no code support yet.
- Informative: non-normative guidance (not required).

Correctness legend:
- Compliant: implementation matches the spec (verified by code inspection/tests).
- Needs Review: implementation exists but correctness is unclear or not fully validated.
- Noncompliant: known mismatch with spec.
- N/A: not applicable (informative or not implemented).

---

## SHM_Tensor_Pool_Wire_Spec_v1.2.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Goals | Informative | N/A | Scope guidance. |
| 2. Non-Goals (v1) | Informative | N/A | Scope guidance. |
| 3. High-Level Architecture | Informative | N/A | Architecture overview. |
| 4. Shared Memory Backends | Implemented | Compliant | File-backed shm only (`shm:file`) as required by spec. |
| 4.1 Region URI Scheme | Implemented | Compliant | `src/shm/uri.jl` parses/validates shm:file URIs. |
| 4.2 Behavior Overview | Informative | N/A | Background. |
| 5. Control-Plane and Data-Plane Streams | Implemented | Compliant | Control/descriptor/QoS/metadata pubs+subs across agents with schema gating tests. |
| 6. SHM Region Structure | Implemented | Compliant | Superblock + header ring + pools with encode/decode tests. |
| 7. SBE Messages Stored in SHM | Implemented | Compliant | `ShmRegionSuperblock`, `TensorSlotHeader256` via schema with tests. |
| 7.1 ShmRegionSuperblock | Implemented | Compliant | Encode/decode tests in `test/test_shm_superblock.jl`. |
| 8. Header Ring | Implemented | Compliant | Header ring layout tested via slot header tests. |
| 8.1 Slot Layout | Implemented | Compliant | 256-byte slot header validated in tests. |
| 8.2 SlotHeader and TensorHeader | Implemented | Compliant | Tensor header validation tests cover template gating. |
| 8.3 Commit Encoding via seq_commit | Implemented | Compliant | Seqlock encoding tests cover commit semantics. |
| 9. Payload Pools | Implemented | Compliant | Pool addressing helpers + payload slot tests. |
| 10. Aeron + SBE Messages (Wire Protocol) | Implemented | Compliant | Schema gating and integration tests cover encode/decode. |
| 10.1 Service Discovery and SHM Coordination | Implemented | Compliant | Discovery integration + driver attach tests. |
| 10.2 Data Availability | Implemented | Compliant | Seqlock read/drop tests validate descriptor availability. |
| 10.3 Per-Data-Source Metadata | Implemented | Compliant | Metadata API tests cover announce/meta flow. |
| 10.4 QoS and Health | Implemented | Compliant | QoS monitor + callbacks tests. |
| 10.5 Supervisor / Unified Management | Partial | N/A | Supervisor exists; service commands not implemented. |
| 11. Consumer Modes | Implemented | Compliant | RATE_LIMITED mode tests in `test/test_consumer_rate_limited.jl`. |
| 12. Bridge Service (Optional) | Implemented | Compliant | Bridge integration tests cover sender/receiver behavior. |
| 13. Implementation Notes | Informative | N/A | Background. |
| 14. Open Parameters | Informative | N/A | Deployment-specific. |
| 15. Additional Requirements and Guidance | Partial | Needs Review | See subsections below. |
| 15.1 Validation and Compatibility | Implemented | Compliant | Superblock/URI validation tests cover compatibility checks. |
| 15.2 Epoch Lifecycle | Implemented | Compliant | Driver epoch bump/remap tests in `test/test_driver_restart_bumps_epoch.jl`. |
| 15.3 Commit Protocol Edge Cases | Implemented | Compliant | Seqlock drop tests cover instability cases. |
| 15.4 Overwrite and Drop Accounting | Implemented | Compliant | drops_gap/drops_late tracked; gap threshold + tests cover seqlock/drop paths. |
| 15.5 Pool Mapping Rules (v1.2) | Implemented | Compliant | Payload slot mismatch/drop tests cover v1.2 mapping rules. |
| 15.6 Sizing Guidance | Informative | N/A | Guidance only. |
| 15.7 Timebase | Implemented | Needs Review | Cached epoch clock used in agents. |
| 15.7a NUMA Policy | Informative | N/A | Deployment guidance. |
| 15.8 Enum and Type Registry | Not implemented | N/A | Registry not defined. |
| 15.9 Metadata Blobs | Implemented | Needs Review | Metadata helpers in client API. |
| 15.10 Security and Permissions | Implemented | Compliant | Restrictive SHM modes applied; permissions tests cover defaults. |
| 15.11 Stream Mapping Guidance | Informative | N/A | Guidance only. |
| 15.12 Consumer State Machine (suggested) | Implemented | Compliant | Consumer phase tracked (UNMAPPED/MAPPED/FALLBACK) with tests. |
| 15.13 Test and Validation Checklist | Partial | Needs Review | Not all checklist items covered. |
| 15.14 Deployment & Liveness | Implemented | Compliant | Operational checklist added in `docs/OPERATIONAL_PLAYBOOK.md`. |
| 15.15 Aeron Terminology Mapping | Informative | N/A | Reference. |
| 15.16 Reuse Aeron Primitives | Informative | N/A | Reference. |
| 15.16a File-Backed SHM Regions | Implemented | Compliant | shm:file URIs validated and used in tests. |
| 15.17 ControlResponse Error Codes | Implemented | Compliant | Driver response validation tests cover required fields/codes. |
| 15.18 Normative Algorithms (per role) | Implemented | Compliant | Seqlock encoding + header validation tests cover normative steps. |
| 15.20 Compatibility Matrix | Informative | N/A | Reference. |
| 15.21 Protocol State Machines (Normative) | Implemented | Compliant | Driver HSM + consumer phase model validated in tests. |
| 15.21a Filesystem Layout and Path Containment | Implemented | Compliant | Canonical layout + consumer containment checks align with spec. |
| 15.21a.1 Overview | Informative | N/A | Guidance only. |
| 15.21a.2 Shared Memory Base Directory | Implemented | Needs Review | `shm_base_dir` + `allowed_base_dirs` config. |
| 15.21a.3 Canonical Directory Layout | Implemented | Compliant | Layout matches `tensorpool-${USER}/<namespace>/<stream_id>/<epoch>/<pool_id>.pool` in `src/shm/paths.jl`. |
| 15.21a.4 Path Announcement Rule | Implemented | Compliant | URIs always announced; consumers do not derive paths. |
| 15.21a.5 Consumer Path Containment Validation | Implemented | Compliant | Canonical allowed dirs + realpath containment enforced in `src/agents/consumer/mapping.jl` with `O_NOFOLLOW` in `src/shm/linux.jl`. |
| 15.21a.6 Permissions and Ownership | Implemented | Compliant | Driver applies restrictive modes; tests cover permissions on SHM regions. |
| 15.21a.7 Cleanup and Epoch Handling | Implemented | Compliant | Epoch GC + cleanup tests cover behavior. |
| 15.22 SHM Backend Validation (v1.2) | Implemented | Compliant | URI/stride/hugepage validation tests present. |
| 16. Control-Plane SBE Schema (Draft) | Implemented | Compliant | Generated schemas used in tests and runtime. |

---

## SHM_Driver_Model_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Background. |
| 2. Roles | Implemented | Compliant | Driver/producer/consumer roles covered by integration tests. |
| 2.1 SHM Driver | Implemented | Compliant | `src/agents/driver/*` with integration tests. |
| 2.2 Producer Client | Implemented | Compliant | Producer agent + client API tested. |
| 2.3 Consumer Client | Implemented | Compliant | Consumer agent + client API tested. |
| 3. SHM Ownership and Authority | Implemented | Compliant | Driver owns SHM + control plane in tests. |
| 4. Attachment Model | Implemented | Compliant | Attach/detach protocol tested in driver suite. |
| 4.1 Leases | Implemented | Compliant | Lease lifecycle + keepalive tests. |
| 4.2 Attach Protocol | Implemented | Compliant | Request/response flow tests cover required fields. |
| 4.3 Attach Request Semantics | Implemented | Compliant | publish modes + role handling validated. |
| 4.4 Lease Keepalive | Implemented | Compliant | Keepalive + expiry tests. |
| 4.4a Schema Version Compatibility | Implemented | Compliant | Schema gating tests for driver control. |
| 4.5 Control-Plane Transport | Implemented | Compliant | Aeron control channel tests. |
| 4.6 Response Codes | Implemented | Compliant | Response code validation tests. |
| 4.7 Lease Lifecycle | Implemented | Compliant | Lease HSM tests. |
| 4.7a Protocol Errors | Implemented | Compliant | Error response tests for invalid requests. |
| 4.8 Lease Identity and Client Identity | Implemented | Compliant | Correlation/identity tests in attach flow. |
| 4.9 Detach Semantics | Implemented | Compliant | Detach handling tests. |
| 4.10 Control-Plane Sequences | Informative | N/A | Reference. |
| 4.11 Embedded Driver Discovery | Informative | N/A | Reference. |
| 4.12 Client State Machines | Partial | Needs Review | Driver HSM present; client state machine not formalized. |
| 4.13 Driver Termination | Implemented | Compliant | Shutdown notice/request tests. |
| 5. Exclusive Producer Rule | Implemented | Compliant | Driver enforces single producer in tests. |
| 6. Epoch Management | Implemented | Compliant | Epoch bump/remap tests. |
| 7. Producer Failure and Recovery | Implemented | Compliant | Epoch-based recovery in driver tests. |
| 8. Relationship to ShmPoolAnnounce | Implemented | Compliant | Announce cadence + mapping tests. |
| 9. Filesystem Safety and Policy | Implemented | Compliant | Canonical layout + containment validated. |
| 10. Failure of the SHM Driver | Partial | Needs Review | Failure behavior implemented; operational handling unverified. |
| 11. Stream ID Allocation Ranges | Implemented | Compliant | Stream allocation tests. |
| 17. Canonical Driver Configuration | Implemented | Compliant | Config loader/defaults tested. |
| Appendix A. Driver Control-Plane SBE Schema | Implemented | Compliant | Generated schema exercised by tests. |

---

## SHM_Aeron_UDP_Bridge_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Background. |
| 2. Roles | Implemented | Compliant | Sender/receiver bridge agents with integration tests. |
| 2.1 Bridge Sender | Implemented | Compliant | Sender path tested in bridge integration. |
| 2.2 Bridge Receiver | Implemented | Compliant | Receiver rematerialization + validation tests. |
| 2.3 Bidirectional Bridge Instances | Implemented | Compliant | Multi-mapping support covered by tests. |
| 3. Transport Model | Implemented | Compliant | UDP payload + control channel tests. |
| 4. Streams and IDs | Implemented | Compliant | Config + mapping enforcement tests. |
| 5. Bridge Frame Chunk Message | Implemented | Compliant | `BridgeFrameChunk` SBE encode/decode exercised in tests. |
| 5.1 Message Fields | Implemented | Compliant | Encoded via SBE; schema gating tests. |
| 5.2 Chunking Rules | Implemented | Compliant | Chunk sizing/segmentation covered by integration tests. |
| 5.3 Loss Handling | Implemented | Compliant | Drop + backpressure tests. |
| 5.3a Frame Assembly Timeout | Implemented | Compliant | Assembly timeout tests. |
| 5.4 Integrity | Partial | Needs Review | No checksum validation (optional). |
| 6. Receiver Re-materialization | Implemented | Compliant | Re-materialization + descriptor publish tests. |
| 7. Descriptor Semantics | Implemented | Compliant | Seq preservation tests. |
| 7.1 Metadata Forwarding | Implemented | Compliant | Metadata forwarding tests. |
| 7.2 Source Pool Announce Forwarding | Implemented | Compliant | Announce forwarding tests. |
| 8. Liveness and Epochs | Implemented | Compliant | Epoch checks/remap tests. |
| 9. Control and QoS | Implemented | Compliant | Control/QoS forwarding tests. |
| 10. Bridge Configuration | Implemented | Compliant | Config validation tests. |
| 11. Bridge SBE Schema | Implemented | Compliant | Generated schema exercised by tests. |

---

## SHM_Discovery_Service_Spec_v_1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Background. |
| 2. Roles | Implemented | Compliant | Provider/registry/client roles covered by tests. |
| 2.1 SHM Driver | Implemented | Compliant | Provider authoritative for local driver in tests. |
| 2.2 Discovery Provider | Implemented | Compliant | `src/agents/discovery/*` with integration tests. |
| 2.3 Client | Implemented | Compliant | Discovery client + API tests. |
| 3. Authority Model | Implemented | Compliant | Driver authoritative, registry advisory behavior validated. |
| 4. Transport and Endpoint Model | Implemented | Compliant | Request/response endpoints validated in tests. |
| 4.1 Control Plane Transport | Implemented | Compliant | Aeron request/response channels in tests. |
| 4.2 Endpoint Configuration | Implemented | Compliant | Config + validation tests. |
| 4.3 Response Channels | Implemented | Compliant | Response channel rules enforced in tests. |
| 5. Discovery Messages | Implemented | Compliant | Request/response encode/decode tests. |
| 5.0 Encoding and Optional Fields | Implemented | Compliant | Null handling via codecs tested. |
| 5.1 DiscoveryRequest | Implemented | Compliant | Request encode/decode tests. |
| 5.2 DiscoveryResponse | Implemented | Compliant | Registry/provider encode + client decode tests. |
| 6. Registry State and Expiry | Implemented | Compliant | Registry table + expiry tests. |
| 6.1 Indexing | Implemented | Compliant | Registry indexing tests. |
| 6.2 Expiry Rules | Implemented | Compliant | Expiry timer tests. |
| 6.3 Conflict Resolution | Implemented | Compliant | Replacement rules tested. |
| 6.4 Source Inputs | Implemented | Compliant | Provider/registry inputs tested. |
| 7. Client Behavior | Implemented | Compliant | Client poll/timeout tests. |
| 8. Multi-Host and Fleet Discovery | Implemented | Compliant | Multi-host registry entries covered by tests. |
| 9. Relationship to Bridging | Implemented | Compliant | Discovery + bridge integration test. |
| 10. Compatibility and Versioning | Implemented | Compliant | Schema gating tests. |
| 12. Security and Policy | Implemented | Compliant | Discovery advisory policy implemented. |
| 13. Operational Guidance | Informative | N/A | Guidance only. |
| 14. Example Flows | Informative | N/A | Reference. |
| 15. Discovery Schema | Implemented | Compliant | Generated schema exercised by tests. |

---

## SHM_Join_Barrier_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Draft spec only. |
| 2. Key Words | Informative | N/A | Draft spec only. |
| 3. Conformance | Not implemented | N/A | No implementation. |
| 4. Terminology | Informative | N/A | Draft spec only. |
| 5. Requirements and Constraints | Not implemented | N/A | No implementation. |
| 6. MergeMap | Not implemented | N/A | No implementation. |
| 7. SequenceJoinBarrier | Not implemented | N/A | No implementation. |
| 8. TimestampJoinBarrier | Not implemented | N/A | No implementation. |
| 9. LatestValueJoinBarrier | Not implemented | N/A | No implementation. |
| 10. Wire Format | Not implemented | N/A | No implementation. |
| 11. Examples | Informative | N/A | Draft spec only. |
| 12. Feature Comparison Matrix | Informative | N/A | Draft spec only. |
| 13. Usage Guidance | Informative | N/A | Draft spec only. |
| 14. Interoperability Requirements | Not implemented | N/A | No implementation. |
| 15. SBE Schema Appendix | Not implemented | N/A | No implementation. |

---

## SHM_RateLimiter_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Draft spec only. |
| 2. Roles | Not implemented | N/A | No agent. |
| 3. Streams and IDs | Not implemented | N/A | No agent. |
| 4. Rate Limiting Rules | Not implemented | N/A | No agent. |
| 5. Re-materialization | Not implemented | N/A | No agent. |
| 6. Metadata Forwarding | Not implemented | N/A | No agent. |
| 6.1 Progress and QoS Forwarding | Not implemented | N/A | No agent. |
| 7. Liveness and Epochs | Not implemented | N/A | No agent. |
| 8. RateLimiter Configuration | Informative | N/A | Draft spec only. |
| 9. Bridge Interplay | Informative | N/A | Draft spec only. |

---

## SHM_Service_Control_Plane_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Draft spec only. |
| 2. Key Words | Informative | N/A | Draft spec only. |
| 3. Conformance | Not implemented | N/A | No implementation. |
| 4. Streams and Roles | Not implemented | N/A | No implementation. |
| 5. EventMessage Transport | Not implemented | N/A | No implementation. |
| 6. Status Echo | Not implemented | N/A | No implementation. |
| 7. Open Questions | Informative | N/A | Draft spec only. |
| 7. Tag Naming | Informative | N/A | Draft spec only. |

---

## SHM_TraceLink_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Draft spec only. |
| 2. Key Words | Informative | N/A | Draft spec only. |
| 3. Conformance | Not implemented | N/A | No implementation. |
| 4. Terminology | Informative | N/A | Draft spec only. |
| 5. Design Constraints | Informative | N/A | Draft spec only. |
| 6. Trace Identity | Not implemented | N/A | No implementation. |
| 7. TraceLink Semantics | Not implemented | N/A | No implementation. |
| 8. FrameDescriptor Integration | Not implemented | N/A | No implementation. |
| 9. TraceLinkSet Message | Not implemented | N/A | No implementation. |
| 10. Persistence Model | Informative | N/A | Draft spec only. |
| 11. Query Examples | Informative | N/A | Draft spec only. |
| 12. Interaction with Runtime Processing | Not implemented | N/A | No implementation. |
| 12.1 Stateful Integrators | Informative | N/A | Draft spec only. |
| 13. Wire Format Changes | Not implemented | N/A | No implementation. |
| 14. Reliability and Performance | Informative | N/A | Draft spec only. |
| 14.1 Implementation Hints | Informative | N/A | Draft spec only. |
| 14.2 Reference Designs | Informative | N/A | Draft spec only. |
| 15. Summary | Informative | N/A | Draft spec only. |
| 16. SBE Schema Appendix | Not implemented | N/A | No implementation. |

---

## AeronTensorPool_Data_Product_Service_spec_draft_v_0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Draft spec only. |
| 2. Key Words | Informative | N/A | Draft spec only. |
| 3. Conformance | Not implemented | N/A | No implementation. |
| 4. Responsibilities | Not implemented | N/A | No implementation. |
| 5. Inputs | Not implemented | N/A | No implementation. |
| 6. Outputs | Not implemented | N/A | No implementation. |
| 7. Product Generation Rules | Not implemented | N/A | No implementation. |
| 8. FITS Products | Informative | N/A | Draft spec only. |
| 9. Provenance | Not implemented | N/A | No implementation. |
| 10. Open Questions | Informative | N/A | Draft spec only. |
| 11. Product Manifest | Informative | N/A | Draft spec only. |

---

## AeronTensorPool_Data_Recorder_spec_draft_v_0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Draft spec only. |
| 2. Key Words | Informative | N/A | Draft spec only. |
| 3. Conformance | Not implemented | N/A | No implementation. |
| 4. Goals and Non-Goals | Informative | N/A | Draft spec only. |
| 5. Architecture Overview | Informative | N/A | Draft spec only. |
| 6. On-Disk Data Model | Not implemented | N/A | No implementation. |
| 7. SQLite Schema | Not implemented | N/A | No implementation. |
| 8. Recording Algorithm | Not implemented | N/A | No implementation. |
| 9. Circular Recording | Not implemented | N/A | No implementation. |
| 10. Tiered Storage | Not implemented | N/A | No implementation. |
| 10.1 Replication | Not implemented | N/A | No implementation. |
| 11. TraceLink Integration | Not implemented | N/A | No implementation. |
| 12. EventMessage Capture | Not implemented | N/A | No implementation. |
| 13. Replay | Not implemented | N/A | No implementation. |
| 14. Segment Lifecycle Commands | Informative | N/A | Draft spec only. |
| 15. Derived Products | Informative | N/A | Draft spec only. |
| 16. Rationale | Informative | N/A | Draft spec only. |
| 17. Open Questions | Informative | N/A | Draft spec only. |
| 18. Design Notes Borrowed from Aeron Archive | Informative | N/A | Draft spec only. |
| 19. Features Borrowed from ArchiverService.jl | Informative | N/A | Draft spec only. |
| 20. Operational Guidance | Informative | N/A | Draft spec only. |
