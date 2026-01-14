# Spec Traceability Matrix

This matrix maps every normative requirement (MUST/SHOULD/MAY/REQUIRED/RECOMMENDED) to code and tests. Specs are authoritative.

Status legend:
- Mapped: code/tests linked (verification tracked in SPEC_COMPLIANCE_MATRIX.md).
- Gap: missing or noncompliant.

## docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md

Default code refs: src/shm, src/agents/producer, src/agents/consumer, src/client, src/gen/TensorPool.jl
Default tests: test/test_shm_*, test/test_consumer_*, test/test_producer_*, test/test_metadata_*, test/test_qos_*

| Requirement ID | Requirement | Code refs | Test refs | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:12 | **Key Words** The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHOULD”, “SHOULD NOT”, and “MAY” are to be interpreted as described in RFC 2119. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:14 | **Document Conventions** Normative sections: 6–11, 15.1–15.22, 16. Informative sections: 1–5, 12–14. "NOTE:"/"Rationale:" text is informative. Uppercase MUST/SHOULD/MAY keywords appear only in normative sections and carry RFC 2119 force; any lowercase "must/should/may" in informative text is non-normative. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:96 | Per-consumer descriptor streams (optional): producers MAY publish `FrameDescriptor` on per-consumer channels/stream IDs when requested. If used, the producer MUST return the assigned descriptor channel/stream in `ConsumerConfig`, and the consumer MUST subscribe to that stream instead of the shared descriptor stream. Producers MUST stop publishing and close per-consumer descriptor publications when the consumer disconnects or times out. Liveness for per-consumer streams is satisfied by either `ConsumerHello` or `QosConsumer`; producers MUST treat a consumer as stale only when neither has been received for 3–5× the configured hello/qos interval. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:97 | When per-consumer descriptor streams are used, producers MAY apply `ConsumerHello.max_rate_hz` as a per-consumer descriptor rate cap; if `max_rate_hz` is 0, descriptors are unthrottled. `max_rate_hz` MUST be ignored when only the shared descriptor stream is used. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:98 | Per-consumer control streams (optional): producers MAY publish `FrameProgress` on per-consumer control channels/stream IDs when requested. If used, the producer MUST return the assigned control channel/stream in `ConsumerConfig`, and the consumer MUST subscribe to that control stream for `FrameProgress`. Consumers MUST continue to subscribe to the shared control stream for all other control-plane messages. Producers MUST NOT publish other control-plane messages on per-consumer control streams. Producers MUST validate requested per-consumer channels/stream IDs; if unsupported or invalid, they MUST decline by returning empty channel and null/zero stream IDs in `ConsumerConfig`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:116 | Define `superblock_size = 64` bytes (fixed); all offsets/formulas refer to this constant in v1.2. This is normative: implementations MUST treat `superblock_size` as exactly 64 bytes (do not derive from SBE blockLength metadata). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:143 | - Consumers MUST validate against announced parameters. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:145 | - Encoding is little-endian. Superblock layout is SBE-defined (see schema appendix) so existing SBE parsers can `wrap!` directly over the mapped memory. Current magic MUST be ASCII `TPOLSHM1` (`0x544F504C53484D31` as u64, little-endian); treat mismatches as invalid. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:149 | - `pool_id` meaning: for `region_type=HEADER_RING`, `pool_id` MUST be 0. For `region_type=PAYLOAD_POOL`, `pool_id` MUST match the `pool_id` advertised in `ShmPoolAnnounce`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:168 | SBE definition: `SlotHeader` and `TensorHeader` messages in the schema appendix (v1.2 `MAX_DIMS=8`). The schema includes a `maxDims` constant field for codegen alignment; it is not encoded on the wire and MUST be treated as a compile-time constant. Changing `MAX_DIMS` requires a new `layout_version` and schema rebuild. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:171 | - The header slot is a raw SBE message body (no SBE message header). `seq_commit` MUST be at byte offset 0 of the slot. SBE wrap functions MUST be used without applying a message header. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:181 | - `pad : bytes[26]` (reserved; producers MAY zero-fill; consumers MUST ignore) | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:182 | - `headerBytes : varData` (length MUST match the embedded TensorHeader SBE message header + blockLength; v1.2 length is 192 bytes) | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:190 | - `progress_stride_bytes : u32` (bytes between adjacent rows/columns when `progress_unit!=NONE`; MUST be > 0 and equal to the true row/column stride) | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:198 | Canonical identity: `logical_sequence = seq_commit >> 1`, `FrameDescriptor.seq`, and `FrameProgress.seq` MUST be equal for the same frame; consumers MUST DROP if any differ. No separate `frame_id` field exists in the header. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:203 | - `seq_commit` MUST reside entirely within a single cache line and be written with a single aligned store; assume 64-byte cache lines (common); if different, still place `seq_commit` in the first cache line and use an 8-byte aligned atomic store. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:204 | - `ndims` MUST be in the range `1..MAX_DIMS`; consumers MUST drop frames with `ndims=0` or `ndims > MAX_DIMS`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:205 | - For v1.2, `payload_offset` MUST be 0; consumers MUST drop frames with non-zero `payload_offset`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:206 | - Producers MUST zero-fill `dims[i]` and `strides[i]` for all `i >= ndims`; consumers MUST ignore indices `i >= ndims`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:207 | - Strides: `0` means inferred contiguous; negative strides are **not supported in v1.2**; strides MUST describe a non-overlapping layout consistent with `major_order` (row-major implies increasing stride as dimension index decreases); reject headers whose strides would overlap or contradict `major_order`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:220 | - Progress: if `progress_unit != NONE`, `progress_stride_bytes` MUST be non-zero and equal to the true row/column stride implied by `strides` (or inferred contiguous). Consumers MUST drop frames where `progress_unit != NONE` and `progress_stride_bytes` is zero or inconsistent with the declared layout. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:222 | - Padding is reserved/opaque; producers MAY leave it zeroed or use it for implementation-specific data; consumers MUST ignore it and MUST NOT store process-specific pointers/addresses there. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:223 | - Frame identity: `logical_sequence` (derived from `seq_commit`), `FrameDescriptor.seq`, and `FrameProgress.seq` MUST match. Consumers SHOULD drop a frame if `seq_commit` and `FrameDescriptor.seq` disagree (stale slot reuse). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:224 | - Empty payloads: `values_len_bytes = 0` is valid. Producers MUST still commit the slot; consumers MUST NOT read payload bytes when `values_len_bytes = 0` (payload metadata may be ignored). `payload_slot` MUST still equal `header_index` (derived from `seq`) in v1.2. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:250 | 5. Parse `headerBytes` as an embedded SBE message (expect `TensorHeader` in v1.2); drop if header length or templateId is invalid (length MUST equal the embedded message header + blockLength). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:251 | The embedded message header MUST have the expected `schemaId` and `version`; otherwise drop. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:257 | - Producer MUST ensure payload bytes are visible to CPUs before writing the COMMITTED `seq_commit` (and before emitting a `FrameProgress` COMPLETE state). On non-coherent DMA paths, flush/invalidate as required by the platform/driver. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:258 | - Consumers MUST treat payload as valid only after the seqlock check on `seq_commit` succeeds. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:269 | - Pools MAY be size-classed (e.g. 1 MiB, 16 MiB). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:271 | - If no pool fits (`values_len_bytes` larger than all `stride_bytes`), the producer MUST drop the frame (and MAY log/emit QoS) rather than blocking; future v2 may add dynamic pooling. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:290 | - Producers MUST encode “absent” optional primitives using the nullValue; consumers MUST interpret those null values as “not provided”. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:291 | - Variable-length `data` fields are optional by encoding an empty value (length = 0). Producers MUST use length 0 to indicate absence; consumers MUST treat length 0 as “not provided”. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:292 | - For sbe-tool compatibility, variable-length `data` fields MUST NOT be marked `presence="optional"` in the schema; absence is represented by length 0 only. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:319 | - Consumers MUST treat `ShmPoolAnnounce` as soft-state and ignore stale announcements. At minimum, consumers MUST prefer the highest observed `epoch` per `stream_id` and MUST ignore any announce whose `announce_timestamp_ns` is older than a freshness window (RECOMMENDED: 3× the announce period) relative to local receipt time. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:320 | - Consumers MUST ignore announcements whose `announce_timestamp_ns` precedes the consumer's join time (to avoid Aeron log replay) **only when `announce_clock_domain=MONOTONIC`**. Define `join_time_ns` as the local monotonic time when the subscription image becomes available; compare directly only for MONOTONIC. For REALTIME_SYNCED, consumers MUST NOT apply the join-time drop rule and MUST rely on the freshness window relative to local receipt time instead. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:348 | - Optionally request a per-consumer descriptor stream only when `descriptor_channel` is non-empty and `descriptor_stream_id` is non-zero. If either is missing, the request MUST be treated as absent; consumers MUST NOT send a non-empty channel with `descriptor_stream_id=0`, and producers MUST reject such requests. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:349 | - Optionally request a per-consumer control stream only when `control_channel` is non-empty and `control_stream_id` is non-zero. If either is missing, the request MUST be treated as absent; consumers MUST NOT send a non-empty channel with `control_stream_id=0`, and producers MUST reject such requests. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:362 | - URI SHOULD follow Aeron channel syntax when bridged over Aeron (e.g., `aeron:udp?...`) or a documented scheme such as `bridge://<id>` when using a custom bridge; undefined schemes MUST be treated as unsupported. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:373 | - Empty `descriptor_channel`/`control_channel` strings (length=0) MUST be treated as “not requested/assigned”; length=0 is the only valid absent encoding. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:374 | - If only one of channel/stream_id is provided, the request MUST be rejected (non-empty channel with stream_id=0, or non-zero stream_id with empty channel). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:375 | - If a producer declines a per-consumer stream request, it MUST return empty channel and stream ID = 0 in `ConsumerConfig`, and the consumer MUST remain on the shared stream. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:376 | - Per-consumer descriptor/control publications MUST be closed when the consumer is stale (no `QosConsumer` or `ConsumerHello` for 3–5× the configured hello/qos interval) or explicitly disconnected. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:387 | - `seq : u64` (monotonic; MUST equal `logical_sequence = seq_commit >> 1` in the header) | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:395 | - Producers MUST publish `FrameDescriptor` only after the slot’s `seq_commit` is set to COMMITTED and payload visibility is ensured. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:396 | - Consumers MUST ignore descriptors whose `epoch` does not match mapped SHM regions. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:398 | - Consumers MUST compute `header_index = seq & (header_nslots - 1)` using the mapped header ring size. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:399 | - Consumer MUST drop if the header slot’s committed `logical_sequence` (derived from `seq_commit >> 1`) does not equal `FrameDescriptor.seq` for that `header_index` (stale reuse guard). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:400 | - Consumers MUST drop if `payload_slot` decoded from the header is out of range for the mapped payload pool. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:401 | - Consumers MUST drop frames where `values_len_bytes > stride_bytes`. (Future versions that permit non-zero `payload_offset` MUST additionally enforce `payload_offset + values_len_bytes <= stride_bytes`.) | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:403 | TraceLink is enabled for that frame; producers SHOULD emit TraceLinkSet | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:404 | records per `docs/SHM_TraceLink_Spec_v1.0.md`. Consumers MAY ignore `trace_id`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:413 | - `seq : u64` (MUST equal `FrameDescriptor.seq` and the header logical sequence) | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:422 | - Consumers that opt in and need slot access MUST compute `header_index = seq & (header_nslots - 1)` using the mapped header ring size. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:423 | - Consumers that opt in must read only the prefix `[0:payload_bytes_filled)` and may reread `payload_bytes_filled` to confirm. Consumers MUST validate `progress_unit`/`progress_stride_bytes` before treating any prefix as layout-safe; if `progress_unit != NONE` and `progress_stride_bytes` is zero or inconsistent with the declared strides, the frame MUST be dropped. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:424 | - `payload_bytes_filled` MUST be `<= values_len_bytes`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:425 | - `payload_bytes_filled` MUST be monotonic non-decreasing within a frame; consumers MUST drop if it regresses. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:426 | - `FrameProgress.state=COMPLETE` does **not** guarantee payload visibility; consumers MUST still validate `seq_commit` before treating data as committed. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:427 | - FrameDescriptor remains the canonical “frame available” signal; consumers MUST NOT treat `FrameProgress` (including COMPLETE) as a substitute, and producers MAY omit `FrameProgress` entirely. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:473 | - Use `meta_version` bumps to add/remove `attributes`. Consumers MAY ignore unknown `key` values. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:483 | Rules (experimental): offsets MUST be monotonically increasing, non-overlapping, and cover `[0, total_len)`; consumers discard on gap/overlap or checksum mismatch; retransmission/repair is out of scope in v1.2. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:527 | - **RATE_LIMITED**: consumer requests reduced-rate delivery (e.g., per-consumer descriptor/control stream or downstream rate limiter). Producer/supervisor MAY decline; if declined, consumer remains on the shared stream and MAY drop locally. `max_rate_hz` in `ConsumerHello` is authoritative when `mode=RATE_LIMITED`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:558 | - Aeron channel/stream ID mapping conventions (examples in 15.11 are non-normative; deployments SHOULD set explicit defaults) | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:569 | - Consumers MUST validate that `layout_version`, `nslots`, `slot_bytes`, `stride_bytes`, `region_type`, and `pool_id` in `ShmRegionSuperblock` match the most recent `ShmPoolAnnounce`; mismatches MUST trigger a remap or fallback. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:570 | - Consumers MUST validate `magic` and `epoch` on every `ShmPoolAnnounce`; `pid` is informational and cannot alone detect restarts or multi-producer contention. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:571 | - Consumers MUST validate `activity_timestamp_ns` freshness: announcements older than the freshness window (RECOMMENDED: 3× announce period) MUST be ignored. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:572 | - Host endianness: implementation is little-endian only; big-endian hosts MUST reject or byte-swap consistently (out of scope in v1.2). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:576 | - On `epoch` change, producer SHOULD reset `seq` to 0; consumers MUST drop stale frames, unmap, and remap regions. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:580 | - If `seq_commit` decreases for the same slot (e.g., lower `logical_sequence`), consumers MUST treat it as stale and skip. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:585 | - Producers MAY overwrite any slot following `header_index = seq & (nslots - 1)` with no waiting. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:586 | - Consumers SHOULD treat gaps in `seq` as `drops_gap` and `seq_commit` instability as `drops_late`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:587 | - Documented policy: no producer backpressure in v1.2; supervisor MAY act on QoS to throttle externally. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:588 | - Optional policy: implementations MAY configure `max_outstanding_seq_gap` per consumer; if exceeded, consumer SHOULD resync (e.g., drop to latest) and report in QoS. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:589 | - Recommended `max_outstanding_seq_gap` default: 256 frames; deployments MAY tune based on buffer depth and latency tolerance. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:592 | - All payload pools MUST use the same `nslots` as the header ring; differing `nslots` are invalid in v1.2. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:600 | - `timestamp_ns` SHOULD be monotonic (CLOCK_MONOTONIC) for latency calculations. If cross-host alignment is required and PTP is available, `CLOCK_REALTIME` is acceptable—document the source clock and drift budget. When possible, include both a monotonic timestamp (for latency) and a realtime/epoch timestamp (for cross-host alignment). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:608 | - Define and version registries for `dtype`, `major_order`, and set `MAX_DIMS` (v1.2 fixed at 8). Changing `MAX_DIMS` requires a new `layout_version` and schema rebuild. Unknown enum values MUST cause rejection of the frame (or fallback) rather than silent misinterpretation. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:610 | - Normative numeric values (v1.2): `Dtype.UNKNOWN=0, UINT8=1, INT8=2, UINT16=3, INT16=4, UINT32=5, INT32=6, UINT64=7, INT64=8, FLOAT32=9, FLOAT64=10, BOOLEAN=11, BYTES=13, BIT=14`; `MajorOrder.UNKNOWN=0, ROW=1, COLUMN=2`. These values MUST NOT change within v1.x. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:613 | - Define `CHUNK_MAX`; checksum is OPTIONAL given Aeron reliability. Offsets MUST be monotonically increasing and non-overlapping. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:618 | - SHM files SHOULD be created with restrictive modes (e.g., 660) and owned by the producing service user/group; set appropriate `umask`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:619 | - On systems with MAC (SELinux/AppArmor), label/allow rules SHOULD be set to limit writers to trusted services. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:622 | - Recommend fixed stream ID ranges per channel: descriptor, control, QoS, metadata. Template IDs alone MAY be used for multiplexing, but separate streams improve observability. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:629 | - Cadence guidance (SHOULD, configurable per deployment): `ShmPoolAnnounce` 1 Hz; `DataSourceAnnounce` 1 Hz; `QosProducer`/`QosConsumer` 1 Hz; `activity_timestamp` refresh at same cadence. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:646 | - Single-writer rule: producer is sole writer of header/pool regions; if `pid` changes or concurrent writers are detected, consumers MUST unmap and wait for a new `epoch`. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:682 | - `InternalError`: transient or unexpected server failure; requester MAY retry after backoff. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:700 | 5. Parse `headerBytes` as an embedded SBE message (expect `TensorHeader` in v1.2); drop if header length or templateId is invalid (length MUST equal the embedded message header + blockLength). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:742 | 2. **Commit stability**: MUST observe a stable `seq_commit` with LSB=1 before accepting; if WRITING/unstable, DROP. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:743 | 3. **Embedded header validation**: `headerBytes` MUST decode to a supported embedded header (v1.2: `TensorHeader` with the expected schemaId/version/templateId and length per §8.3); otherwise DROP. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:744 | 4. **Frame identity**: `(seq_commit >> 1)` MUST equal `FrameDescriptor.seq` (same rule as §10.2.1); if not, DROP. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:745 | 5. **No waiting**: MUST NOT block/spin waiting for commit; on any failure, DROP and continue. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:764 | - A consumer MUST treat any epoch mismatch as a hard boundary. All in-flight frames MUST be DROPPED. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:765 | - After detecting an epoch mismatch, the consumer MUST NOT accept subsequent frames until the regions have been remapped for the new epoch. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:766 | - While in M0: UNMAPPED, frames referencing unmapped regions MUST be DROPPED. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:783 | Consumers MUST NOT rely on directory scanning or filename derivation for | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:788 | Implementations SHOULD expose a configuration parameter: | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:798 | Implementations MAY support multiple base directories (e.g., | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:807 | When creating shared-memory regions under `shm_base_dir`, producers MUST | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:819 | A per-user namespace directory (e.g., `tensorpool-alice`). `${USER}` MUST be | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:821 | identifier. Implementations MUST sanitize this value to avoid path traversal. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:825 | MUST be configured per deployment. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:841 | Filenames and extensions are not protocol-significant but MUST remain stable | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:848 | - Producers MUST announce explicit absolute paths for all shared-memory regions. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:849 | - Consumers MUST NOT infer, derive, or synthesize filesystem paths. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:850 | - Consumers MUST NOT scan directories to discover shared-memory regions. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:857 | MUST: | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:870 | and sockets MUST be rejected. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:871 | 6. To avoid TOCTOU/symlink swaps, consumers MUST open the file with | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:872 | no-follow/symlink-safe flags where available and MUST re-validate the opened | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:875 | handle identity check (e.g., inode+device or file ID), the consumer MUST | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:878 | If any of these checks fail, the consumer MUST reject the region and MUST NOT | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:885 | Implementations SHOULD ensure that directory and file permissions prevent | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:907 | Implementations MAY remove epoch directories eagerly on clean shutdown or lazily | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:908 | during startup or supervision. A Supervisor or Driver SHOULD periodically scan | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:924 | - `path` (required): absolute filesystem path to the backing file (POSIX or Windows). Examples: `/dev/shm/<name>` (tmpfs), `/dev/hugepages/<name>` (hugetlbfs), or `C:\\aeron\\<name>` on Windows. Absolute POSIX paths use a leading `/`. Non-path platform identifiers (e.g., Windows named shared memory) are out of scope for v1.2; deployments that support them MUST define equivalent containment/allowlist rules. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:925 | - `require_hugepages` (optional, default false): if true, the region MUST be backed by hugepages; mappings that do not satisfy this requirement MUST be rejected. On platforms without a reliable hugepage verification mechanism (e.g., Windows), `require_hugepages=true` is unsupported and MUST be rejected. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:926 | - v1.2 supports only `shm:file`; other schemes or additional parameters are unsupported and MUST be rejected. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:936 | Only `path` and `require_hugepages` are defined; unknown parameters MUST be rejected. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:940 | - Consumers MUST reject any `region_uri` with an unknown scheme. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:941 | - For `shm:file`, if `require_hugepages=true`, consumers MUST verify that the mapped region is hugepage-backed. On platforms without a reliable verification mechanism (e.g., Windows), `require_hugepages=true` is unsupported and MUST cause the region to be rejected (no silent downgrade). | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:942 | - `stride_bytes` is explicit and MUST NOT be inferred from page size. It MUST be a power-of-two multiple of 64 bytes. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:943 | - Page size or hugepage alignment MAY be chosen by deployments for performance | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:945 | - For `shm:file`, parameters are separated by `\|`; unknown parameters MUST be rejected. | Default | Default | Mapped |  |
| docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:946 | - Regions that violate these requirements MUST be rejected. On rejection, consumers MAY fall back to a configured `payload_fallback_uri`; otherwise they MUST fail the data source with a clear diagnostic. Rejected regions MUST NOT be partially consumed. | Default | Default | Mapped |  |


