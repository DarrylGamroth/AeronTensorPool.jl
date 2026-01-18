# Spec Compliance Matrix

This matrix audits the Julia reference implementation against the SHM_* specs. The specs are authoritative; this matrix records **presence** and **correctness** for each major section and calls out known gaps.

Status legend:
- Implemented
- Partial
- Not implemented
- Informative (non-normative)

Correctness legend:
- Compliant
- Needs Review
- Noncompliant
- N/A

Last updated: 2026-01-17

Traceability: `docs/SPEC_TRACEABILITY_MATRIX.md` provides per-requirement code/test mapping. Spec versions are locked in `docs/SPEC_LOCK.toml`.

---

## SHM_Tensor_Pool_Wire_Spec_v1.2.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1–3 (Goals/Non-Goals/Architecture) | Informative | N/A | Guidance only. |
| 4 SHM Backends + URI Scheme | Implemented | Compliant | `src/shm/uri.jl`, `src/shm/backend.jl`. |
| 5 Streams (control/descriptor/QoS/metadata) | Implemented | Compliant | Agents + client APIs publish/subscribe to all channels. |
| 6–9 SHM Structure + Slot/Header | Implemented | Compliant | `src/shm/superblock.jl`, `src/shm/slots.jl`, `test/test_shm_superblock.jl`, `test/test_shm_uri.jl`, `test/test_tensor_slot_header.jl`, `test/test_slot_header_zero_fill.jl`. |
| 10 Wire Messages | Implemented | Compliant | Generated codecs in `src/gen/`, schemaId gating in handlers. |
| 10.1 Discovery / Coordination | Implemented | Compliant | Discovery agent + driver attach flow. |
| 10.2 Data Availability | Implemented | Compliant | Seqlock read algorithm in `src/agents/consumer/frames.jl`; FrameProgress emission exercised in `test/test_producer_progress_emit.jl`. |
| 10.3 Metadata | Implemented | Compliant | `src/client/metadata.jl`, producer metadata publishing, tests. |
| 10.4 QoS | Implemented | Compliant | QoS monitor + callbacks (`src/client/qos_monitor.jl`). |
| 10.5 Supervisor | Implemented | Compliant | `test/test_supervisor_integration.jl`, `test/test_supervisor_liveness.jl`. |
| 11 Consumer Modes | Implemented | Compliant | RATE_LIMITED enforced in consumer (`should_process`). |
| 12 Bridge Service | Implemented | Compliant | Bridging agents + tests; see Bridge spec v1.1 matrix. |
| 15 Normative Requirements | Implemented | Compliant | Announce epoch preference, activity freshness, and seq regression handling enforced in consumer mapping/frames. |
| 15.21–15.22 FS layout + validation | Implemented | Compliant | Canonical layout + containment checks in `src/shm/paths.jl` and `src/agents/consumer/mapping.jl`. |

Known gaps / open questions:
- Fresh sweep 2026-01-15: no new gaps identified.

---

## SHM_Driver_Model_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1–3 Scope/Roles/Authority | Implemented | Compliant | Driver owns SHM + control-plane. |
| 4 Attach/Detach/Keepalive | Implemented | Compliant | Driver HSM + tests; expectedLayoutVersion + desiredNodeId covered in `test/test_driver_expected_layout_version.jl` and `test/test_driver_desired_node_id.jl`. |
| 5 Exclusive Producer Rule | Implemented | Compliant | Enforced by driver. |
| 6 Epoch Management | Implemented | Compliant | Epoch bump/remap logic. |
| 7 Failure/Recovery | Implemented | Compliant | Shutdown/epoch bump + tests. |
| 9 Filesystem Safety | Implemented | Compliant | Canonical layout + path containment. |
| 10 Driver Failure Behavior | Implemented | Compliant | Shutdown notice + cleanup policies. |
| 11 Stream ID Allocation | Implemented | Compliant | Allocation ranges in driver. |
| 17 Canonical Config | Implemented | Compliant | Defaults in `src/config/defaults.jl`, TOML loader. |

