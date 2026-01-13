# C Client Conformance Matrix

This report audits the C client implementation against the normative requirements in:
- `docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md`
- `docs/SHM_Driver_Model_Spec_v1.0.md`
- `docs/SHM_Discovery_Service_Spec_v_1.0.md`

Status legend:
- **Implemented**: requirement enforced in C client code.
- **Partial**: some aspects covered; gaps remain.
- **Not Implemented**: missing behavior in C client.
- **N/A (driver-only)**: requirement applies to the driver, not the client.

## Driver Model Spec (client-facing requirements)

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §1–§2 | Clients MUST NOT create/choose SHM paths; must treat driver URIs as authoritative | **Implemented** | `tp_attach_producer/consumer` uses driver URIs; no path selection. `c/src/tp_consumer.c`, `c/src/tp_producer.c` |
| §4 | Attach response on OK must include required fields; missing/null => protocol error | **Implemented** | `tp_validate_attach_response` enforces required fields. `c/src/tp_driver_control.c` |
| §4 | `poolNslots` must equal `headerNslots`; mismatch => drop/reattach | **Implemented** | `tp_validate_attach_response` enforces equality. |
| §4 | Required URIs must be non-empty | **Implemented** | `tp_validate_attach_response` checks `header_uri` and pool URIs. |
| §4 | `correlationId` echoed unchanged | **Implemented** | `tp_decode_attach_response` uses response correlation; `tp_wait_attach` matches. |
| §4 | Reject unknown/unsupported schema version | **Implemented** | Message header version checks in driver/control/wire/discovery handlers. |
| §4 | Optional primitives use nullValue; required fields must be non-null | **Implemented** | `tp_validate_attach_response` rejects nullValue on OK responses. |
| §5 | Clients MUST send keepalives; treat failure as fatal | **Implemented** | `tp_consumer_poll`/`tp_producer_poll` schedule keepalives and mark revoked on failure. |
| §6 | On protocol error: drop attach, stop using regions, reattach | **Implemented** | Protocol errors mark leases revoked; `tp_consumer_reattach`/`tp_producer_reattach` helpers provided. |
| §6 | Handle `ShmLeaseRevoked` (stop using SHM, reattach) | **Implemented** | Revocations set error state; reattach helpers provided. |
| §6 | Clients MUST NOT issue concurrent attach requests for same stream/role | **Implemented** | `tp_send_attach_request` rejects when a pending attach exists. |
| §6 | Detach is best-effort and idempotent; handle response | **Implemented** | Detach tracks last successful response and treats repeats as OK. |
| §7 | On lease invalidation, stop using SHM; remap on epoch bump | **Implemented** | Revocations/shutdown mark leases revoked; reattach helpers available for remap. |
| §9 | Schema version compatibility rules | **Implemented** | Message header version checks enforced for control/wire/driver/discovery. |
| §10 | Driver shutdown notice => immediate invalidation | **Implemented** | Shutdown flag and poll checks stop usage; reattach helpers provided. |
| §11 | Producer-only or consumer-only per stream | **N/A (driver-only)** | Driver enforced. |

## Wire Spec (consumer/producer client requirements)

### Attach + SHM validation

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §15.21a / §15.22 | Validate SHM URI scheme/params; reject unknown params; hugepage validation | **Implemented** | `tp_shm_validate_uri` enforces scheme/params; hugepages requested => reject (unsupported). |
| §15.22 | Validate `stride_bytes` power-of-two and page-size multiple | **Implemented** | `tp_validate_stride_bytes` in `tp_shm.c`. |
| §15.22 | Use no-follow / symlink-safe opens; revalidate inode | **Implemented** | `lstat` rejects symlinks, then `fstat`/inode/device checks enforced. |
| §7.1 | Superblock validation (magic/layout/epoch/region_type) | **Implemented** | `tp_shm_validate_superblock`. |
| §7.1 | `pool_id` rules for HEADER_RING and PAYLOAD_POOL | **Implemented** | Verified in `tp_shm_validate_superblock`. |