## docs/SHM_Driver_Model_Spec_v1.0.md

Default code refs: src/agents/driver, src/client/driver_client.jl, src/config
Default tests: test/test_driver_*, test/test_consumer_attach_response_validation.jl

| Requirement ID | Requirement | Code refs | Test refs | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| docs/SHM_Driver_Model_Spec_v1.0.md:10 | The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHOULD”, “SHOULD NOT”, and “MAY” are to be interpreted as described in RFC 2119. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:40 | The driver MAY be embedded within an application process or run as an external service. A deployment MUST ensure that only one authoritative driver instance manages a given `stream_id` at a time. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:44 | A Producer Client attaches to a stream via the driver, writes headers and payloads into driver-owned SHM regions, publishes `FrameDescriptor` messages as defined in the Wire Specification, and MUST NOT create, truncate, or unlink SHM backing files. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:48 | A Consumer Client attaches to a stream via the driver, maps SHM regions using URIs provided by the driver, reads SHM and consumes descriptors per the Wire Specification, and MUST NOT create, truncate, or unlink SHM backing files. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:57 | 2. Producer and consumer clients MUST NOT create or select SHM filesystem paths. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:58 | 3. Producer and consumer clients MUST treat all SHM region URIs received from the driver as authoritative. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:59 | 4. All SHM regions MUST conform to the Wire Specification. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:61 | The driver MAY update `activity_timestamp_ns` in superblocks directly or delegate that responsibility to the attached producer, but it remains responsible for ensuring liveness semantics in the Wire Specification are met. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:69 | A lease represents authorization for a client to access a specific stream in a specific role. Each lease is associated with exactly one `stream_id`, exactly one role (PRODUCER or CONSUMER), is identified by an opaque `lease_id`, and MAY have a bounded lifetime enforced by the driver. The driver MUST track active leases for liveness and cleanup. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:73 | Clients attach to a stream by issuing a ShmAttachRequest to the driver and receiving a correlated ShmAttachResponse. The attach protocol MUST provide, on success, the current `epoch`, the current `layout_version`, URIs for all SHM regions required by the Wire Specification, and a valid `lease_id`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:74 | If the deployment uses dynamic TraceLink node IDs, the driver MAY assign a | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:77 | Clients MAY request a specific node ID via `desiredNodeId`. If the requested ID | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:78 | is unavailable, the driver MUST reject the attach with `code=REJECTED` (or | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:79 | `INVALID_PARAMS`) and MUST NOT set `nodeId`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:81 | The driver MAY create new SHM regions on demand when `publishMode=EXISTING_OR_CREATE`; otherwise, it MUST return an error if the stream does not already exist or is not provisioned for the requested role. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:83 | Clients SHOULD apply an attach timeout; if no response is received within the configured window, clients SHOULD retry with backoff. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:85 | `correlationId` is client-supplied; the driver MUST echo it unchanged in `ShmAttachResponse`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:87 | For `code=OK`, the response MUST include: `leaseId`, `streamId`, `epoch`, `layoutVersion`, `headerNslots`, `headerSlotBytes`, `headerRegionUri`, and a complete `payloadPools` group with each pool's `regionUri`, `poolId`, `poolNslots`, and `strideBytes`. `headerSlotBytes` is fixed at `256` by the Wire Specification. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:88 | If a node ID is assigned, the response MUST also include `nodeId`. If present, | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:89 | `nodeId` MUST be non-null and stable for the lease lifetime. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:91 | For `code != OK`, the response MUST include `correlationId` and `code`, and SHOULD include `errorMessage` with a diagnostic string. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:93 | Optional primitive fields in the SBE schema MUST use explicit `nullValue` sentinels. For `code=OK`, all required fields MUST be non-null; for `code != OK`, optional response fields SHOULD be set to their `nullValue`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:95 | For optional enum fields, the `nullValue` MUST be used when the field is absent and MUST NOT match any defined enum constant. For required enum fields that are conceptually optional, this specification uses an explicit `UNSPECIFIED` value (e.g., `HugepagesPolicy`). | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:97 | Variable-length `data` fields (e.g., `errorMessage`, `headerRegionUri`) MUST NOT be marked `presence="optional"` in the schema for sbe-tool compatibility. Absence is represented by a zero-length value. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:99 | If `code=OK` and any required field is set to its `nullValue`, the client MUST treat the response as a protocol error, DROP the attach, and reattach. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:101 | For `code=OK`, `headerRegionUri` and every `payloadPools.regionUri` MUST be present, non-empty, and not blank. If any required URI is absent or empty (length=0), the client MUST treat the response as a protocol error, DROP the attach, and reattach. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:103 | For `code=OK`, clients MUST reject the response if `headerSlotBytes != 256` or if the `payloadPools` group is empty. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:105 | For `code=OK`, the driver MUST set `poolNslots` equal to `headerNslots` for each payload pool. Clients MUST treat any mismatch as a protocol error, DROP the attach, and reattach. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:107 | If `leaseExpiryTimestampNs` is present, clients MUST treat it as a hard deadline; if absent, clients MUST still send keepalives at the configured interval and treat lease validity as unknown beyond the absence of `ShmLeaseRevoked`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:109 | All URIs returned by the driver MUST satisfy the Wire Specification URI validation rules; clients MUST validate and reject URIs that fail those rules. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:111 | If `errorMessage` is present (length > 0), it MUST be limited to 1024 bytes; drivers SHOULD truncate longer messages. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:115 | - `expectedLayoutVersion`: If present and nonzero, the driver MUST reject the request with `code=REJECTED` if the active layout version for the stream does not match. If absent or zero, the driver uses its configured layout version and returns it in the response. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:116 | - `publishMode`: `REQUIRE_EXISTING` means the driver MUST reject if the stream is not already provisioned. `EXISTING_OR_CREATE` allows the driver to create or initialize SHM regions on demand. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:117 | - `requireHugepages`: A `HugepagesPolicy` value. If `HUGEPAGES`, the driver MUST reject the request with `code=REJECTED` if it cannot provide hugepage-backed regions that satisfy Wire Specification validation rules. If `STANDARD`, the driver MUST reject the request with `code=REJECTED` if it cannot provide standard page-backed regions. If `UNSPECIFIED`, the driver applies its configured default policy. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:118 | - Streams with zero payload pools are invalid in v1.0; the driver MUST reject attach requests for such streams with `code=INVALID_PARAMS`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:122 | The driver SHOULD require periodic `ShmLeaseKeepalive` messages for active leases. If `leaseExpiryTimestampNs` is provided in the attach response, the client MUST ensure keepalives arrive before that timestamp. On each valid keepalive, the driver MUST extend the lease expiry (duration is implementation-defined and MAY be documented out-of-band). If a lease expires, the driver MUST invalidate it and enforce the epoch rules in §6 and §7. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:124 | For interoperability, a deployment SHOULD configure a default keepalive interval and expiry grace. A recommended baseline is: | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:129 | Drivers MAY use different values but MUST make them discoverable out-of-band (configuration or operational documentation). Clients SHOULD treat a keepalive send failure as a fatal condition and reattach. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:137 | Clients MUST reject messages with a schema version higher than they support. Drivers SHOULD respond using the highest schema version supported by both client and driver; if no compatible version exists, the driver MUST return `code=UNSUPPORTED`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:139 | Clients MUST reject driver control-plane messages whose `schemaId` or `templateId` does not match the expected driver control schema. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:143 | `ShmAttachRequest`, `ShmAttachResponse`, `ShmDetachRequest`, `ShmDetachResponse`, `ShmLeaseKeepalive`, `ShmLeaseRevoked`, `ShmDriverShutdown`, and (if implemented) `ShmDriverShutdownRequest` MUST be carried on the control-plane Aeron stream defined by the Wire Specification unless an alternative is explicitly configured and documented for the deployment. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:147 | The driver MUST use response codes consistently: | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:165 | Once a lease reaches `DETACHED`, `EXPIRED`, or `REVOKED`, the client MUST stop using all SHM regions from that lease and MUST reattach to continue. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:169 | On any detected protocol error (e.g., required fields missing or set to null on `code=OK`, malformed responses, unknown enums where disallowed), clients MUST fail closed: drop the attach, stop using any mapped regions derived from the response, and reattach. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:171 | When a producer lease transitions to `EXPIRED` or `REVOKED`, the driver MUST increment `epoch` and MUST emit a fresh `ShmPoolAnnounce` promptly so consumers can fail closed and remap. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:175 | - `leaseId` MUST be unique per driver instance for the lifetime of the process and MUST NOT be reused after expiry or detach. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:176 | - `leaseId` scope is local to a single driver instance and MUST NOT be assumed stable across driver restarts. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:177 | - `clientId` MUST be unique per client process. If the driver observes two active leases with the same `clientId`, it MUST reject the newer attach with `code=REJECTED`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:178 | - Clients MUST NOT issue concurrent attach requests for the same `streamId` and role. Drivers MAY reject subsequent requests with `code=REJECTED` or treat them as retries (ignoring duplicates by `correlationId`). | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:182 | `ShmDetachRequest` is best-effort and idempotent. If the lease is active and matches the request's `leaseId`, `streamId`, `clientId`, and `role`, the driver MUST invalidate the lease and return `code=OK`. If the lease is unknown or already invalidated, the driver SHOULD return `code=REJECTED` (or `OK` if it treats the request as idempotent success). Detaching a producer lease MUST trigger an epoch increment per §6. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:184 | The driver MUST echo `correlationId` unchanged in `ShmDetachResponse`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:186 | For any lease invalidation event (`DETACHED`, `EXPIRED`, or `REVOKED`), the driver MUST publish a `ShmLeaseRevoked` notice on the control-plane stream. This includes consumer leases and producer leases (in addition to any `ShmPoolAnnounce` required for epoch changes). | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:188 | Clients MUST handle `ShmLeaseRevoked` as follows: | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:189 | - If the revoked lease matches the client's active lease, the client MUST immediately stop using mapped regions, DROP any in-flight frames, and reattach. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:190 | - If the revoked lease is a producer lease for a stream the client consumes, the client MUST wait for the epoch-bumped `ShmPoolAnnounce` before remapping and resuming. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:191 | - If the revoked lease does not match the client's lease and is not the current producer lease for a stream the client consumes, the client MAY ignore it after verifying the `leaseId`, `streamId`, and `role` do not apply. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:192 | Clients SHOULD handle revocations on a per-lease basis; revocation of one lease MUST NOT force teardown of unrelated leases. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:194 | `ShmLeaseRevoked.reason` is required; clients MUST reject messages with unknown reason values. Clients MUST also reject `ShmLeaseRevoked` messages with unknown `role` values. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:196 | The driver SHOULD emit `ShmLeaseRevoked` before the corresponding `ShmPoolAnnounce` to allow consumers to correlate the epoch change with the revocation event. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:198 | Consumers SHOULD apply a timeout (recommend 3× the announce period) when waiting for an epoch-bumped `ShmPoolAnnounce`; on timeout, consumers SHOULD unmap and enter a retry/backoff loop. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:200 | Consumers SHOULD verify that the `streamId` in `ShmLeaseRevoked` matches the `stream_id` in the subsequent `ShmPoolAnnounce`, and that the announced `epoch` is strictly greater than the previously observed value. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:202 | The driver SHOULD NOT send duplicate `ShmLeaseRevoked` messages for the same `leaseId` unless the lease has been reissued and revoked again. Clients MUST tolerate duplicate revocations idempotently. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:251 | When the driver is embedded, deployments SHOULD still expose a well-known control-plane endpoint (channel + stream ID) so external tools (supervisors, diagnostics) can attach. If the control-plane endpoint is dynamic, deployments SHOULD publish it via service discovery or out-of-band configuration. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:308 | The driver MAY support an administrative termination mechanism. If implemented, it SHOULD require an authorization token configured out-of-band and MUST reject unauthenticated requests. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:310 | If implemented, the driver MUST accept a `ShmDriverShutdownRequest` on the control-plane stream. The request MUST include a `token` that matches the configured shutdown token. The driver MUST reject (ignore) shutdown requests with missing or invalid tokens. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:312 | If a shutdown request is accepted, the driver SHOULD transition to `Draining`, emit a final `ShmPoolAnnounce`, and publish `ShmDriverShutdown` after the shutdown timeout expires. The `ShmDriverShutdown.reason` SHOULD reflect the request. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:314 | On graceful shutdown, the driver SHOULD publish a `ShmDriverShutdown` notice on the control-plane stream before exiting. Clients MUST treat this notice as immediate lease invalidation, stop using mapped regions, and reattach after restart. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:316 | If a shutdown notice is not observed, clients MUST still rely on lease expiry and epoch changes via `ShmPoolAnnounce` to detect driver loss and MUST fail closed on stale mappings. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:322 | For a given `stream_id`, at most one producer lease MAY be active at any time. The SHM Driver MUST reject any attempt to attach a second producer to the same `stream_id`. Multiple consumers MAY attach concurrently without limit, subject to deployment policy. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:328 | The SHM Driver MUST increment `epoch` when a producer attaches to a stream with no existing producer lease, when a producer lease is revoked, expires, or is explicitly detached, when SHM layout parameters change, or when SHM backing files are recreated or reinitialized. Consumers MUST treat any `epoch` change as a hard remapping boundary. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:334 | If a producer terminates unexpectedly, the SHM Driver SHOULD detect failure via lease keepalive expiration, process liveness detection, or stale activity timestamps. The driver MUST invalidate the producer lease and MUST increment `epoch` before granting a new producer lease for the same stream. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:340 | When the Driver Model is used, the SHM Driver MUST be the entity that emits `ShmPoolAnnounce`. ShmPoolAnnounce serves as a broadcast beacon for discovery, supervision, and liveness monitoring. Attach requests provide an on-demand mechanism to obtain the same authoritative information. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:342 | If the Wire Specification requires a `producerId`, the driver MUST populate it with the currently attached producer's `clientId` for the stream (or zero if no producer is attached). | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:348 | The SHM Driver MUST enforce all filesystem validation rules defined in the Wire Specification, including base directory containment, canonical path resolution, regular-file-only backing, and hugepage enforcement. Clients MUST NOT bypass or weaken these rules. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:354 | If the SHM Driver terminates, all leases are implicitly invalidated. Clients MUST treat all mapped SHM regions as stale and MUST reattach once the driver restarts. The driver MUST increment `epoch` before reissuing leases. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:360 | To avoid manual Aeron stream ID assignment and prevent collisions across hosts, drivers MAY allocate stream IDs dynamically within configured ranges. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:364 | - If `policies.allow_dynamic_streams=true`, the driver MUST allocate `stream_id` for new streams from `driver.stream_id_range`. If the range is empty or unset, the driver MUST reject dynamic stream creation with `code=INVALID_PARAMS` (or fail fast at startup). | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:365 | - For per-consumer descriptor/control streams, the driver SHOULD allocate IDs from `driver.descriptor_stream_id_range` and `driver.control_stream_id_range` when a consumer requests per-consumer streams with `descriptor_stream_id=0` or `control_stream_id=0`. If the relevant range is unset or empty, the driver MUST decline the per-consumer stream request and fall back to shared streams (i.e., return the shared descriptor/control channel and stream IDs). | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:366 | - If the relevant per-consumer range is exhausted, the driver MUST decline the per-consumer stream request by returning empty channel and null/zero stream ID in `ConsumerConfig` (see Wire Spec §10.1.3). The attach itself MAY still succeed. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:367 | - Ranges MUST NOT overlap with the driver control/announce/QoS stream IDs, any statically configured `streams.*.stream_id`, or with each other. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:368 | - The driver MUST validate ranges at startup (start ≤ end, non-overlapping). On invalid configuration, the driver MUST fail fast or reject attach requests with `code=INVALID_PARAMS`. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:369 | - Deployments SHOULD assign non-overlapping ranges per host (or per driver instance) to prevent cross-host collisions. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:371 | These rules are informational for static-only deployments; a driver MAY still operate with fully static IDs. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:383 | This Driver Model specification is normatively dependent on the Wire Specification. The Wire Specification defines encoding and layout semantics; the Driver Model defines ownership, lifecycle, and coordination semantics. Deployments that use an external SHM Driver MUST implement this document to ensure interoperability. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:389 | Deployments MAY configure the driver to delete and recreate existing SHM backing files at startup (for example, in controlled or single-tenant environments). When this mode is enabled, the driver MUST still enforce the epoch rules in §6 and §10 before issuing new leases. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:395 | Drivers SHOULD follow the directory layout guidance in the Wire Specification (§15.21a.3). When multiple drivers (embedded or external) can run on the same host, they SHOULD rely on the per-user namespace, stream_id scoping, and (if needed) distinct `shm_base_dir` roots to avoid collisions. Embedded drivers SHOULD use the same `shm_base_dir` layout as external drivers for operational consistency. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:414 | The driver is typically configured via a TOML file. The following keys are the canonical configuration surface. Implementations MAY add additional keys, but SHOULD preserve these names and defaults for interoperability. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:416 | Drivers SHOULD also accept equivalent environment variables, following Aeron’s convention: uppercase the key and replace `.` with `_`. For example, `driver.control_stream_id` maps to `DRIVER_CONTROL_STREAM_ID`. Environment variables MUST override TOML settings when both are provided. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:426 | - `streams.*` (table): if `policies.allow_dynamic_streams=false`, each stream MUST be explicitly defined. | Default | Default | Mapped |  |
| docs/SHM_Driver_Model_Spec_v1.0.md:448 | - `policies.mlock_shm` (bool): mlock SHM regions on create; if enabled and `mlock` fails, the driver MUST treat it as a fatal error. `mlock` is per-process; clients SHOULD mlock their own mappings when enabled. On unsupported platforms, implementations SHOULD warn and treat it as a no-op. Default: `false`. | Default | Default | Mapped |  |


## docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md

Default code refs: src/agents/bridge, src/agents/bridge/proxy.jl
Default tests: test/test_bridge_*, test/test_bridge_integrity.jl

| Requirement ID | Requirement | Code refs | Test refs | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:8 | The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHOULD”, “SHOULD NOT”, and “MAY” are to be interpreted as described in RFC 2119. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:46 | A single bridge instance MAY host mappings in both directions (A→B and B→A). In this case, each mapping is independent; stream IDs MUST be distinct, and deployments SHOULD avoid creating feedback loops (e.g., bridging a stream back to its origin with the same IDs). If the same UDP channels are reused for both directions, stream IDs MUST disambiguate all payload/control/metadata traffic. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:55 | - Multicast is supported and MAY be used for one-to-many fan-out (use a multicast endpoint address in the UDP channel). | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:71 | Bridge payload streams SHOULD use a reserved stream ID range (e.g., 50000-59999) to avoid collisions with local control/descriptor streams. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:74 | - If the bridge publishes into driver-owned SHM on the destination host, it MUST attach as the exclusive producer for the destination stream and obey the driver’s stream ID allocation rules (see Driver Spec §11). If a producer is already attached for the destination stream, the bridge MUST fail or remap to a different destination. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:75 | - If `dest_stream_id` is omitted or set to `0`, the bridge MUST allocate from a configured bridge range (e.g., `bridge.dest_stream_id_range`) and MUST ensure it does not overlap driver control/announce/QoS stream IDs, any statically configured stream IDs, or other bridge ranges on the destination host. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:76 | - The bridge MUST NOT allocate per-consumer streams; it publishes only to the configured `dest_stream_id` (and optional metadata/control stream IDs per mapping). | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:104 | - `chunkCount` MUST be >= 1. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:105 | - `chunkCount` MUST NOT exceed 65535. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:106 | - `chunkIndex` MUST be < `chunkCount`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:107 | - For `chunkIndex==0`, `headerIncluded` MUST be TRUE and `headerBytes` MUST contain the full 256-byte SlotHeader block (60-byte fixed prefix + 4-byte varData length + 192-byte TensorHeader). | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:108 | - For `chunkIndex==0`, `chunkOffset` MUST be 0. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:109 | - For `chunkIndex>0`, `headerIncluded` MUST be FALSE. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:110 | - `chunkOffset` and `chunkLength` MUST describe a non-overlapping slice of the payload. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:111 | - The sum of all `chunkLength` values MUST equal `payloadLength`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:112 | - `payloadLength` MUST NOT exceed the largest supported local `stride_bytes`; receivers MUST drop frames that violate this limit. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:113 | - `payloadLength` MUST NOT exceed `bridge.max_payload_bytes`; receivers MUST drop frames that violate this limit. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:114 | - Receivers MUST drop all frame chunks until a `ShmPoolAnnounce` has been received for the mapping. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:115 | - Chunks SHOULD be sized to fit within the configured MTU for the UDP channel to avoid fragmentation. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:116 | - Implementations SHOULD size chunks to allow Aeron `try_claim` usage (single buffer write) and avoid extra copies. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:118 | - When `headerIncluded=TRUE`, `headerBytes` length MUST be 256. When `headerIncluded=FALSE`, `headerBytes` length MUST be 0. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:119 | - Receivers MUST drop chunks where `headerIncluded=TRUE` but `headerBytes.length != 256`, or `headerIncluded=FALSE` and `headerBytes.length > 0`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:120 | - `payloadBytes` length MUST equal `chunkLength`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:121 | - `traceId` MUST be identical across all chunks for a given frame. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:122 | - If integrity is enabled, `payloadCrc32c` MUST be populated and receivers MUST drop chunks that fail CRC validation. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:123 | - If the source `FrameDescriptor.trace_id` is non-zero, bridge senders MUST set | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:124 | `traceId` to that value; otherwise they MUST set `traceId=0`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:125 | - Receivers MUST drop the frame if `traceId` differs across chunks for the same | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:127 | - Chunks MAY arrive out-of-order; receivers MUST assemble by `chunkOffset` and `chunkLength`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:128 | - Senders SHOULD publish chunks in order but MUST NOT require in-order delivery. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:129 | - Duplicate chunks MAY be ignored if identical; overlapping or conflicting chunks for the same offset MUST cause the frame to be dropped. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:131 | - Receivers MUST drop chunks where `chunkLength` exceeds the configured `bridge.chunk_bytes`, MTU-derived bound, or `bridge.max_chunk_bytes`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:132 | - Decoders MUST NOT allocate buffers larger than configured `bridge.max_chunk_bytes` for `payloadBytes`; oversized varData fields MUST be rejected. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:136 | If any chunk is missing or inconsistent, the receiver MUST drop the frame and MUST NOT publish a `FrameDescriptor` for it. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:140 | Receivers MUST apply a per-stream frame assembly timeout (RECOMMENDED: 100-500 ms). Incomplete frames exceeding this timeout MUST be dropped, and any in-flight frame state MUST be discarded (including associated buffer credits). | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:142 | The timeout SHOULD be configurable via `bridge.assembly_timeout_ms`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:146 | The bridge assumes Aeron UDP reliability. If additional integrity is required, deployments MAY enable a CRC32C policy. When `bridge.integrity_crc32c=true`, senders MUST populate `payloadCrc32c` and receivers MUST drop chunks whose CRC does not match. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:149 | - For chunks where `headerIncluded=TRUE`, `payloadCrc32c` MUST be computed over `headerBytes \|\| payloadBytes`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:150 | - For chunks where `headerIncluded=FALSE`, `payloadCrc32c` MUST be computed over `payloadBytes` only. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:151 | - Receivers MUST treat missing or zero `payloadCrc32c` as invalid when integrity is enabled. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:160 | 2. Drop frames until at least one `ShmPoolAnnounce` has been received for the mapping; receivers MUST NOT accept payloads without a source pool announce. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:161 | 3. Drop frames if the chunk `epoch` does not match the most recent forwarded `ShmPoolAnnounce` epoch for the mapping; receivers MUST NOT write into a mapping with mismatched epoch/layout. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:162 | 4. Validate the header: `values_len_bytes` MUST equal `payloadLength`; `ndims`, `dtype`, and `dims` MUST be within local limits; malformed headers MUST be dropped. Header length requirements in §5.2 are mandatory. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:163 | The embedded header MUST decode to a supported type (v1.0: `TensorHeader` with the expected schemaId/version/templateId and length); otherwise drop. `payload_offset` MUST be 0 in v1.2. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:164 | 5. Validate `headerBytes.pool_id` against the source pool range from the most recent forwarded `ShmPoolAnnounce` for the mapping; invalid pool IDs MUST be dropped. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:165 | 6. Validate `payloadLength` against the source pool stride (from the forwarded announce); if `payloadLength` exceeds the source `stride_bytes`, the frame MUST be dropped. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:166 | 7. Select the local payload pool and slot using configured mapping rules (e.g., smallest stride >= `payloadLength`). If no local pool can fit the payload, or if `payloadLength` exceeds the largest local `stride_bytes`, the receiver MUST drop the frame. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:168 | 9. Write the `SlotHeader` (with embedded TensorHeader) into the local header ring (with logical sequence preserved), but override `pool_id` and `payload_slot` to match the local mapping. The receiver MUST ignore source `pool_id` and `payload_slot` values. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:172 | The receiver MUST treat `seq` as the canonical frame identity and MUST ensure it matches `seq_commit >> 1`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:178 | The bridge receiver publishes a standard `FrameDescriptor` for the re-materialized frame. The derived header index and payload slot refer to the receiver's local SHM pools. The receiver MUST publish `FrameDescriptor` on its standard local IPC descriptor channel and stream for `dest_stream_id` (per the wire specification), unless explicitly overridden by deployment configuration. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:180 | If `BridgeFrameChunk.traceId` is non-zero, the receiver MUST set | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:182 | descriptor. If `traceId=0`, the receiver MUST set `trace_id` to 0. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:184 | Bridge senders MUST NOT publish local `FrameDescriptor` messages over UDP; only `BridgeFrameChunk` messages are carried over the bridge transport. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:190 | Bridge instances MUST support forwarding `DataSourceAnnounce` and `DataSourceMeta` from the source stream to the receiver host. When `bridge.forward_metadata=true`, the sender MUST forward metadata over `bridge.metadata_channel`/`bridge.metadata_stream_id`, and the receiver MUST publish the forwarded metadata on the destination host's standard local IPC metadata channel/stream. The forwarded `stream_id` MUST be rewritten to `metadata_stream_id` for the mapping (defaulting to `dest_stream_id` if unset) and MUST preserve `meta_version`. If the metadata channel/stream is not configured, the bridge MUST disable metadata forwarding for that mapping (and SHOULD fail fast if `bridge.forward_metadata=true`). When `bridge.forward_metadata=false`, metadata MAY be omitted and bridged consumers will lack metadata. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:192 | When `bridge.forward_tracelink=true`, the bridge MUST forward `TraceLinkSet` | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:196 | forwarded `stream_id` MUST be rewritten to `metadata_stream_id` (defaulting to | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:198 | the bridge MUST disable TraceLink forwarding for that mapping (and SHOULD fail | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:203 | Bridge instances MUST forward `ShmPoolAnnounce` for each mapped source stream to the receiver host on the bridge control channel. The receiver MUST use the most recent forwarded announce to validate pool IDs and epochs and MUST NOT republish the source `ShmPoolAnnounce` to local consumers. Metadata forwarding does not use the bridge control channel. When enabled, QoS and FrameProgress MUST be carried on the bridge control channel. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:205 | Decoders on the bridge control channel MUST validate `MessageHeader.schemaId` | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:213 | - The bridge MUST treat an epoch change on the source stream as a remap boundary. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:214 | - If `epoch` changes, the receiver MUST drop any in-flight bridge frames and wait for new frames with the new epoch. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:215 | - Once a receiver observes a higher `epoch` for a stream, it MUST drop any subsequent chunks that carry an older `epoch`. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:216 | - When the receiver first observes a source epoch for a stream, it MUST initialize its local SHM pool epoch at 1 (or increment from any prior local epoch). The receiver's local epoch is independent of the source epoch but MUST be incremented on receiver restart. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:222 | Bridge instances MAY forward or translate `QosProducer`/`QosConsumer` messages; when `bridge.forward_qos=true`, they SHOULD do so on the bridge control channel using the per-mapping `source_control_stream_id` and `dest_control_stream_id`. A minimal bridge only handles payload and local descriptor publication. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:224 | Bridge instances MAY forward `FrameProgress`; when `bridge.forward_progress=true`, they MUST: | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:227 | - `FrameProgress.streamId` MUST be set to `source_stream_id` (sender) and rewritten to `dest_stream_id` (receiver). | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:228 | - `FrameProgress.epoch`, `seq`, `payloadBytesFilled`, and `state` MUST be preserved as received from the source. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:229 | 3. Receiver MUST republish forwarded `FrameProgress` on the destination host's local IPC control stream at `dest_control_stream_id` (per mapping). | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:231 | Receivers derive the local header index from `seq` before republishing. If the mapping cannot be determined, the receiver MUST drop the forwarded progress for that frame. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:233 | Progress forwarding is sender-side (as observed from the source stream) and independent of whether the receiver has finished re-materialization. Receivers SHOULD drop forwarded progress that refers to unknown or expired assembly state. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:235 | If `bridge.forward_progress=true`, both `source_control_stream_id` and `dest_control_stream_id` MUST be nonzero for each mapping. If either is unset, the mapping is invalid and the bridge MUST drop forwarded progress for that mapping (and SHOULD fail fast at startup if possible). | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:237 | Consumers MUST still treat `FrameDescriptor` as the canonical availability signal. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:243 | The bridge is a separate application from the driver and SHOULD be configured independently. The following keys define a minimal configuration surface; implementations MAY add additional keys. | Default | Default | Mapped |  |
| docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md:262 | - `bridge.dest_stream_id_range` (string or array): inclusive range for dynamically allocated destination stream IDs when `dest_stream_id=0`. Ranges MUST NOT overlap metadata/control/QoS stream IDs or other bridge ranges. Default: empty (disabled). | Default | Default | Mapped |  |


## docs/SHM_Discovery_Service_Spec_v_1.0.md

Default code refs: src/agents/discovery, src/discovery/Discovery.jl
Default tests: test/test_discovery_*

| Requirement ID | Requirement | Code refs | Test refs | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:13 | The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHOULD”, “SHOULD NOT”, and “MAY” are to be interpreted as described in RFC 2119. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:40 | - MAY implement the Discovery API directly | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:49 | A Discovery Provider MAY be: | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:57 | - MUST still attach via the authoritative SHM Driver | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:58 | - MUST validate epochs, layout versions, and SHM superblocks | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:65 | 2. Discovery responses MUST NOT be treated as authoritative. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:66 | 3. Clients MUST NOT attach, map, or consume SHM solely based on Discovery responses. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:67 | 4. All attachments MUST be validated via the authoritative SHM Driver. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:91 | When Discovery is embedded in the Driver, `discovery.*` MAY default to the driver control endpoint. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:93 | If discovery shares a channel or stream with other control-plane traffic, implementations MUST gate decoding on the SBE message header `schemaId` (and `templateId`) to avoid mixed-schema collisions. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:97 | - Clients MUST provide a response channel and stream ID in each request. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:98 | - Discovery Providers MUST publish responses to the provided response endpoint. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:99 | - Providers MUST NOT respond on the request channel unless the client explicitly requests it. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:108 | - Optional primitive fields MUST use explicit nullValue sentinels as defined in the SBE schema. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:109 | - Variable-length `data` fields are optional by encoding length = 0. Producers MUST use length 0 to indicate absence; consumers MUST treat length 0 as “not provided”. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:131 | - If no filters are supplied, all known streams MAY be returned (subject to limits). | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:132 | - If multiple filters are provided, they MUST be treated as AND. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:133 | - Requests with empty `response_channel` or `response_stream_id=0` MUST be rejected. Providers MUST drop such requests silently and MUST NOT emit any response when `response_channel` is empty. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:134 | - `response_stream_id` is required on the wire and MUST be non-zero; providers MUST reject any request whose encoded value is 0. If `response_channel` is non-empty, providers SHOULD return `status=ERROR` to the response endpoint; if `response_channel` is empty, providers MUST drop the request without responding. Clients MUST NOT send zero. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:136 | - Providers MUST return `data_source_name` exactly as announced (byte-for-byte); clients MUST compare names byte-for-byte. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:137 | - `data_source_name` SHOULD be at most 256 bytes. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:141 | - If multiple tags are provided, all requested tags MUST be present on a stream result. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:142 | - Duplicate tags in a request MUST be treated as a single tag for matching purposes. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:145 | - `client_id` is an opaque identifier provided by the client. Providers MAY use it for logging, rate limiting, or access control, but MUST NOT treat it as an authentication token. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:148 | - `response_stream_id` MUST be non-zero; providers MUST reject requests with zero as invalid. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:186 | - Providers MUST return the full tag set for the stream (not a filtered subset), so clients can cache and display complete metadata. Tags MUST preserve original case; ordering is unspecified. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:195 | - Clients MUST use these fields when initiating attach operations. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:196 | - The authority fields refer to the Driver control endpoint used for `ShmAttach*` and lease messages. Per-consumer descriptor/control streams (if used) are separate and MUST NOT be inferred from discovery responses. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:197 | - `driver_control_channel` MUST be non-empty; results with an empty channel MUST be treated as invalid by clients. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:198 | - `driver_control_stream_id` is required on the wire and MUST be non-zero; providers MUST NOT emit results where the value is 0, and clients MUST treat zero as invalid and ignore any such result. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:199 | - Providers SHOULD cap responses (RECOMMENDED: max 1,000 results) and MAY return `status=ERROR` with an `error_message` if limits are exceeded. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:200 | - `error_message` SHOULD be limited to 1024 bytes for UDP MTU safety. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:201 | - Responses MUST echo `request_id`. Clients MUST drop responses with unknown `request_id`. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:202 | - If `pool_nslots` is present in results, providers MUST ensure it matches `header_nslots` for v1.0; clients MUST treat any mismatch as a protocol error and reattach. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:203 | - `status=OK` MUST be used when the request is processed successfully, even if there are zero matching results. `status=NOT_FOUND` MUST be used only to indicate that no visible matches exist (after applying ACLs/filters). `status=ERROR` is reserved for internal failures or malformed requests. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:204 | - When `status=ERROR` or `status=NOT_FOUND`, the `results` group MUST be empty (`numInGroup = 0`). Clients MUST ignore any results if a non-zero count is received with these statuses. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:221 | - Entries MUST expire if no `ShmPoolAnnounce` is observed within a timeout window. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:222 | - RECOMMENDED expiry: `3 × announce_period_ms` | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:225 | Expired entries MUST NOT be returned in Discovery responses. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:229 | - If multiple announces are observed for the same `(driver_instance_id, stream_id)` with different `epoch`, the newest `epoch` MUST replace prior entries. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:230 | - Providers SHOULD drop entries that regress `epoch` unless a driver restart is known (e.g., driver endpoint changes or `driver_instance_id` changes). | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:234 | Discovery Providers MUST derive their index from: | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:239 | Providers MAY also index: | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:247 | Clients MUST: | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:258 | Clients MUST NOT: | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:262 | Clients SHOULD: | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:264 | - Apply a local freshness window: if the provider returns stale epochs or layouts (e.g., by mismatch against `ShmPoolAnnounce`), the client SHOULD discard and re-query. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:272 | - A standalone Registry service MAY aggregate announcements from multiple Drivers | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:274 | - Registries MAY apply policy filters, ACLs, or visibility rules | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:276 | Registries MUST NOT proxy or modify attach semantics. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:282 | Discovery MAY advertise streams that are not locally attachable. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:284 | Such streams MAY include metadata indicating: | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:295 | - Clients MUST reject Discovery messages with unsupported schema versions. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:296 | - Clients MUST use the SBE message header (`schemaId`, `version`) to determine discovery schema compatibility. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:297 | - Providers SHOULD include a `discovery_schema_version` constant in their SBE schema (for codegen/diagnostics), but clients MUST rely on the message header for version checks. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:298 | - For v1.0, the discovery schema uses `schemaId=910`, `version=1`, and template IDs: `DiscoveryRequest=1`, `DiscoveryResponse=2`. Implementations MUST reject mismatched `schemaId` or unsupported `version`. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:314 | - Providers MUST treat discovery as advisory and MUST NOT grant access implicitly. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:315 | - Providers MAY enforce ACLs and visibility filters based on client identity. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:316 | - If access control is used, providers MUST return `status=NOT_FOUND` for unauthorized streams to avoid oracle leakage, or `status=ERROR` if policy requires explicit denial. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:322 | - Embedded discovery SHOULD reuse the driver control channel for simplicity. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:323 | - Standalone registries SHOULD be replicated for availability. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:324 | - Providers SHOULD log discovery queries at a sampled rate to avoid PII leaks. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:353 | - `responseStreamId` MUST be present and non-zero. If zero, the request MUST be rejected (see §5.1). | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:354 | - `responseChannel` MUST be non-empty. If length=0, providers MUST drop the request without responding. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:355 | - `driverControlStreamId` MUST be present and non-zero. Results with zero MUST be omitted or treated as invalid by clients. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:356 | - When `status=ERROR` or `status=NOT_FOUND`, `results.numInGroup` MUST be 0; clients MUST ignore any results if a non-zero count is received. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:357 | - `data_source_name` SHOULD be at most 256 bytes. | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:402 | <!-- responseChannel length=0 is invalid; providers MUST drop such requests without responding --> | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:410 | <!-- When status=ERROR or NOT_FOUND, results.numInGroup MUST be 0 --> | Default | Default | Mapped |  |
| docs/SHM_Discovery_Service_Spec_v_1.0.md:420 | <!-- driverControlStreamId MUST be non-zero; zero is invalid --> | Default | Default | Mapped |  |


## docs/SHM_RateLimiter_Spec_v1.0.md

Default code refs: src/agents/ratelimiter
Default tests: test/test_rate_limiter_*

| Requirement ID | Requirement | Code refs | Test refs | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| docs/SHM_RateLimiter_Spec_v1.0.md:8 | The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHOULD”, “SHOULD NOT”, and “MAY” are to be interpreted as described in RFC 2119. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:41 | The rate limiter MUST NOT publish `FrameDescriptor` messages for the source stream and MUST only publish to the destination stream. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:42 | The rate limiter MUST attach as the sole producer for the destination stream and MUST enforce exclusive producer semantics (per the Driver Model). | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:48 | - **Rate-limit**: accept frames at most `max_rate_hz` (0 = unlimited). The rate limiter SHOULD publish the most recent frame available when the next rate slot opens. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:50 | Only one rate-limit policy is active per instance. If multiple policies are required, they MUST be expressed as distinct rate limiter instances. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:52 | The rate limiter MUST preserve logical sequence identity when republishing: `FrameDescriptor.seq` MUST equal `seq_commit >> 1` in the destination header. The rate limiter MUST copy the source sequence into the destination header/descriptor; dropped frames result in sequence gaps on the destination stream. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:54 | When operating per-consumer, the rate limiter MUST treat `ConsumerHello.max_rate_hz` as the authoritative rate limit for that consumer. A value of `0` means unlimited. The rate limiter MUST NOT aggregate or apply policies across multiple consumers. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:56 | The first accepted frame after start or remap is eligible immediately, and the rate timer MUST reset on rate limiter restart and on source epoch change. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:71 | If the destination pool cannot fit the payload, the rate limiter MUST drop the frame. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:72 | If the destination slot cannot be claimed immediately (e.g., ring overwrite under load), the rate limiter MUST drop the frame and continue; it MUST NOT block. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:78 | When `rate_limiter.forward_metadata=true`, rate limiters MUST forward `DataSourceAnnounce` and `DataSourceMeta` from the source stream to the destination stream. The forwarded metadata MUST preserve `meta_version` and MUST rewrite `stream_id` to the destination stream_id for the mapping. If `metadata_stream_id` is configured for the mapping, the rate limiter MUST publish metadata on that stream and set `stream_id` accordingly. When `rate_limiter.forward_metadata=false`, metadata MAY be omitted and consumers will lack metadata. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:84 | Rate limiters MAY forward `FrameProgress`; when enabled they SHOULD publish progress on `rate_limiter.control_channel`/`rate_limiter.dest_control_stream_id`. `FrameProgress.streamId` MUST be rewritten to the destination stream_id and `seq` MUST be preserved; receivers derive the local header index from `seq`. Consumers MUST still treat `FrameDescriptor` as the canonical availability signal. All mappings share the same control channel/stream IDs; disambiguation is by `streamId`. The source control stream ID is shared across all mappings, and the rate limiter subscribes on `rate_limiter.control_channel`/`rate_limiter.source_control_stream_id`. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:86 | Rate limiters MAY forward or translate `QosProducer`/`QosConsumer` messages; when enabled they SHOULD publish them on `rate_limiter.qos_channel`/`rate_limiter.dest_qos_stream_id` and rewrite `streamId` to the destination stream_id. Other fields MAY be preserved for observability. All mappings share the same QoS channel/stream IDs; disambiguation is by `streamId`. The source QoS stream ID is shared across all mappings, and the rate limiter subscribes on `rate_limiter.qos_channel`/`rate_limiter.source_qos_stream_id`. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:92 | - The rate limiter MUST treat a source epoch change as a remap boundary and drop in-flight frames until remap completes. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:93 | - The destination stream MUST use its own local epoch, incremented on rate limiter restart, independent of the source epoch. | Default | Default | Mapped |  |
| docs/SHM_RateLimiter_Spec_v1.0.md:124 | When `rate_limiter.forward_progress=true`, `rate_limiter.source_control_stream_id` and `rate_limiter.dest_control_stream_id` MUST be nonzero; otherwise the rate limiter MUST fail fast or disable progress forwarding with an error. When `rate_limiter.forward_qos=true`, `rate_limiter.source_qos_stream_id` and `rate_limiter.dest_qos_stream_id` MUST be nonzero; otherwise the rate limiter MUST fail fast or disable QoS forwarding with an error. Forwarding MUST NOT start when required IDs are zero. | Default | Default | Mapped |  |


## docs/SHM_Join_Barrier_Spec_v1.0.md

Default code refs: src/agents/joinbarrier
Default tests: test/test_join_barrier_*

| Requirement ID | Requirement | Code refs | Test refs | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| docs/SHM_Join_Barrier_Spec_v1.0.md:9 | `docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md`. Implementations MAY adopt this feature | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:14 | The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT", and "MAY" | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:43 | When multiple outputs are emitted per input frame, processed_time SHOULD | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:52 | - The steady-state hot path MUST remain type-stable and zero-allocation after | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:54 | - JoinBarrier MUST NOT wait on SHM slot commit or overwrite prevention. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:55 | - JoinBarrier MUST only gate attempts to process; slot validation remains | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:57 | - MergeMap MUST be treated as configuration (low-rate, control-plane data). | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:69 | Each MergeMap entry consists of one or more rules. Each rule MUST identify an | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:72 | For each rule, exactly one parameter MUST be present: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:73 | - For `OFFSET`, `offset` MUST be non-null and `windowSize` MUST be null. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:74 | - For `WINDOW`, `windowSize` MUST be non-null and `offset` MUST be null. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:75 | Rules violating these constraints MUST be rejected, and the MergeMap MUST be | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:85 | The offset MUST be encoded as a signed 32-bit integer. If `out_seq + offset` | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:86 | would be negative for a given `out_seq`, SequenceJoinBarrier MUST treat the rule as not | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:97 | Window size MUST be a positive integer. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:98 | If `out_seq + 1 < N`, SequenceJoinBarrier MUST treat the rule as not ready. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:99 | SequenceJoinBarrier readiness uses only the upper bound; the join stage MAY | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:100 | attempt to process all frames in the window but MUST tolerate missing or | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:101 | overwritten frames. Implementations MAY add an optional lower-bound availability | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:102 | check (e.g., based on header ring size and observed cursor), but MUST NOT wait | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:108 | required input timestamps `in_time`. All timestamps MUST use a declared clock | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:111 | For each timestamp rule, exactly one parameter MUST be present: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:112 | - For `OFFSET_NS`, `offsetNs` MUST be non-null and `windowNs` MUST be null. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:113 | - For `WINDOW_NS`, `windowNs` MUST be non-null and `offsetNs` MUST be null. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:114 | Rules violating these constraints MUST be rejected, and the MergeMap MUST be | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:123 | The offset MUST be encoded as a signed 64-bit integer. If `out_time + offset_ns` | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:124 | would be negative for a given `out_time`, TimestampJoinBarrier MUST treat the | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:134 | Window size MUST be a positive integer. If `out_time < window_ns`, the rule is | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:138 | `out_time`; deployments that expect lagged inputs SHOULD size `latenessNs` to | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:143 | - MergeMap MUST be scoped to `(out_stream_id, epoch)`. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:144 | - MergeMap changes MUST invalidate SequenceJoinBarrier and TimestampJoinBarrier | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:146 | - On epoch change, JoinBarrier MUST require a fresh MergeMap before resuming | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:153 | For a given `out_seq`, SequenceJoinBarrier readiness MUST be computed as follows: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:162 | If all conditions are satisfied, SequenceJoinBarrier MAY allow the stage to attempt | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:167 | - SequenceJoinBarrier MUST NOT wait for SHM slot commit stability. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:168 | - SequenceJoinBarrier MUST NOT attempt to prevent overwrite in the SHM data plane. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:169 | - Slot validation MUST remain single-attempt with drop-on-failure semantics. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:173 | - If no MergeMap is available for `(out_stream_id, epoch)`, SequenceJoinBarrier MUST | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:176 | SequenceJoinBarrier MAY resume readiness evaluation for subsequent `out_seq` values. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:180 | JoinBarriers MAY support a staleness policy that allows progress when a required | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:185 | - When a required input is stale, the JoinBarrier MAY treat it as absent for the | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:187 | - The join stage MUST surface which inputs were absent (implementation-defined | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:189 | - If `staleTimeoutNs` is absent, the JoinBarrier MUST continue to block on | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:200 | For a given output timestamp `out_time`, TimestampJoinBarrier readiness MUST be | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:213 | If all conditions are satisfied, TimestampJoinBarrier MAY allow the stage to | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:220 | - The timestamp source MUST be declared per rule and MUST be either | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:225 | - When `TimestampSource=FRAME_DESCRIPTOR`, the FrameDescriptor timestamp MUST | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:227 | - When `TimestampSource=SLOT_HEADER`, the slot header timestamp MUST be present | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:229 | - All participating rules MUST use the same `clockDomain`, or the join MUST be | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:233 | MUST be rejected. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:234 | - Lateness MUST be configured via `TimestampMergeMapAnnounce`. If absent, | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:241 | reach `out_time`; deployments that expect lagged inputs SHOULD set | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:243 | - For streams participating in TimestampJoinBarrier, timestamps MUST be | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:244 | monotonic non-decreasing within a stream; otherwise the stream MUST be | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:246 | - If a required timestamp is absent (null), the rule MUST be treated as not | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:248 | - The output `out_time` MUST be monotonic non-decreasing for a given output | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:249 | stream and MUST use the declared clock domain. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:253 | - TimestampJoinBarrier MUST NOT wait for SHM slot commit stability. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:254 | - TimestampJoinBarrier MUST NOT attempt to prevent overwrite in the SHM data | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:256 | - Slot validation MUST remain single-attempt with drop-on-failure semantics. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:290 | For a given output tick (sequence or timestamp), LatestValueJoinBarrier MUST be | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:292 | frame in the current epoch. Required input streams MUST be derived from the | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:293 | active MergeMap; rule parameters are ignored. It MUST NOT require alignment on | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:297 | fails slot validation, that input MUST be treated as absent for the current | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:299 | If any required input is absent after validation, readiness MUST be considered | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:300 | false and the join MUST be retried on a subsequent tick. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:302 | LatestValueJoinBarrier MUST NOT use frames from prior epochs. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:305 | stream after adopting the current epoch for that stream. Implementations MAY | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:311 | - For each input stream, LatestValueJoinBarrier MUST select the most recent | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:313 | - Implementations MAY choose sequence or timestamp ordering per stream, but | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:314 | MUST be consistent within a join stage. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:315 | - If timestamp ordering is used, the timestamp source for each stream MUST use | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:317 | stage MUST share a single clock domain to make "most recent" unambiguous. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:323 | - LatestValueJoinBarrier MUST be treated as best-effort and MAY use stale data. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:324 | - It MUST NOT wait for SHM slot commit stability or prevent overwrite. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:325 | - It SHOULD be used only when the application tolerates temporal misalignment. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:331 | A new control-plane message is REQUIRED to convey MergeMap rules. The message | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:332 | MUST be SBE-encoded and carried on the control stream (shared or per-consumer) | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:337 | The message MUST contain: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:344 | Each rule MUST encode: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:350 | Implementations SHOULD encode `rules` as an SBE repeating group with fixed | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:353 | Template IDs and field IDs MUST be allocated in the control-plane schema | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:355 | MergeMap authorities SHOULD re-announce MergeMap rules at a low cadence as | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:356 | soft-state, and MUST respond to explicit `SequenceMergeMapRequest` messages. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:357 | Implementations MUST set `MessageHeader.schemaId = 903` for MergeMap messages. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:361 | FrameDescriptor remains the availability signal. No changes are REQUIRED for | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:367 | request/response path is REQUIRED. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:369 | - A consumer that needs MergeMap MUST send a `SequenceMergeMapRequest` on the control | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:372 | MUST respond with a `SequenceMergeMapAnnounce` for the requested `(out_stream_id, | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:374 | - The driver MUST NOT cache or proxy MergeMap state. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:376 | The `SequenceMergeMapRequest` message MUST contain: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:381 | Implementations MAY extend the request with additional fields (e.g., a list of | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:382 | stream IDs or a capability flag), but the minimal form above is REQUIRED for | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:387 | A timestamp MergeMap announcement is REQUIRED to convey timestamp-based rules. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:388 | The message MUST be SBE-encoded and carried on the control stream per the | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:392 | The message MUST contain: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:401 | Each rule MUST encode: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:410 | Timestamp MergeMap authorities SHOULD re-announce rules at a low cadence as | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:411 | soft-state, and MUST respond to explicit `TimestampMergeMapRequest` messages. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:415 | The timestamp request message MUST contain: | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:437 | \| Epoch-scoped config \| REQUIRED \| Not applicable \| | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:446 | - Mixed schema traffic MUST be guarded by `MessageHeader.schemaId` before decode. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:447 | - Embedded TensorHeader decode MUST use `TensorHeaderMsg.wrap!` on the read path. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:448 | - TimestampJoinBarrier MUST use the same clock domain across all participating | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:449 | streams; otherwise it MUST reject the join. | Default | Default | Mapped |  |
| docs/SHM_Join_Barrier_Spec_v1.0.md:450 | - Codecs SHOULD be regenerated after spec changes to avoid schema mismatches. | Default | Default | Mapped |  |


## docs/SHM_TraceLink_Spec_v1.0.md

Default code refs: src/agents/tracelink, src/agents/bridge/proxy.jl
Default tests: test/test_tracelink_*, test/test_bridge_tracelink_chunks.jl

| Requirement ID | Requirement | Code refs | Test refs | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| docs/SHM_TraceLink_Spec_v1.0.md:13 | The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT", and "MAY" | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:33 | - TraceLink MUST NOT affect runtime scheduling, readiness, or data correctness. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:34 | - TraceLink emission MUST be best-effort and non-blocking. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:35 | - Tracing loss MUST NOT affect pipeline correctness. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:41 | Trace IDs MUST be 64-bit identifiers. Implementations SHOULD use a | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:49 | Each producer MUST use a node ID that is unique within the deployment. Node IDs | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:50 | MAY be: | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:56 | If node IDs are allocated dynamically, they MUST remain stable for the lifetime | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:59 | SHOULD: | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:65 | Dynamic allocation SHOULD reuse the driver lease/keepalive model described in | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:71 | - Root frames MUST mint a new trace ID. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:72 | - 1→1 derived frames MUST reuse the upstream trace ID. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:73 | - N→1 derived frames MUST mint a new trace ID and record parent trace IDs via | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:85 | TraceLinkSet SHOULD be emitted only when the parents group length is > 1. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:86 | It MAY be emitted with length = 1 for explicit re-rooting or retagging. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:87 | Emission is best-effort and MAY be dropped under load. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:99 | - The null trace ID sentinel MUST be `0` (unset). | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:100 | - If tracing is enabled for a stream, producers MUST populate `trace_id` with a | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:102 | - 1→1 stages MUST propagate `trace_id` unchanged. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:103 | - N→1 stages MUST mint a new `trace_id` for outputs and emit TraceLinkSet for | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:105 | - On epoch change, implementations MAY either continue trace IDs or reset them; | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:106 | the chosen behavior MUST be documented per deployment. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:112 | Consumers that do not understand `trace_id` MUST ignore it and remain fully | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:132 | - TraceLinkSet MUST use `MessageHeader.schemaId = 904` and | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:134 | - `stream_id`, `epoch`, and `seq` MUST match the corresponding | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:136 | - `trace_id` MUST identify the derived output frame. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:137 | - `parents[]` MUST list all parent trace IDs for N→1 stages and MUST contain | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:140 | `numInGroup` value is authoritative and MUST be ≥ 1. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:141 | - Parent trace IDs MUST be unique within a TraceLinkSet. Implementations SHOULD | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:143 | - TraceLinkSet SHOULD be emitted only when the parents group length is > 1. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:144 | It MAY be emitted with length = 1 for explicit re-rooting or retagging. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:165 | If tracing is disabled, implementations MAY omit rows for untraced frames, or | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:166 | MAY persist rows with `trace_id = 0` to indicate absence. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:182 | Low-rate artifacts (e.g., calibration matrices) MAY be recorded separately | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:229 | SQLite recursive CTEs MAY be used to traverse multi-hop trace graphs. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:233 | - TraceLink MUST NOT drive runtime readiness or flow control. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:256 | - Mixed-schema control streams MUST gate decoding on `MessageHeader.schemaId`. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:262 | - TraceLink messages MAY be batched. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:263 | - Tracing MAY be sampled or dropped under load. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:264 | - Persistence implementations SHOULD batch writes (e.g., 10–100 ms | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:267 | Tracing loss MUST NOT affect correctness. | Default | Default | Mapped |  |
| docs/SHM_TraceLink_Spec_v1.0.md:322 | Encoders MUST set `parents` group length (`numInGroup`) to at least 1 and MUST | Default | Default | Mapped |  |
