# Data Recorder Implementation Plan (v0.1)

Spec reference: `docs/AeronTensorPool_Data_Recorder_spec_draft_v_0.md` (authoritative).
Related specs: `docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md`, `docs/SHM_TraceLink_Spec_v1.0.md`,
`docs/SHM_Service_Control_Plane_Spec_v1.0.md`.

Goal: Implement a Julia + SQLite recorder agent that consumes `FrameDescriptor`
and SHM slots, writes SHM-layout segments, and persists a SQLite manifest per
spec while keeping hot paths type-stable and zero-allocation after init.

---

## Phase 0: Survey and decisions
- Confirm MVP scope: frames + segments + manifest only; defer metadata,
  TraceLink ingestion, and EventMessage control to a later phase.
- Decide dataset layout policy:
  - Use multi-stream shared dataset root (single manifest for multiple streams).
  - Default to larger on-disk rings than live SHM (power-of-two sizing); use
    replay rematerialization when sizes differ.
- Decide default segment sizing, retention, and checksum enablement.
- Identify reuse points in existing agents:
  - SHM read path from consumer agent.
  - Aeron publish helpers in `src/aeron/`.
  - Control-plane pollers in `src/control/`.
- Choose module placement and file layout:
  - `src/agents/recorder/` with `state.jl`, `handlers.jl`, `init.jl`,
    `lifecycle.jl`, `work.jl`, `segments.jl`, `manifest.jl`.

Status: in progress.

---

## Phase 1: Config + wiring
- Add recorder config struct and loader (likely `src/config/recorder.jl`).
- Add example config under `config/recorder_example.toml`.
- Document config keys in `docs/CONFIG_REFERENCE.md`.
- Config keys (proposed defaults):
  - `instance_id`: "recorder-01"
  - `aeron_dir`: ""
  - `aeron_uri`: "aeron:ipc?term-length=4m"
  - `shm_base_dir`: "/dev/shm"
  - `descriptor_channel`: "aeron:ipc"
  - `descriptor_stream_id`: 1100
  - `dataset_root`: "./recordings"
  - `segment_max_bytes`: 17179869184 (16 GiB)
  - `header_nslots`: 0 (auto-size from `segment_max_bytes` when 0)
  - `pool_nslots`: 0 (auto-size from `segment_max_bytes` when 0)
  - `checksum_alg`: "crc32"
  - `frame_batch_rows`: 5000
  - `frame_batch_ms`: 100
  - `wal_checkpoint_ms`: 1000
  - `sqlite_busy_timeout_ms`: 2000
  - `sqlite_synchronous`: "NORMAL"
  - `retention_max_bytes`: 0 (disabled unless set)
- Auto-size rule when `header_nslots` and `pool_nslots` are 0:
  - Compute `header_nslots = floor_pow2(segment_max_bytes /
    (header_slot_bytes + sum(pool_stride_bytes)))`.
  - Set `pool_nslots = header_nslots` for every pool to guarantee a pool slot
    for each header slot regardless of pool selection.
- Per-stream overrides (optional `[[streams]]` list):
  - `stream_id` (required)
  - `descriptor_channel`, `descriptor_stream_id` (optional overrides)
  - `header_nslots`, `pool_nslots`, `segment_max_bytes` (optional overrides)
- Validate invariants:
  - `segment_max_bytes` >= sum of region sizes.
  - `header_nslots` and `pool_nslots` are powers of two.
  - Pool strides can accommodate expected payload sizes.
  - Optional stream IDs for metadata/control/QoS are consistent.
- Config safety checks (fail fast or warn):
  - Error if computed minimum segment size exceeds `segment_max_bytes`; include
    the required size in the message.
  - Error if explicit `header_nslots`/`pool_nslots` are not powers of two.
  - Warn if any `pool_nslots < header_nslots` (pool wrap may seal early).
  - Warn if `sqlite_synchronous` is "OFF" or WAL mode is disabled.
  - Error if a payload does not fit any configured pool stride.

