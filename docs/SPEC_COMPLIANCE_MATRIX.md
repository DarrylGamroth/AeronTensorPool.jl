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
| 4. Shared Memory Backends | Implemented | Needs Review | File-backed shm only (`shm:file`). |
| 4.1 Region URI Scheme | Implemented | Compliant | `src/shm/uri.jl` parses/validates shm:file URIs. |
| 4.2 Behavior Overview | Informative | N/A | Background. |
| 5. Control-Plane and Data-Plane Streams | Implemented | Needs Review | Control/descriptor/QoS/metadata pubs+subs across agents. |
| 6. SHM Region Structure | Implemented | Needs Review | Superblock + header ring + pools in `src/shm/*`. |
| 7. SBE Messages Stored in SHM | Implemented | Needs Review | `ShmRegionSuperblock`, `TensorSlotHeader256` via schema. |
| 7.1 ShmRegionSuperblock | Implemented | Needs Review | `src/shm/superblock.jl`. |
| 8. Header Ring | Implemented | Needs Review | Header ring layout in `src/shm/slots.jl`. |
| 8.1 Slot Layout | Implemented | Needs Review | 256-byte slot header. |
| 8.2 SlotHeader and TensorHeader | Implemented | Needs Review | `try_read_slot_header` validates SBE header. |
| 8.3 Commit Encoding via seq_commit | Implemented | Needs Review | Seqlock read/write in `src/shm/seqlock.jl`. |
| 9. Payload Pools | Implemented | Needs Review | Pool selection and addressing in `src/shm/pool.jl`. |
| 10. Aeron + SBE Messages (Wire Protocol) | Implemented | Needs Review | Schema + encode/decode in `src/core/messages.jl`, `src/agents/*`. |
| 10.1 Service Discovery and SHM Coordination | Implemented | Needs Review | Announce + attach flow in driver + discovery. |
| 10.2 Data Availability | Implemented | Needs Review | FrameDescriptor publish + seqlock read in consumer. |
| 10.3 Per-Data-Source Metadata | Implemented | Needs Review | DataSourceAnnounce/DataSourceMeta helpers. |
| 10.4 QoS and Health | Implemented | Needs Review | QosProducer/QosConsumer published + consumed. |
| 10.5 Supervisor / Unified Management | Partial | N/A | Supervisor exists; service commands not implemented. |
| 11. Consumer Modes | Partial | Noncompliant | RATE_LIMITED mode not implemented (only STREAM). |
| 12. Bridge Service (Optional) | Implemented | Needs Review | Bridge sender/receiver agents + tests. |
| 13. Implementation Notes | Informative | N/A | Background. |
| 14. Open Parameters | Informative | N/A | Deployment-specific. |
| 15. Additional Requirements and Guidance | Partial | Needs Review | See subsections below. |
| 15.1 Validation and Compatibility | Implemented | Needs Review | Backend + superblock validation in `src/shm/validate.jl`. |
| 15.2 Epoch Lifecycle | Implemented | Needs Review | Driver epoch bump + remap logic. |
| 15.3 Commit Protocol Edge Cases | Implemented | Needs Review | Seqlock checks + drop accounting in consumer. |
| 15.4 Overwrite and Drop Accounting | Partial | Needs Review | drops_gap/drops_late tracked; detailed causes not exhaustive. |
| 15.5 Pool Mapping Rules (v1.2) | Implemented | Needs Review | Producer/bridge pool selection. |
| 15.6 Sizing Guidance | Informative | N/A | Guidance only. |
| 15.7 Timebase | Implemented | Needs Review | Cached epoch clock used in agents. |
| 15.7a NUMA Policy | Informative | N/A | Deployment guidance. |
| 15.8 Enum and Type Registry | Not implemented | N/A | Registry not defined. |
| 15.9 Metadata Blobs | Implemented | Needs Review | Metadata helpers in client API. |
| 15.10 Security and Permissions | Partial | Needs Review | SHM permissions + allowlist partial; cross-platform rules incomplete. |
| 15.11 Stream Mapping Guidance | Informative | N/A | Guidance only. |
| 15.12 Consumer State Machine (suggested) | Partial | Needs Review | Driver/lease HSM present; consumer state machine not formalized. |
| 15.13 Test and Validation Checklist | Partial | Needs Review | Not all checklist items covered. |
| 15.14 Deployment & Liveness | Partial | Needs Review | Liveness timers present; full ops guidance unverified. |
| 15.15 Aeron Terminology Mapping | Informative | N/A | Reference. |
| 15.16 Reuse Aeron Primitives | Informative | N/A | Reference. |
| 15.16a File-Backed SHM Regions | Implemented | Needs Review | File-backed SHM supported. |
| 15.17 ControlResponse Error Codes | Implemented | Needs Review | Driver response codes in control plane. |
| 15.18 Normative Algorithms (per role) | Implemented | Needs Review | Algorithms present; needs full step-by-step validation. |
| 15.20 Compatibility Matrix | Informative | N/A | Reference. |
| 15.21 Protocol State Machines (Normative) | Partial | Needs Review | Driver lifecycle/lease HSM; consumer state machine missing. |
| 15.21a Filesystem Layout and Path Containment | Partial | Noncompliant | Canonical layout differs; consumer containment missing. |
| 15.21a.1 Overview | Informative | N/A | Guidance only. |
| 15.21a.2 Shared Memory Base Directory | Implemented | Needs Review | `shm_base_dir` + `allowed_base_dirs` config. |
| 15.21a.3 Canonical Directory Layout | Implemented | **Noncompliant** | Implementation uses `<shm_base_dir>/<namespace>/<producer_instance_id>/epoch-<epoch>/payload-<pool_id>.pool` instead of `tensorpool-${USER}/<namespace>/<stream_id>/<epoch>/<pool_id>.pool`. See `src/shm/paths.jl`. |
| 15.21a.4 Path Announcement Rule | Implemented | Needs Review | URIs announced explicitly; no consumer path derivation observed. |
| 15.21a.5 Consumer Path Containment Validation | Not implemented | Noncompliant | Consumer mapping does not perform canonical realpath containment checks; `O_NOFOLLOW` used only in driver (`src/agents/driver/streams.jl`, `src/shm/linux.jl`). |
| 15.21a.6 Permissions and Ownership | Partial | Needs Review | Configurable modes; platform parity incomplete. |
| 15.21a.7 Cleanup and Epoch Handling | Implemented | Needs Review | Epoch GC and cleanup controls in driver. |
| 15.22 SHM Backend Validation (v1.2) | Implemented | Needs Review | URI scheme + hugepage checks in `src/shm/uri.jl`, `src/shm/linux.jl`. |
| 16. Control-Plane SBE Schema (Draft) | Implemented | Needs Review | Generated schema and codecs. |

