# Aeron Tensor Pool Implementation Guide (Julia, v1.1)

This guide maps the wire spec to concrete implementation steps in Julia using Aeron.jl, SBE.jl, and Agent.jl. It stays implementation-oriented and references the spec for normative rules.

For a combined wire + driver overview, see `docs/IMPLEMENTATION_GUIDE.md`.

## 1. Dependencies
- Aeron driver/runtime: align with Aeron.jl supported version.
- Julia packages: Aeron.jl, SBE.jl, Agent.jl, Mmap stdlib.
- SBE.jl alone can generate codecs from the schema in SHM_Tensor_Pool_Wire_Spec_v1.1.md §16 (see sbe-schema.xml); no external sbe-tool needed.

## 2. Code Generation (SBE)
- Source schema: SHM_Tensor_Pool_Wire_Spec_v1.1.md §16 (also extracted to sbe-schema.xml). MAX_DIMS is 8; if you change it, update the schema and regenerate.
- Generate control-plane codecs and SHM composites (TensorSlotHeader256, ShmRegionSuperblock) directly with SBE.jl (no java tool required).
- Enums use SBE numeric bodies (see Spiders schema style); if you edit enum values, keep the body text numeric and regenerate.
- Julia codegen example (adjust paths):
  - Inline load: `modname = @load_schema "sbe-schema.xml"` then `using .` to access types; suitable for tooling/tests.
  - File generation: `SBE.generate("sbe-schema.xml", "gen/TensorPool.jl")`; then `include("gen/TensorPool.jl"); using .TensorPool`.
- Regenerate codecs whenever the schema or layout_version changes.

## 2a. Source Layout (Aeron-style, Julian)
- `src/core`: shared constants and error types.
- `src/shm`: shared-memory helpers (canonical paths, mmap, superblocks, headers).
- `src/aeron`: Aeron helpers (try_claim, fragment assemblers, counters).
- `src/timers`: polled timers and timer sets.
- `src/config`: TOML/env config loading and path resolution.
- `src/agents/<role>`: role implementation split into `state.jl`, `handlers.jl`, and `logic.jl`.
- `src/agent_glue`: Agent.jl integration for each role.

## 3. Shared Constants (must match spec)
- superblock_size = 64
- header_slot_bytes = 256
- magic = TPOLSHM1 (0x544F504C53484D31 LE)
- endianness = little-endian only
- slot mapping v1.1: payload_slot = header_index; pool nslots == header nslots

## 4. Producer Flow (spec §15.19)
1) header_index = seq & (nslots - 1)
2) commit_word = (frame_id << 1) | 1 (store release/relaxed)
3) Fill payload bytes; ensure visibility (flush DMA if needed)
4) Fill header (frame_id=seq, shape/strides, pool/slot, meta_version, etc.)
5) commit_word = (frame_id << 1) (store release)
6) Publish FrameDescriptor; optional FrameProgress COMPLETE

## 5. Consumer Flow (spec §15.19)
1) Validate epoch from FrameDescriptor; compute header_index
2) Read commit_word (acquire); if odd → DROP
3) Read header + payload
4) Re-read commit_word (acquire); if changed/odd → DROP
5) Accept only if commit_word stable/even AND header.frame_id == FrameDescriptor.seq
6) Track drops_gap (seq gaps) and drops_late (seqlock/identity failures)

## 6. Epoch and Mapping (spec §15.21)
- States: UNMAPPED → MAPPED(epoch). Remap on epoch change or validation failure; drop in-flight frames.
- On producer restart/layout change: bump epoch; reset seq/frame_id to 0; republish announce.

## 6a. Filesystem layout and path containment (spec §15.21a)
- Producers MUST announce explicit absolute paths for all SHM regions; do not derive/synthesize paths on the consumer side.
- Consumers MUST NOT scan directories or infer filenames; use only the announced paths.
- Implementations SHOULD expose `shm_base_dir` and MAY expose `allowed_base_dirs` for path containment checks.
- Path containment procedure before mmap:
  1) Ensure the announced path is absolute.
  2) Canonicalize the announced path (realpath).
  3) Canonicalize each configured allowed_base_dir once at startup; use only canonical forms.
  4) Verify the canonical announced path is contained within one of the canonical allowed_base_dirs.
  5) Perform a filesystem metadata check: reject unless the path is a regular file (hugetlbfs regular files allowed); reject block/char devices, FIFOs, and sockets.
  6) On any failure, reject and do not map; optionally fall back to payload_fallback_uri.
