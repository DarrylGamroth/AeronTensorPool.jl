# AeronTensorPool Data Recorder Specification (Draft v0.1, RFC Style)

## 1. Scope

This document defines a concrete on-disk recorder design for AeronTensorPool
streams using segment files and SQLite. It specifies required behavior for
recording, metadata persistence, and optional tiering and TraceLink ingestion.
It depends on the wire spec and `docs/SHM_TraceLink_Spec_v1.0.md` but is
optional for deployments.

## 2. Key Words

The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT", and "MAY"
are to be interpreted as described in RFC 2119.

## 3. Conformance

Unless explicitly marked as Informative, sections in this document are
Normative.

## 4. Goals and Non-Goals

### 4.1 Goals

- Sustain high recording rates (target ≥ 500 MiB/s aggregate).
- Preserve zero-copy SHM semantics on the data plane (payloads copied only once
  into segments).
- Provide circular recording with overwrite semantics.
- Create portable, self-contained datasets.
- Enable time-aligned queries across multiple streams.
- Support provenance ingestion via TraceLink.

### 4.2 Non-Goals

- Database-driven ingestion of pixel payloads.
- Distributed consistency or exactly-once guarantees.
- Remote live recording over the network (handled by bridges).
- Object store formats (Zarr, HDF5, etc.) as the primary recorder.

## 5. Architecture Overview

The recorder is an out-of-band consumer of AeronTensorPool descriptors and SHM:

```
SHM Header + Payload Pools
        │
        ▼
FrameDescriptor (Aeron IPC)
        │
        ▼
Recorder Agent
  ├─ segment writer (binary payloads)
  ├─ SQLite manifest writer
  ├─ TraceLink ingestion
  └─ optional offloader (tiered storage)
```

Pixels live in segment files. Metadata lives in SQLite.

## 6. On-Disk Data Model

### 6.1 Dataset Layout

A recorder output is a directory that can be moved/copied as a unit:

```
<dataset_root>/
  manifest.sqlite
  manifest.sqlite-wal
  tensorpool-${USER}/<namespace>/<stream_id>/<epoch>/
    header.ring
    <pool_id>.pool
  metadata/
    datasource-meta.sbe
    tracelink.sbe
```

Multiple streams MAY share a dataset root or be separated per stream. The
dataset root acts as the recorder's `shm_base_dir`: recorders MUST create
epoch directories at `tensorpool-${USER}/<namespace>/<stream_id>/<epoch>/` using
the same layout as the wire spec. Epoch directories MUST be named with the
numeric epoch value.

Operationally, deployments MAY rotate datasets on a fixed cadence (e.g., one
dataset per night) to keep manifest sizes bounded and simplify archival.

### 6.2 Segment Files (SHM-Layout Plane)

- Segment region files MUST be large, fixed-size binary files; sizes SHOULD be
  power-of-two and are typically 16–32 GiB per pool.
- Segment size MUST be bounded by a configured maximum; recorders MUST seal a
  segment when it reaches the configured size limit.
- Segments MUST use the same SHM layout as the wire spec (superblock, header
  ring, and payload pools). A segment is the epoch directory at the canonical
  path and contains one header region file and one file per payload pool.
- On-disk `header_nslots`/`pool_nslots` MAY be larger than live SHM rings for the
  same stream. For zero-copy replay, the replay SHM layout MUST match the
  recorded ring sizes; otherwise replay MUST rematerialize frames using the
  mapping algorithm in §13.
- Recorders MUST write SlotHeader and payload bytes exactly as the producer
  would, using the seqlock protocol and layout rules from the wire spec.
- Segments MUST be append-only until sealed with respect to their logical
  recording window; overwrites are allowed only via circular retention.
- Recorders MUST preallocate segments to their full configured size to avoid
  sparse files and SHOULD write in large contiguous chunks (≥ 1 MiB).
- Recorders MUST NOT grow pool files at runtime. Pool files MUST be fixed-size
  for the life of the segment, and a segment MUST be sealed before any pool or
  header ring would wrap.
- Recorders MUST fsync only when sealing a segment, not per frame.
- If `segments.checksum` is populated, it MUST be computed on seal over the
  segment bytes. The checksum algorithm MUST be documented by the deployment.

Sizing guidance (informative):
- If pool selection is unconstrained, deployments SHOULD size each pool with
  `pool_nslots >= header_nslots` to avoid premature wrap.