---

## SHM_Driver_Model_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Background. |
| 2. Roles | Implemented | Needs Review | Driver/producer/consumer roles in agents. |
| 2.1 SHM Driver | Implemented | Needs Review | `src/agents/driver/*`. |
| 2.2 Producer Client | Implemented | Needs Review | Producer agent + client API. |
| 2.3 Consumer Client | Implemented | Needs Review | Consumer agent + client API. |
| 3. SHM Ownership and Authority | Implemented | Needs Review | Driver owns SHM + control plane. |
| 4. Attachment Model | Implemented | Needs Review | Attach/detach protocol in driver + client. |
| 4.1 Leases | Implemented | Needs Review | Lease lifecycle + keepalive. |
| 4.2 Attach Protocol | Implemented | Needs Review | Request/response flow. |
| 4.3 Attach Request Semantics | Implemented | Needs Review | publish modes, role handling. |
| 4.4 Lease Keepalive | Implemented | Needs Review | Keepalive messages and expiry. |
| 4.4a Schema Version Compatibility | Implemented | Needs Review | Schema version checks. |
| 4.5 Control-Plane Transport | Implemented | Needs Review | Aeron control channel. |
| 4.6 Response Codes | Implemented | Needs Review | Driver response codes. |
| 4.7 Lease Lifecycle | Implemented | Needs Review | Lease state transitions. |
| 4.7a Protocol Errors | Implemented | Needs Review | Error responses and metrics. |
| 4.8 Lease Identity and Client Identity | Implemented | Needs Review | Correlation and IDs. |
| 4.9 Detach Semantics | Implemented | Needs Review | Detach handling. |
| 4.10 Control-Plane Sequences | Informative | N/A | Reference. |
| 4.11 Embedded Driver Discovery | Informative | N/A | Reference. |
| 4.12 Client State Machines | Partial | Needs Review | Driver HSM present; client state machine not formalized. |
| 4.13 Driver Termination | Implemented | Needs Review | Shutdown handling with drain. |
| 5. Exclusive Producer Rule | Implemented | Needs Review | Enforced in driver. |
| 6. Epoch Management | Implemented | Needs Review | Epoch bump and remap. |
| 7. Producer Failure and Recovery | Implemented | Needs Review | Epoch-based recovery. |
| 8. Relationship to ShmPoolAnnounce | Implemented | Needs Review | Announce cadence + mapping requirements. |
| 9. Filesystem Safety and Policy | Implemented | **Noncompliant** | Canonical layout mismatch; consumer containment checks missing (see wire spec 15.21a). |
| 10. Failure of the SHM Driver | Partial | Needs Review | Failure behavior implemented; operational handling unverified. |
| 11. Stream ID Allocation Ranges | Implemented | Needs Review | Stream ID range allocation. |
| 17. Canonical Driver Configuration | Implemented | Needs Review | Config loader and defaults. |
| Appendix A. Driver Control-Plane SBE Schema | Implemented | Needs Review | Generated schema and codecs. |

