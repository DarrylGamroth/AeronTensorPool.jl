# Spec Compliance Checklist

This checklist maps key MUST/SHOULD items to code/tests. The wire spec is authoritative.

## Wire Spec (v1.1) MUSTs

| Area | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| SHM URI validation | Unknown params/schemes rejected; require_hugepages enforced | Implemented | `src/shm/uri.jl`, `src/shm/validation.jl`, tests `test/test_shm_uri.jl`, `test/test_consumer_remap_fallback.jl` |
| Superblock validation | magic/layout/epoch/region_type/pool_id validated | Implemented | `src/shm/superblock.jl`, `src/agents/consumer/validation.jl`, tests `test/test_shm_superblock.jl` |
| Header invariants | seq_commit location, ndims range, payload_offset=0 | Implemented | `src/shm/slot_header.jl`, `src/agents/consumer/frames.jl`, tests `test/test_tensor_slot_header.jl` |
| Seqlock protocol | validate stable seq_commit and matching FrameDescriptor.seq | Implemented | `src/agents/consumer/frames.jl`, tests `test/test_consumer_seqlock.jl` |
| Frame identity | logical_sequence == descriptor seq | Implemented | `src/agents/consumer/frames.jl`, tests `test/test_consumer_seqlock.jl` |
| Drops on invalid | drop on header_index out of range, values_len > stride | Implemented | `src/agents/consumer/frames.jl`, tests `test/test_consumer_validation.jl` |
| Per-consumer streams | descriptor/control per-consumer rules | Implemented | `src/agents/producer/streams.jl`, tests `test/test_driver_per_consumer_streams.jl` |
| Announce freshness | ignore stale announce; join-time handling | Implemented | `src/agents/consumer/handlers.jl`, tests `test/test_consumer_remap_fallback.jl` |
| Epoch change | remap on epoch mismatch | Implemented | `src/agents/consumer/remap.jl`, tests `test/test_driver_restart_epoch.jl` |
| Payload pool parity | payload nslots matches header | Implemented | `src/agents/producer/init.jl`, tests `test/test_driver_attach_remap.jl` |

## Wire Spec SHOULDs

| Area | Recommendation | Status | Evidence |
| --- | --- | --- | --- |
| Announce cadence | 1 Hz announces and QoS | Implemented | defaults in `config/defaults.toml`, timers in `src/agents/*/work.jl` |
| Activity timestamp refresh | refresh at announce cadence | Implemented | `src/agents/producer/shm.jl` |
| drops_gap/drops_late | count for QoS | Implemented | `src/agents/consumer/metrics.jl`, `src/agents/consumer/proxy.jl` |
| max_outstanding_seq_gap | optional resync | Implemented | `src/agents/consumer/frames.jl`, tests `test/test_consumer_seq_gap.jl` |

## Bridge Spec MUSTs

| Area | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| Forwarding | descriptor/payload/metadata/progress/QoS per config | Implemented | `src/agents/bridge/*`, tests `test/test_bridge_integration.jl`, `test/test_bridge_progress_mapping.jl` |
| Rewrites | stream_id/meta_version/epoch rules | Implemented | `src/agents/bridge/proxy.jl` |

## Driver Spec MUSTs

| Area | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| Attach/detach/lease | required request/response behavior | Implemented | `src/agents/driver/*`, tests `test/test_driver_attach.jl`, `test/test_driver_lease_expiry.jl` |
| Shutdown behavior | shutdown request/notice | Implemented | `src/agents/driver/shutdown.jl`, tests `test/test_driver_shutdown*.jl` |
| Per-consumer stream allocation | assignment/decline rules | Implemented | `src/agents/driver/streams.jl`, tests `test/test_driver_per_consumer_streams.jl` |

## Discovery Spec MUSTs

| Area | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| Request/response | discovery query and result formatting | Implemented | `src/agents/discovery/*`, tests `test/test_discovery_*.jl` |

## Optional / Not Implemented

| Feature | Status |
| --- | --- |
| Meta blobs (large metadata chunking) | Not implemented |
| Rate limiter agent (spec v1.0) | Spec exists; no integration tests |
| Decimator agent | Removed; spec mentions should be revisited |