- If expected per-pool rates are known, `pool_nslots` MAY be sized to the
  expected fraction of frames per pool, with early seal on wrap.

### 6.4 Superblock Initialization

Each region file within a segment (header or payload pool) MUST begin with a
valid SHM superblock matching the wire spec. Recorders MUST set:

- `layout_version`
- `epoch`
- `stream_id`
- `region_type` (HEADER_RING or PAYLOAD_POOL as applicable)
- slot and stride parameters

Superblock fields MUST be written before any SlotHeader or payload bytes and
must remain consistent for the life of the segment.

### 6.3 SQLite Manifest (Control Plane)

- SQLite MUST be the authoritative index for frame location and metadata.
- SQLite MUST run in WAL mode.
- Recorder implementations SHOULD batch transactions (10–100 ms or 1–10k rows,
  whichever comes first) and SHOULD expose commit/checkpoint cadence as
  configuration. Default settings SHOULD be 5,000 rows or 100 ms, and a WAL
  checkpoint SHOULD be attempted at least every 1 s.

## 7. SQLite Schema (Normative v0.1)

### 7.1 Recordings

```sql
CREATE TABLE recordings (
  recording_id INTEGER PRIMARY KEY,
  root_path    TEXT NOT NULL,
  created_ns   INTEGER NOT NULL
);
```

Recorders MUST assign a unique `recording_id` per dataset root and use it to
associate segments with their dataset.
Recorders MUST store a dataset manifest version in SQLite. The `recordings`
table MUST include a `manifest_version` column.

### 7.2 Streams

```sql
CREATE TABLE streams (
  stream_id      INTEGER PRIMARY KEY,
  name           TEXT,
  layout_version INTEGER,
  created_ns     INTEGER
);
```

### 7.3 Segments

```sql
CREATE TABLE segments (
  segment_id    INTEGER PRIMARY KEY,
  recording_id  INTEGER NOT NULL,
  stream_id     INTEGER NOT NULL,
  path          TEXT NOT NULL,
  epoch         INTEGER NOT NULL,
  layout_version INTEGER NOT NULL,
  header_nslots INTEGER NOT NULL,
  header_slot_bytes INTEGER NOT NULL,
  seq_start     INTEGER NOT NULL,
  seq_end       INTEGER,
  t_start_ns    INTEGER,
  t_end_ns      INTEGER,
  size_bytes    INTEGER,
  sealed        INTEGER NOT NULL,
  tier          INTEGER NOT NULL, -- 0=HOT, 1=COLD
  checksum_alg  TEXT,
  checksum      BLOB
);

CREATE INDEX segments_stream_time_idx
  ON segments(stream_id, t_start_ns);

CREATE INDEX segments_recording_idx
  ON segments(recording_id);
```

`segments.sealed` MUST be `0` for active segments and `1` for sealed segments.
When `sealed=1`, `seq_end`, `t_end_ns`, and `size_bytes` MUST be populated.
`segments.path` MUST refer to the epoch directory at the canonical SHM layout
path; `size_bytes` SHOULD be the sum of all region file sizes within the
segment.
If `segments.checksum` is populated, `segments.checksum_alg` MUST be populated
and MUST identify the checksum algorithm (e.g., `crc32`, `xxhash64`).

### 7.4 Segment Pools

```sql
CREATE TABLE segment_pools (
  segment_id   INTEGER NOT NULL,
  pool_id      INTEGER NOT NULL,
  path         TEXT NOT NULL,
  pool_nslots  INTEGER NOT NULL,
  stride_bytes INTEGER NOT NULL,
  PRIMARY KEY (segment_id, pool_id)
);
```

The `header.ring` file size MUST equal `header_nslots * header_slot_bytes`. Each
`<pool_id>.pool` file size MUST equal `pool_nslots * stride_bytes`.

### 7.5 Frames

```sql
CREATE TABLE frames (
  stream_id     INTEGER NOT NULL,
  epoch         INTEGER NOT NULL,
  seq           INTEGER NOT NULL,
  header_index  INTEGER NOT NULL,
  pool_id       INTEGER NOT NULL,
  payload_slot  INTEGER NOT NULL,
  t_ns          INTEGER NOT NULL,
  segment_id    INTEGER NOT NULL,
  values_len    INTEGER NOT NULL,
  meta_version  INTEGER,
  trace_id      INTEGER,
  header_bytes  BLOB,
  PRIMARY KEY (stream_id, epoch, seq)
) WITHOUT ROWID;

CREATE INDEX frames_time_idx ON frames(t_ns);
CREATE INDEX frames_trace_idx ON frames(trace_id);
```