- Recommended layout (informative):
  - `<shm_base_dir>/<namespace>/<producer_instance_id>/epoch-<E>/`
  - `header.ring` and `payload-<pool_id>.pool` within the epoch directory.
- Permissions (informative):
  - Private: directories `0700`, files `0600`.
  - Shared-group: directories `2770` (setgid), files `0660`.

## 7. Backend Validation (spec §15.22)
- URI scheme: only shm:file; reject unknown parameters. Separator is '|'.
- Hugepages: if require_hugepages=true, verify hugepage-backed mapping; reject if not.
- stride_bytes: power-of-two; multiple of page size; if hugepages required, also multiple of hugepage size.
- Reject on any validation failure; optionally use payload_fallback_uri.

## 8. Progress Reporting
- Emit FrameProgress only if any subscriber supports_progress=true.
- Defaults: interval 250 µs, bytes delta 64 KiB, rows delta unset.
- FrameProgress is advisory; FrameDescriptor remains canonical availability signal.

## 9. QoS and Metrics
- drops_gap: sequence gaps detected from FrameDescriptor.
- drops_late: seqlock/identity failures (commit_word instability or frame_id != seq).
- Supervisor aggregates QosProducer/QosConsumer for liveness and throttling decisions.

## 10. Operational Defaults
- Announce cadence: 1 Hz; liveness timeout: 3–5× cadence.
- nslots sizing: rate × worst-case consumer latency × safety factor (2–4).
- Stride classes: per deployment (e.g., 1 MiB, 4 MiB, 16 MiB on hugepages).
- NUMA: pin agents and place SHM on producing node.

## 11. Testing Checklist (spec §15.13)
- Superblock/URI validation fails closed (magic/layout/version/endianness; scheme/hugepage/stride rules).
- Seqlock prevents torn reads; commit_word monotonic; drop if regress or identity mismatch.
- Epoch change triggers remap; in-flight frames dropped; header_index reuse guarded by frame_id==seq.
- Progress gating respected; no progress when no subscriber supports it.
- Fallback path works when SHM invalid/unsupported.

## 12. Role Notes
- Producer: single writer of header/payload regions; refresh activity_timestamp_ns at announce cadence.
- Consumer: must not spin-wait for commit; on any failure, drop and continue.
- Supervisor: detect stale activity_timestamp_ns or missing announces; issue ConsumerConfig; arbitrate consumer IDs.
- Bridge (optional): validate before republishing; preserve seq/frame_id; maintain its own epoch/layout in announces.
- Decimator/Tap (optional): consumes STREAM, republishes LATEST/DECIMATED; may suppress progress for dropped frames.

## 13. Julia fast path guidance
- Keep hot paths allocation-free and type-stable: preallocate buffers for decoded headers and reuse; avoid VarData/VarAscii decoding in the frame loop.
- Use concrete structs for TensorSlotHeader256/Superblock views; avoid Any/Union in critical paths.
- Ensure commit_word loads/stores use acquire/release semantics; prefer `Base.llvmcall`/atomic wrappers only if needed—otherwise rely on SBE.jl’s generated accessors when they are type-stable.
- For progress/descriptor handling, stage work in small immutable structs to keep inference intact; avoid closures/allocating iterators in the poll loop.
- Pin frequently accessed buffers and avoid String allocations for URIs in the hot path; parse URIs once at startup.