---

## SHM_Aeron_UDP_Bridge_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Background. |
| 2. Roles | Implemented | Needs Review | Sender/receiver bridge agents. |
| 2.1 Bridge Sender | Implemented | Needs Review | `src/agents/bridge/sender_*`. |
| 2.2 Bridge Receiver | Implemented | Needs Review | `src/agents/bridge/receiver_*`. |
| 2.3 Bidirectional Bridge Instances | Implemented | Needs Review | Multi-mapping support in BridgeSystemAgent. |
| 3. Transport Model | Implemented | Needs Review | UDP payload + control channel. |
| 4. Streams and IDs | Implemented | Needs Review | Config + mapping enforcement. |
| 5. Bridge Frame Chunk Message | Implemented | Needs Review | `BridgeFrameChunk` SBE + encoder. |
| 5.1 Message Fields | Implemented | Needs Review | Encoded via SBE. |
| 5.2 Chunking Rules | Implemented | Needs Review | Chunk sizing and segmentation. |
| 5.3 Loss Handling | Implemented | Needs Review | Drops on loss; assembly timeout. |
| 5.3a Frame Assembly Timeout | Implemented | Needs Review | Timeout logic in receiver. |
| 5.4 Integrity | Partial | Needs Review | No checksum validation. |
| 6. Receiver Re-materialization | Implemented | Needs Review | SHM re-materialization and descriptor publish. |
| 7. Descriptor Semantics | Implemented | Needs Review | Preserved seq/frame_id and local descriptor publish. |
| 7.1 Metadata Forwarding | Implemented | Needs Review | Optional metadata forwarding. |
| 7.2 Source Pool Announce Forwarding | Implemented | Needs Review | Announce forwarding and mapping. |
| 8. Liveness and Epochs | Implemented | Needs Review | Epoch checks and remap. |
| 9. Control and QoS | Implemented | Needs Review | Forwarding with per-mapping control streams. |
| 10. Bridge Configuration | Implemented | Needs Review | TOML config + loader. |
| 11. Bridge SBE Schema | Implemented | Needs Review | Generated schema and codecs. |

---

## SHM_Discovery_Service_Spec_v_1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1. Scope | Informative | N/A | Background. |
| 2. Roles | Implemented | Needs Review | Provider/registry/client roles. |
| 2.1 SHM Driver | Implemented | Needs Review | Provider authoritative for local driver. |
| 2.2 Discovery Provider | Implemented | Needs Review | `src/agents/discovery/*`. |
| 2.3 Client | Implemented | Needs Review | `src/discovery/discovery_client.jl` + client API. |
| 3. Authority Model | Implemented | Needs Review | Driver authoritative, registry advisory. |
| 4. Transport and Endpoint Model | Implemented | Needs Review | Request/response endpoints. |
| 4.1 Control Plane Transport | Implemented | Needs Review | Aeron request/response channels. |
| 4.2 Endpoint Configuration | Implemented | Needs Review | Config + validation. |
| 4.3 Response Channels | Implemented | Needs Review | Response channel rules enforced. |
| 5. Discovery Messages | Implemented | Needs Review | Request/response encode/decode. |
| 5.0 Encoding and Optional Fields | Implemented | Needs Review | Null handling via generated codecs. |
| 5.1 DiscoveryRequest | Implemented | Needs Review | Encoder/decoder in discovery client. |
| 5.2 DiscoveryResponse | Implemented | Needs Review | Registry/provider encode + client decode. |
| 6. Registry State and Expiry | Implemented | Needs Review | Registry table + expiry. |
| 6.1 Indexing | Implemented | Needs Review | Registry indexing by stream + source. |
| 6.2 Expiry Rules | Implemented | Needs Review | Expiry timer and purge. |
| 6.3 Conflict Resolution | Implemented | Needs Review | Entry replacement rules. |
| 6.4 Source Inputs | Implemented | Needs Review | Provider and registry inputs. |
| 7. Client Behavior | Implemented | Needs Review | Client poll + timeouts. |
| 8. Multi-Host and Fleet Discovery | Partial | Needs Review | Registry supports endpoints; fleet ops unverified. |
| 9. Relationship to Bridging | Implemented | Needs Review | Discovery visibility for bridged streams. |
| 10. Compatibility and Versioning | Implemented | Needs Review | Schema version checks. |
| 12. Security and Policy | Partial | Needs Review | Allowlist/validation partial. |
| 13. Operational Guidance | Informative | N/A | Guidance only. |
| 14. Example Flows | Informative | N/A | Reference. |
| 15. Discovery Schema | Implemented | Needs Review | Generated schema and codecs. |

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