`frames.header_bytes` MAY store the raw `SlotHeader.headerBytes` blob when
additional redundancy is desired. It is not required when segments already
encode the full SHM layout.
`frames.t_ns` SHOULD be populated from `SlotHeader.timestamp_ns`. If unavailable,
recorders MUST fall back to `FrameDescriptor.timestamp_ns`; if both are absent,
recorders MUST store `0` to indicate unknown.

### 7.7 Metadata Events (Informative)

Recorders SHOULD persist DataSourceAnnounce, DataSourceMeta, and ShmPoolAnnounce
messages in a small table or as files under `metadata/` so datasets are
self-describing. A minimal table is:

```sql
CREATE TABLE metadata_events (
  stream_id   INTEGER NOT NULL,
  t_ns        INTEGER NOT NULL,
  schema_id   INTEGER NOT NULL,
  template_id INTEGER NOT NULL,
  payload     BLOB NOT NULL
);

CREATE INDEX metadata_events_time_idx ON metadata_events(t_ns);
```

### 7.8 Trace Links

```sql
CREATE TABLE trace_links (
  trace_id        INTEGER NOT NULL,
  parent_trace_id INTEGER NOT NULL,
  PRIMARY KEY (trace_id, parent_trace_id)
) WITHOUT ROWID;
```

## 8. Recording Algorithm (Normative)

For each `FrameDescriptor`:

1. Validate epoch/layout and required SHM mapping.
2. Read committed SHM slot using the seqlock rules in the wire spec.
3. Write SlotHeader + payload into the segment files using the SHM layout and
   seqlock protocol defined by the wire spec. Payload bytes are written at
   `payload_slot * stride_bytes` in the appropriate pool file.
4. Insert a `frames` row (batched transaction) including `header_index`,
   `pool_id`, and `payload_slot`.
5. Update per-stream counters (optional).

On epoch change for a stream:
- Recorder MUST seal the current segment for that stream and start a new epoch
  directory with the new `epoch` and `layout_version`.

On segment full:
- Seal segment and fsync.
- Create a new segment and continue.
Segment fullness MUST be triggered when either the header ring or any payload
pool ring would wrap for the next write.

## 9. Circular Recording

### 9.1 Pure Ring

- Recorder MUST enforce a maximum storage budget.
- When space is needed, the oldest sealed segments MUST be deleted. Selection
  SHOULD be based on `t_end_ns` (oldest first) and MAY fall back to `seq_end`
  when timestamps are absent.
- Recorders MUST NOT overwrite sealed segment files in place. Circular behavior
  is implemented by deleting sealed segments and creating new epoch directories.
- SQLite rows for deleted segments MUST be removed in the same transaction that
  records the deletion.
- Active (unsealed) segments MUST NOT be deleted or truncated.

### 9.3 Data Loss Reporting (Optional)

If a segment is missing or truncated (e.g., due to disk full or manual
deletion), recorders SHOULD log a data-loss event and MAY persist it in a table:

```sql
CREATE TABLE data_loss (
  event_id     INTEGER PRIMARY KEY,
  t_ns         INTEGER NOT NULL,
  segment_id   INTEGER,
  stream_id    INTEGER,
  seq_start    INTEGER,
  seq_end      INTEGER,
  path         TEXT,
  reason       TEXT NOT NULL
);
```

### 9.2 Commit Window

- An operator MAY request `commit [t0, t1]`.
- Recorder MUST copy referenced segments into a new dataset root.
- Recorder MUST generate a new SQLite manifest for the committed window.

## 10. Tiered Storage (Optional)

- Tiering is application-managed, not filesystem-managed.
- SQLite MUST track `tier` and the current segment `path`.
- Automatic or manual offload MAY be supported by a background migrator.

## 10.1 Replication (Optional)

Recorders MAY support replication in two complementary modes:

- **Live stream replication (bridge-based)**: use the UDP bridge to forward
  payloads and control/metadata to a remote recorder. The remote recorder
  writes its own segments and manifest. This provides near-real-time replica
  capture at the cost of additional network and CPU load.