## 14. Codegen and build tasks
- Set MAX_DIMS in schemas/sbe-schema.xml (DimsArray/StridesArray length) before codegen; bump layout_version when changing it.
- Generate codecs: `julia --project -e 'using SBE; SBE.generate("schemas/sbe-schema.xml", "gen/TensorPool.jl")'`.
- Keep generated codec at gen/TensorPool.jl; include it from src as needed.
- Optional VS Code task/make target: regenerate codec, then `julia --project -e 'using Pkg; Pkg.test()'` or run agents.
- Tooling: `scripts/run_tests.sh` wraps the full test run for CI/local workflows.
- Control CLI: `scripts/tp_tool.jl send-consumer-config` can push ConsumerConfig on the control stream.
- Role runner: `scripts/run_role.jl <producer|consumer|supervisor> [config]` starts a single agent with polling loop.
- Multi-role runner: `scripts/run_all.sh <config>` launches producer/consumer/supervisor in one shell with a shared config.
- System smoke test: `scripts/run_system_smoke.jl [config] [timeout_s]` runs a full in-process system using an embedded media driver.
- Optional CI/system test: `TP_RUN_SYSTEM_SMOKE=true julia --project -e 'using Pkg; Pkg.test()'` runs the end-to-end smoke test.
- Optional GC monitor: `TP_RUN_SYSTEM_SMOKE_GC=true TP_GC_MONITOR_ITERS=2000 TP_GC_ALLOC_LIMIT_BYTES=50000000 julia --project -e 'using Pkg; Pkg.test()'` runs the E2E loop and asserts GC allocation growth stays below the limit.

## 15. Configuration pattern (TOML + env overrides)
- Keep a default TOML (e.g., config/defaults.toml) with uri, nslots, stride_bytes, cadences, progress defaults, payload_fallback_uri, and Aeron directory when needed.
- Allow env overrides for deployment specifics: AERON_URI (default `aeron:ipc`), AERON_DIR (default `/dev/shm/aeron-${USER}`), TP_HUGEPAGE_MOUNT, TP_SHM_URI, TP_STREAM_ID, TP_PROGRESS_INTERVAL_US, JULIA_PROJECT.
- Example (TOML):

```toml
[producer]
uri = "shm:file?path=/dev/hugepages/tensorpool/example-producer/epoch-1/payload-1.pool|require_hugepages=true"
nslots = 1024
stride_bytes = 1048576
announce_hz = 1.0
progress_interval_us = 250
progress_bytes_delta = 65536
payload_fallback_uri = ""

[consumer]
mode = "STREAM"
max_rate_hz = 0
expected_layout_version = 1
supports_progress = true

[supervisor]
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
metadata_stream_id = 1300
aeron_dir = "/dev/shm/aeron-${USER}"
```

## 16. Runtime wiring
- Aeron channels: default to ipc for control/descriptor/QoS/metadata; pick stream IDs as in the config example.
- Prefer keeping control/descriptor/QoS/metadata on distinct stream IDs to avoid head-of-line blocking; multiplexing them on one stream is acceptable for low-rate control paths if receivers still demux by message type.
- One Aeron URI is enough for these control-plane streams; keep separate URIs only when media params differ (e.g., smaller term-length for control vs larger for descriptors, or different endpoints/linger).
- Agents in play:
  - Producer agent: publishes ShmPoolAnnounce, FrameDescriptor, optional FrameProgress.
  - Consumer agent(s): subscribe to descriptors/progress, mmap SHM, apply mode (STREAM/LATEST/DECIMATED).
  - Supervisor agent: receives announces, issues ConsumerConfig, aggregates QoS, liveness checks.
  - Optional bridge/decimator/tap: republish or downsample while preserving seq/frame_id semantics.

## 17. Operational playbook
- See `docs/OPERATIONAL_PLAYBOOK.md` for startup order, tuning guidance, and failure playbooks.

## 18. Integration examples
- See `docs/INTEGRATION_EXAMPLES.md` for BGAPI2 buffer registration and invoker-mode integration.

## 19. Documentation pipeline
- Plan: add docstrings to all public API functions and generate a Documenter.jl site that references the spec and these examples.