---

## SHM_Aeron_UDP_Bridge_Spec_v1.1.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1–4 Scope/Roles/Transport/IDs | Implemented | Compliant | Sender/receiver agents + config validation. |
| 5 BridgeFrameChunk + Chunking | Implemented | Compliant | `src/agents/bridge/sender.jl`, `receiver.jl`, tests including `test/test_bridge_max_payload_bytes.jl`. |
| 5.3a Assembly Timeout | Implemented | Compliant | `bridge.assembly_timeout_ms` enforced. |
| 5.4 Integrity | Implemented | Compliant | Optional CRC32C policy enabled via `bridge.integrity_crc32c`. |
| 6 Re-materialization | Implemented | Compliant | Receiver writes local SHM + descriptor publish. |
| 7 Descriptor semantics | Implemented | Compliant | TraceId propagated and seq preserved. |
| 7.1 Metadata/TraceLink forwarding | Implemented | Compliant | Forwarders in `src/agents/bridge/proxy.jl`. |
| 7.2 Pool announce + control | Implemented | Compliant | Control-channel forwarding for announce/QoS/progress. |

---

## SHM_Discovery_Service_Spec_v_1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1–4 Scope/Roles/Transport | Implemented | Compliant | Discovery agent + client. |
| 5 Messages | Implemented | Compliant | SBE decode/encode in `src/agents/discovery/*`. |
| 6 Registry State/Expiry | Implemented | Compliant | Registry table + expiry timers. |
| 7 Client Behavior | Implemented | Compliant | Client poll + attach integration. |
| 9 Bridge Relationship | Implemented | Compliant | Discovery + bridge tests. |

---

## SHM_RateLimiter_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 2–5 Roles/Rules/Re-materialization | Implemented | Compliant | `src/agents/ratelimiter/*`. |
| 6 Metadata Forwarding | Implemented | Compliant | `forward_data_source_*` helpers. |
| 6.1 Progress/QoS Forwarding | Implemented | Compliant | Config-gated forwarding in `forward.jl`. |
| 7 Liveness/Epochs | Implemented | Compliant | Remap/reset on epoch change. |

---

## SHM_Join_Barrier_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 5 Requirements/Constraints | Implemented | Compliant | Constraints enforced in merge map validation + readiness checks. |
| 6 MergeMap | Implemented | Compliant | Requests/announces + validation. |
| 7 SequenceJoinBarrier | Implemented | Compliant | Output monotonicity and input checks enforced in readiness. |
| 8 TimestampJoinBarrier | Implemented | Compliant | Monotonic input/output and clock-domain validation enforced. |
| 9 LatestValueJoinBarrier | Implemented | Compliant | Best-effort join implemented. |
| 10 Wire Format | Implemented | Compliant | Merge schema (`src/gen/ShmTensorpoolMerge.jl`). |

---

## SHM_TraceLink_Spec_v1.0.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| 1–4 Scope/Ids/Encoding | Implemented | Compliant | TraceLink publisher + helpers in `src/client/tracelink.jl`. |
| 5 TraceLinkSet | Implemented | Compliant | Parent validation + encode/decode tests. |
| 6 Bridge forwarding | Implemented | Compliant | Forwarding in `src/agents/bridge/proxy.jl`. |

---

## CLIENT_RUNTIME_INTERFACE.md

| Section | Status | Correctness | Notes / Evidence |
| --- | --- | --- | --- |
| AbstractTensorPoolClient contract | Implemented | Compliant | `src/core/client_interface.jl`, `test/test_client_interface_contract.jl`. |
| TensorPoolClient do_work | Implemented | Compliant | `src/client/context.jl`, `test/test_client_api.jl`. |
| TensorPoolRuntime control_runtime | Implemented | Compliant | `src/client/runtime.jl`, `test/test_client_interface_contract.jl`. |