- **Sealed-segment replication (archive-style)**: copy sealed segment epoch
  directories and their manifest rows to a replica site. This mode is pull-
  or push-based and minimizes impact on the live recording path but increases
  replication lag (bounded by seal cadence).

Deployments SHOULD document which replication mode is used and whether
replicated datasets are authoritative or best-effort.

## 11. TraceLink Integration

- Recorder MUST persist `FrameDescriptor.trace_id` into `frames.trace_id` when
  present.
- Recorder SHOULD subscribe to TraceLinkSet messages and persist `trace_links`.
- TraceLink ingestion MUST be best-effort and MUST NOT block recording.
- Recorded datasets SHOULD include enough TraceLink data to reconstruct lineage
  across recorded frames (per `docs/SHM_TraceLink_Spec_v1.0.md`).

### 11.1 Metadata Capture

- Recorder SHOULD subscribe to metadata streams and persist DataSourceAnnounce,
  DataSourceMeta, and ShmPoolAnnounce updates alongside the dataset.

## 12. EventMessage Capture (Optional)

The recorder MAY subscribe to a dedicated Aeron stream carrying EventMessage
traffic (SBE-encoded) and persist events alongside frame data so system state
can be reconstructed from the dataset.

- EventMessage capture MUST be best-effort and MUST NOT block recording.
- EventMessages SHOULD be stored as decoded columns plus a raw value blob.
- If `format=REF`, the value MUST be decoded as `(stream_id, epoch, seq)` and
  persisted for joins with recorded frames.
- EventMessages are transported on a separate stream from frame descriptors.
- The EventMessage identity field MAY be `trace_id` or `correlationId`; recorders
  SHOULD persist whichever is present. Channel send/receive timestamps MAY be
  omitted by the event schema.

### 12.3 Control-Plane Integration (Informative)

Shared control/status stream semantics are defined in
`docs/SHM_Service_Control_Plane_Spec_v1.0.md`. Recorders SHOULD subscribe to
the shared status stream and persist accepted events to reconstruct system
state.

### 12.4 Recorder Control API (Informative)

The recorder MAY expose control commands via EventMessage on the shared control
stream. Messages MUST be tagged for the recorder service and use key/value
pairs. Suggested commands:

- `record.enable` (Format=BOOLEAN): enable recording (true) or disable (false).
- `record.stream_id` (Format=UINT32): target stream ID.
- `record.uri` (Format=STRING): optional Aeron URI override for the stream.
- `record.query` (Format=STRING): status request; recorder SHOULD reply on the
  shared status stream with active stream list and dataset root.

The `record.query` response SHOULD include:

- dataset root path
- active stream list
- current segment ID per stream

Commands that are accepted MUST be echoed on the shared status stream per
`docs/SHM_Service_Control_Plane_Spec_v1.0.md`.

EventMessage encoding and field layout MUST follow
`docs/SHM_Service_Control_Plane_Spec_v1.0.md` (tag/key/value with `Format`
selection).

Large control payloads SHOULD be passed by reference using `Format=REF` and the
`refStreamId/refEpoch/refSeq` fields instead of large inline `value` blobs.

### 12.1 EventMessage Table (Informative)

```sql
CREATE TABLE events (
  event_id       INTEGER PRIMARY KEY,
  t_ns           INTEGER NOT NULL,
  trace_id       INTEGER,
  correlation_id INTEGER,
  tag            TEXT,
  format         INTEGER NOT NULL,
  key            TEXT NOT NULL,
  value_bytes    BLOB,
  ref_stream_id  INTEGER,
  ref_epoch      INTEGER,
  ref_seq        INTEGER
);

CREATE INDEX events_time_idx ON events(t_ns);
CREATE INDEX events_trace_idx ON events(trace_id);
```

Recorders MAY omit `trace_id` if the EventMessage schema uses `correlationId`
instead, but SHOULD preserve whichever identity field is present.
`events.t_ns` SHOULD be populated from the EventMessage header timestamp field.

### 12.2 EventMessage Schema (Informative)

The recorder is schema-agnostic and stores EventMessages as raw blobs plus
decoded fields. The authoritative EventMessage schema is defined in
`docs/SHM_Service_Control_Plane_Spec_v1.0.md`; a representative aligned SBE
schema is shown for reference:

```xml
<types>
  <enum name="Format" encodingType="int8">
    <validValue name="NOTHING">0</validValue>
    <validValue name="UINT8">1</validValue>
    <validValue name="INT8">2</validValue>
    <validValue name="UINT16">3</validValue>
    <validValue name="INT16">4</validValue>
    <validValue name="UINT32">5</validValue>
    <validValue name="INT32">6</validValue>
    <validValue name="UINT64">7</validValue>
    <validValue name="INT64">8</validValue>
    <validValue name="FLOAT32">9</validValue>
    <validValue name="FLOAT64">10</validValue>
    <validValue name="BOOLEAN">11</validValue>
    <validValue name="STRING">12</validValue>
    <validValue name="BYTES">13</validValue>
    <validValue name="BIT">14</validValue>
    <validValue name="REF">15</validValue>
  </enum>
</types>

<sbe:message name="EventMessage" id="1">
  <field name="timestampNs" id="1" type="int64"/>
  <field name="correlationId" id="2" type="int64"/>
  <field name="format" id="3" type="Format"/>
  <field name="pad" id="4" type="uint8" length="3"/>
  <field name="refStreamId" id="5" type="uint32" presence="optional" nullValue="4294967295"/>
  <field name="refEpoch" id="6" type="uint64" presence="optional" nullValue="18446744073709551615"/>
  <field name="refSeq" id="7" type="uint64" presence="optional" nullValue="18446744073709551615"/>
  <data  name="tag" id="10" type="varAsciiEncoding"/>
  <data  name="key" id="11" type="varAsciiEncoding"/>
  <data  name="value" id="20" type="varDataEncoding"/>
</sbe:message>
```

## 13. Replay (Optional)

A replay agent MAY read a recorded dataset and re-materialize frames into a
running AeronTensorPool system for testing or regression validation.

- Replay SHOULD publish `FrameDescriptor` messages that match the recorded
  `stream_id`, `epoch`, and `seq`.
- Replay MUST restore payload bytes from segments into SHM pools before
  publishing descriptors.
- Replay MAY pace playback using recorded timestamps (`frames.t_ns`) or run as
  fast as possible.
- Replay SHOULD allow time scaling (e.g., 0.1×, 1×, 5×).
- Replay SHOULD apply a timestamp offset to re-materialized data so replayed
  frames appear as if they were occurring live.
- Replay SHOULD emit metadata events (DataSourceAnnounce, DataSourceMeta, and
  ShmPoolAnnounce) before frame replay to ensure consumers can decode frames.
- Replay MAY remap `stream_id` and Aeron channel/stream destinations via a
  configuration map. Replay SHOULD preserve recorded `epoch` values; if epoch
  remapping is required, it MUST be documented by the deployment.
- Replay SHOULD map the segment region files and publish `FrameDescriptor`
  messages directly from the recorded SHM layout without copying payload bytes.

### 13.1 Replay Slot Mapping (Normative)

When the replay target uses different ring sizes than the recorded segment,
replay MUST rematerialize frames into the target SHM layout using modulo
mapping:

1. Let `seq` be the recorded frame sequence.
2. Compute the recorded slot index `i_rec = seq & (recorded_header_nslots - 1)`.
3. Read the recorded `SlotHeader` at `i_rec` and validate `seq_commit` per the
   wire spec (must equal `seq` and be committed).
4. Choose the target payload pool (e.g., smallest stride that fits the payload).
5. Compute target indices:
   - `i_hdr = seq & (target_header_nslots - 1)`
   - `i_pay = seq & (target_pool_nslots - 1)` for the selected pool
6. Copy payload bytes into the target pool slot `i_pay`.
7. Write a target `SlotHeader` into `i_hdr`, preserving `seq` and rewriting
   `pool_id`/`payload_slot` to match the target mapping.
8. Commit the slot and publish `FrameDescriptor` with the original `seq`.

If the target layout matches the recorded ring sizes, replay MAY map the
recorded segment files and publish `FrameDescriptor` without copying payload
bytes, using `seq` to derive slot indices on the consumer side.

### 13.2 Zero-Copy Replay From Segments (Informative)

When the replay target layout matches the recorded layout, a replay agent MAY
mmap the segment epoch directories and treat them as the SHM regions for a
replay-only producer. In this mode:

- The replay agent MUST publish `ShmPoolAnnounce` that exactly matches the
  recorded superblocks (layout_version, epoch, pool sizes, strides).
- The replay agent MUST publish `FrameDescriptor` with the recorded `seq`; the
  consumer derives slot indices from `seq` and reads directly from the mapped
  segment files.