## 20. Benchmarking
- Microbenchmarks: `julia --project scripts/run_benchmarks.jl`.
- System benchmark: `julia --project scripts/run_benchmarks.jl --system --duration 5 --config config/defaults.toml`.
- Results should include publish/consume rates and allocation behavior under load.
- Map config → SBE messages: producer fills ShmPoolAnnounce from TOML/env (uris, nslots, stride_bytes, max_dims); supervisor sends ConsumerConfig based on consumer mode/bridge decisions.
- Consumers refuse SHM if announce values differ from compiled schema (max_dims/layout_version) or backend validation fails.

## 16a. Agent execution model (AgentRunner vs Invoker)
- Default: use an AgentRunner-style loop that owns the agent task and calls `*_do_work!` with a single `now_ns` per duty cycle.
- Invoker mode: allow embedding in another task or event loop by calling `producer_do_work!`, `consumer_do_work!`, or `supervisor_do_work!` directly; the caller is responsible for cadence, backoff, and lifecycle.
- Decision: keep both options available; choose AgentRunner when agents are standalone processes, use invoker mode when integrating into a larger application.

## 16b. Agent roles and supervisor requirement
- Typical deployment runs three agents: producer, consumer, supervisor.
- Invoker mode lets you run one or more agents inside an application loop without AgentRunner; you call `*_do_work!` each duty cycle with a consistent `now_ns`.
- The supervisor is optional for basic producer/consumer operation (announce + descriptors + QoS can flow without it), but required for dynamic policy (ConsumerConfig), liveness aggregation, and multi-consumer coordination.

## 16c. Config notes (IDs, SHM, and MAX_DIMS)
- `producer_id`: configured per stream; spec recommends a supervisor/authority assign it, otherwise choose a stable app-specific ID.
- `consumer_id`: recommended to be assigned by a supervisor/authority; if self-assigned, spec suggests randomized IDs and collision handling (see §10.1.2).
- `pool_id`: chosen by the producer and advertised in ShmPoolAnnounce; use a simple sequential scheme (1..N) unless you need a stable external mapping.
- `nslots`: capacity for ring and pools; size it to cover producer rate × worst-case consumer latency × safety factor.
- `max_dims`: fixed by the SBE schema and must match on producer/consumer; it is not runtime-configurable without regenerating codecs.
- `use_shm`: ConsumerConfig lever to force a consumer to use SHM or fallback (see §10.1.3).
- `supports_shm`: ConsumerHello capability flag for non-SHM consumers (e.g., remote/bridged); see §10.1.2 in the spec.
- `aeron_dir`: optional; when empty, the default Aeron directory is used. TOML supports `$USER` or `${USER}` via env expansion.
- Counter IDs: Aeron counters encode agent_id in 16 bits; keep `producer_id`/`consumer_id`/`stream_id` ≤ 65535 when enabling counters.

## 17. Validation, logging, and errors
- Backend checks before mmap: scheme==shm:file, require_hugepages honored, stride_bytes power-of-two and page/hugepage aligned; log and reject before mapping.
- On epoch mismatch or commit_word regression: drop frame, increment drops_late, log at debug/info.
- On invalid superblock or failed mmap: log error, attempt fallback_uri if configured; otherwise fail the data source.
- Log drops_gap/drops_late counts, remap events, progress throttling decisions; export counters (e.g., Prometheus) per stream.
- Error taxonomy: SHM parsing/validation throws `ShmUriError` or `ShmValidationError` when used in strict contexts; most data-plane errors are handled by drops and counters rather than exceptions.

## 18. Progress policy
- Consumer hints: take smallest interval/deltas above producer floors; if none provided, use defaults (250 us, 64 KiB, rows unset).
- Disable progress by either: no consumer supports_progress, producer config flag off, or interval/deltas set to very large values.
- Never treat FrameProgress COMPLETE as commit; commit_word remains canonical.

## 19. QoS reporting
- Cadence: ~1 Hz for QosProducer and QosConsumer.
- QosProducer: stream_id, producer_id, epoch, current_seq, optional watermark.
- QosConsumer: stream_id, consumer_id, epoch, last_seq_seen, drops_gap, drops_late, mode.
- Consider alerting when drops_gap or drops_late exceed thresholds or when last_seq_seen lags current_seq beyond buffer depth.