### Descriptor + seqlock path

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §10.2 / §15.19 | Drop if `header_index` out of range | **Implemented** | `tp_consumer_try_read_frame` checks header index bounds. |
| §10.2 / §15.19 | Drop if `epoch` mismatch with mapped SHM | **Implemented** | `tp_consumer_try_read_frame` enforces `descriptor.epoch == mapped epoch`. |
| §10.2 | Drop if `seq_commit>>1` != `FrameDescriptor.seq` | **Implemented** | `tp_consumer_try_read_frame` checks `end >> 1 == last_seq`. |
| §10.2 | Drop if `values_len_bytes > stride_bytes` | **Implemented** | `tp_consumer_try_read_frame` checks `values_len <= stride_bytes`. |
| §10.2 | Drop if `payload_offset != 0` (v1.2) | **Implemented** | `tp_consumer_try_read_frame` rejects non-zero `payload_offset`. |
| §10.2 | Parse `headerBytes` as TensorHeader SBE; validate header length and template ID | **Implemented** | `tp_consumer_try_read_frame`. |
| §10.2 | `ndims` in 1..MAX_DIMS | **Implemented** | `tp_consumer_try_read_frame` enforces bounds. |
| §10.2 | Strides validation (non-overlap, major order) | **Implemented** | `tp_validate_strides` and contiguous inference enforce major-order consistency. |
| §10.2 | Progress unit/stride validation | **Implemented** | `tp_validate_tensor_layout` checks `progress_unit`/`progress_stride_bytes`. |
| §10.2 | Drop if commit changes or odd during read | **Implemented** | Seqlock begin/end check in `tp_consumer_try_read_frame`. |

### Producer requirements

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §15.19 | Commit protocol (seq_commit write/read) | **Implemented** | `tp_producer_commit_slot` uses atomic store; `tp_producer_try_claim_slot` writes seq_commit. |
| §15.19 | `header_index = seq & (nslots-1)` | **Implemented** | `tp_producer_try_claim_slot` uses `seq % header_nslots` (modulo). |
| §15.19 | Drop if no pool fits payload | **Implemented** | `tp_producer_try_claim_slot_by_size` returns error when no pool fits. |
| §15.19 | `payload_offset = 0` | **Implemented** | Producer uses zero offset. |
| §15.19 | Zero-fill dims/strides for i >= ndims | **Implemented** | `tp_write_tensor_header` zero-fills dims/strides. |

### Announce/QoS/Progress

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §9 | ShmPoolAnnounce soft-state + freshness handling | **Implemented** | Control handler validates epoch/stream, join-time (monotonic), and freshness window; tracks last announce timestamp. |
| §10.3 | FrameProgress handling (optional) | **Implemented** | Control handler validates epoch/stream and header index; updates cached progress. |
| §12 | QosProducer/QosConsumer send | **Implemented** | Periodic send in `tp_consumer_poll` and `tp_producer_poll`; explicit send APIs still available. |
| §12 | QoS monitoring (receive) | **Implemented** | `tp_qos_monitor_*`. |

### Per-consumer streams & rate limiting

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §10.1.3 | Per-consumer stream request/validation | **Implemented** | `tp_consumer_send_hello` and ConsumerConfig handler validate channel/stream pairs. |
| §14 | RATE_LIMITED mode with per-consumer stream request | **Implemented** | Context-configured mode/maxRateHz and per-consumer channel requests in ConsumerHello. |

## Discovery Service Spec

| Spec | Requirement | Status | Evidence / Notes |
| --- | --- | --- | --- |
| §3 | Request fields with nullValue for absent | **Implemented** | `tp_discovery_send_request` uses nullValue for zero inputs. |
| §3 | `response_channel`/`response_stream_id` included | **Implemented** | Request includes response fields. |
| §4 | Response status handling | **Implemented** | `tp_handle_discovery_response` handles OK/ERROR and stores `last_status`. |
| §4 | `errorMessage` length zero means absent | **Implemented** | Stored into `last_error`; empty ok. |
| §5 | Filter and tag matching rules | **N/A (driver-only)** | Filtering is server-side; C client only consumes responses. |

## Summary

- Core attach, SHM mapping, and seqlock read/write are implemented with defensive validations (URI/stride, header_index bounds, epoch checks, payload offset/length, ndims, and progress/stride validation).
- Control-plane robustness is improved: attach/detach, keepalive scheduling, lease revocation, shutdown handling, and schema version checks are implemented, with explicit reattach helpers provided.
- QoS/metadata/discovery receive paths exist; QoS send is scheduled via poll helpers; FrameProgress and announce handling are implemented.

## Recommended next actions

1) Expand automated reattach/remap workflows for lease revocation or epoch changes if desired.
2) Add additional integration tests to cover driver shutdown/reattach scenarios.