- The segment files MUST be treated as immutable; replay MUST NOT modify them.

## 14. Segment Lifecycle Commands (Informative)

The recorder MAY expose segment lifecycle operations modeled after Aeron
Archive. These commands apply per `recording_id`:

- `detach_segments(recording_id, new_start_seq)`: advance the dataset start by
  detaching all sealed segments before `new_start_seq`. Detached segments are no
  longer part of the active dataset but may remain on disk.
- `attach_segments(recording_id)`: reattach previously detached segments if they
  are still present on disk.
- `delete_detached_segments(recording_id)`: permanently delete detached segments
  to reclaim storage.

These operations SHOULD NOT apply to segments that are active for recording.

## 15. Derived Products (Informative)

FITS and other products are derived artifacts and SHOULD be generated offline
from the recorded dataset. Headers MAY be assembled from DataSource metadata,
TraceLink lineage, and frame ranges.

## 16. Rationale (Informative)

Segment files + SQLite provide:

- circular overwrite semantics,
- portable datasets,
- resilience to DB failure,
- efficient pixel storage.

The SHM-layout segment format keeps replay simple: consumers and replay agents
use the same modulo indexing rules as live SHM, and large on-disk rings can
extend capture duration without changing the wire protocol. The manifest
provides a compact index and supports offline analytics without scanning raw
segment files.

## 17. Open Questions (Informative)

- Multi-stream co-location vs per-stream datasets.
- Durability semantics on power loss beyond the sealing/checksum model.
- Optional DuckDB read-only views.
- Export tooling and CLI surface.

## 18. Design Notes Borrowed from Aeron Archive (Informative)

- Segmented recording model: fixed-size segments with a catalog/manifest of
  recordings.
- Recording catalog: start/stop positions, timestamps, and stream metadata; maps
  well to the SQLite manifest.
- Replay control: bounded replay (start/stop position or time range), pacing,
  and fast-as-possible mode.
- Checksums on seal: optional integrity checks per segment.
- Control API patterns: explicit start/stop/list/replay operations.
- Segment detach/attach/delete enables efficient retention management without
  rewriting large files.

## 19. Features Borrowed from ArchiverService.jl (Informative)

- EventMessage-driven enable/disable of per-stream recording, with status echo
  for accepted commands.
- Bulk SQLite inserts with a maximum batch size and a commit-delay timeout.
- Periodic WAL checkpoints and file flush cadence to bound data loss windows.
- Segment rollover by size to avoid unbounded raw files.
- Replay with time scaling and timestamp refresh on publish.
- Query helpers for time range and correlation ID range selection.
- Data-loss reporting when indexed payload ranges are missing or truncated.

## 20. Operational Guidance (Informative)

### 20.1 Replay Ordering

Replay SHOULD emit metadata (DataSourceMeta, ShmPoolAnnounce) before the first
frame of each stream, following Aeron Archive’s practice of replaying catalog
and metadata before data payloads.

### 20.2 Control API Responses

For `record.query`, the recorder SHOULD return a structured EventMessage payload
that includes the dataset root, active stream list, and current segment IDs.

### 20.3 Data Loss Reporting

If data loss is detected (missing/truncated segments), recorders SHOULD emit a
data-loss event and persist it. Suggested fields: `segment_id`, `stream_id`,
`seq_start`, `seq_end`, `reason`, and `t_ns`.

### 20.4 Replay Remapping

Replay remapping SHOULD allow `stream_id` and Aeron channel overrides without
altering recorded `epoch`. If epoch remapping is required, the recorder SHOULD
document it explicitly to avoid confusing consumers.

### 20.5 Checksums

Checksum algorithms SHOULD be documented per dataset. CRC32 is recommended as
a fast integrity check (cryptographic hashes are not required); xxHash64 is an
acceptable alternative. Compute checksums on segment seal as in Aeron Archive.

When checksums are enabled:
- The checksum MUST be computed after sealing and fsync over the full bytes of
  each region file in the segment, including superblocks and unused slot space.
- The checksum input MUST be deterministic; the default is the concatenation
  of `header.ring` followed by payload pool files in ascending `pool_id` order.
- The recorder MUST store the checksum bytes in `segments.checksum` and set
  `segments.checksum_alg` to the algorithm identifier.
- Readers SHOULD verify checksums before replay or export; failed verification
  SHOULD be treated as data loss for that segment.