## 20. Deployment checklist
- Hugepages: ensure mount exists and matches stride alignment; verify require_hugepages when set.
- Permissions: create SHM files with restrictive umask/mode; keep owner/group to service user.
- NUMA: place SHM on producer node; pin agents on same node.
- Liveness: set announce cadence ~1 Hz; timeout 3–5x cadence; refresh activity_timestamp_ns accordingly.
- Cleanup: on clean shutdown optionally unlink SHM; on crash rely on epoch bump and new superblocks.

## 20a. Perf and ops hardening
- CPU pinning: pin producer/consumer/supervisor to dedicated cores (e.g., `taskset` or cgroup cpusets).
- NUMA: place SHM on the producer node and co-locate the producer agent on the same NUMA node.
- GC: consider a longer GC interval for long-running processes; keep hot paths allocation-free.
- Aeron counters: optionally wire Aeron counters for publications/subscriptions to a metrics backend.
- Performance counters: agent wrappers register Aeron counters for duty cycles, work done, frames published, announces, QoS publishes, drops (gap/late + seqlock causes), and remaps; use AeronStat or CountersReader to observe.

## 20b. Hugepages (hugetlbfs) setup
- Hugepages are only used when SHM URIs include `require_hugepages=true` or consumer config requires it.
- Use a hugetlbfs mount and point SHM URIs at that path, e.g. `/dev/hugepages`.
- Example commands (run as root):
  - `sudo sysctl -w vm.nr_hugepages=1024`
  - `sudo mkdir -p /dev/hugepages`
  - `sudo mount -t hugetlbfs nodev /dev/hugepages`
- Verify: `grep Huge /proc/meminfo` or `mount | grep hugetlbfs`.
- Ensure `stride_bytes` is a multiple of the hugepage size when `require_hugepages=true` (consumer will reject otherwise).
- When hugepages are not available, either remove `require_hugepages=true` or set a fallback URI for the consumer.

## 21. Testing matrix (tie to §15.13)
- Superblock validation: good vs bad magic/version/layout/endianness.
- Backend validation: reject bad scheme, bad stride alignment, missing hugepages when required.
- Seqlock under overwrite: consumer detects commit_word instability and drops_late increments.
- Epoch remap: producer bumps epoch; consumers drop in-flight, unmap, remap.
- Fallback path: invalid SHM triggers fallback_uri usage.
- Progress off/on: verify gating and throttling; COMPLETE does not bypass commit_word.

## 22. Bridge/decimator specifics
- Bridge republishes with its own epoch/layout in announces; preserves seq/frame_id from source descriptors.
- Decimator/Tap may suppress progress for dropped frames; must keep seq/frame_id identity and follow same commit_word rules on republished descriptors.

## 23. Device DMA integration (zero-copy)
- Use the producer to allocate payload pools, then register each payload slot with your device SDK for DMA writes.
- Map the next header index to a payload slot (v1.1 uses slot == header_index), and hand the slot pointer to the device.
- Once the device fills the buffer, call `publish_frame_from_slot!` to emit the descriptor without copying.

Example (DMA buffer registration):

```julia
header_index = next_header_index(state)
pool_id = UInt16(1)
slot = header_index
ptr, stride = payload_slot_ptr(state, pool_id, slot)
# Pass (ptr, stride) to device SDK for DMA
```

Example (publish after DMA completion):

```julia
publish_frame_from_slot!(
    state,
    pool_id,
    slot,
    values_len,
    shape,
    strides,
    Dtype.UINT8,
    meta_version,
)
```

## 24. Project Review
- Review answers and follow-on phases are tracked in `docs/PROJECT_REVIEW.md`.

Reservation helper for multiple in-flight buffers:

```julia
reservation = reserve_slot!(state, pool_id)
# Pass reservation.ptr + reservation.stride_bytes to the device SDK.

publish_reservation!(
    state,
    reservation,
    values_len,
    shape,
    strides,
    Dtype.UINT8,
    meta_version,
)
```