Status: pending.

---

## Phase 2: SQLite manifest layer
- Implement `manifest.sqlite` creation/migration using SQLite.jl:
  - `recordings`, `streams`, `segments`, `segment_pools`, `frames`.
  - Optional: `metadata_events`, `trace_links`, `events`, `data_loss`.
- Ensure `recordings.manifest_version` exists.
- Enable WAL mode and tune pragmas (busy timeout, synchronous mode).
- Add prepared statements and a batched insert buffer for `frames`.
- Commit cadence: `batch_rows` or `batch_ms` (spec default 5k/100ms).
- Periodic WAL checkpoints (>= 1s) and optional on-seal checkpoint.

Status: pending.

---

## Phase 3: Segment writer (SHM-layout on disk)
- Implement `SegmentState` with:
  - Paths, file handles, mmapped buffers.
  - Layout parameters and sequence range.
- Preallocate fixed-size files (`header.ring`, `<pool_id>.pool`).
- Initialize superblocks using `src/shm/superblock.jl`.
- Implement `segment_write!`:
  - Compute header/payload indices from `seq`.
  - Write header + payload via seqlock (`src/shm/seqlock.jl`).
- Implement `segment_full?`:
  - Seal before header or any pool ring would wrap.
- Implement `seal_segment!`:
  - fsync files.
  - compute checksum (enabled by default; algorithm configurable).
  - update SQLite `segments` with `seq_end`, `t_end_ns`, `size_bytes`.

Status: pending.

---

## Phase 4: SHM read path + descriptor handling
- Subscribe to `FrameDescriptor` and guard on `MessageHeader.schemaId`.
- Map SHM read-only pools and use seqlock read helpers.
- Read `SlotHeader` + payload from live SHM:
  - Validate `seq_commit` and header consistency.
  - Use `SlotHeader.timestamp_ns` when present, else descriptor time.
- Handle epoch changes by closing current segment and starting a new epoch.

Status: pending.

---

## Phase 5: Recorder agent core
- Implement `RecorderState` with:
  - Aeron client, subscriptions, clock cache, timers.
  - Per-stream segment state and manifest state.
  - Preallocated buffers for frame inserts.
- Implement init:
  - Create dataset root and manifest.
  - Start first segment per stream.
  - Register stream row in SQLite.
- Implement `recorder_do_work!`:
  - Fetch clock at top of cycle.
  - Poll descriptors and route to handler.
  - Flush manifest batch on interval/size.

Status: pending.

---

## Phase 6: Lifecycle + retention
- Segment rollover on epoch change or fullness.
- Circular retention:
  - Track total bytes and delete oldest sealed segments.
  - Delete manifest rows in same transaction as deletion.
- Optional `commit [t0, t1]` support:
  - Copy sealed segments and create new manifest.
- Data loss detection on missing/truncated segment files.

Status: pending.

---

## Phase 7: Optional ingestion + control plane
- Metadata capture:
  - Subscribe to metadata streams and persist rows or files in `metadata/`.
- TraceLink ingestion:
  - Subscribe to TraceLinkSet and populate `trace_links`.
- EventMessage capture:
  - Store decoded fields + raw blob.
- Recorder control via EventMessage:
  - Handle `record.enable`, `record.stream_id`, `record.query`.
  - Publish status on shared status stream.

Status: pending.

---

## Phase 8: Tests + scripts + docs
- Scripts:
  - `scripts/run_recorder.jl`
  - `scripts/run_recorder_smoke.jl`
- Tests:
  - SQLite schema + batch insert behavior.
  - Segment writer correctness (seqlock, indices).
  - Rollover/retention behavior.
  - Allocation checks in hot paths after init.
- Docs:
  - `docs/USER_GUIDE.md` recorder quickstart.
  - `docs/CONFIG_REFERENCE.md` recorder config.
  - `AGENTS.md` update to list recorder agent role.

Status: pending.

---

## Open questions
- Should datasets be per-stream or multi-stream by default?
