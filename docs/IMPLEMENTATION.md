# Aeron Tensor Pool Implementation Guide (Julia, v1.2)

This guide maps the wire spec to concrete implementation steps in Julia using Aeron.jl, SBE.jl, and Agent.jl. It stays implementation-oriented and references the spec for normative rules.

Note: Initial driver and client implementations are in Julia. The wire/driver specs are language-neutral and should remain implementable across languages.

For a combined wire + driver overview, see `docs/USER_GUIDE.md`.

## 1. Dependencies
- Aeron driver/runtime: align with Aeron.jl supported version.
- Julia packages: Aeron.jl, SBE.jl, Agent.jl, Mmap stdlib.
- SBE.jl alone can generate codecs from the schema in SHM_Tensor_Pool_Wire_Spec_v1.2.md §16 (see wire-schema.xml); no external sbe-tool needed.

## 2. Code Generation (SBE)
- Source schema: SHM_Tensor_Pool_Wire_Spec_v1.2.md §16 (also extracted to wire-schema.xml). MAX_DIMS is 8; if you change it, update the schema and regenerate.
- Generate control-plane codecs and SHM composites (SlotHeader, TensorHeader, ShmRegionSuperblock) directly with SBE.jl (no java tool required).
- Enums use SBE numeric bodies (see Spiders schema style); if you edit enum values, keep the body text numeric and regenerate.
- Julia codegen example (adjust paths):
  - Inline load: `modname = @load_schema "wire-schema.xml"` then `using .` to access types; suitable for tooling/tests.
  - File generation: `SBE.generate("wire-schema.xml", "gen/TensorPool.jl")`; then `include("gen/TensorPool.jl"); using .TensorPool`.
- Regenerate codecs whenever the schema or layout_version changes.
 - After spec/schema edits, run `julia --project -e 'using Pkg; Pkg.build(\"AeronTensorPool\")'` to keep generated codecs in sync.

## 2b. Decoder Guards and Schema Mixing
- Control/QoS/metadata channels may carry mixed message families. Always check `MessageHeader.schemaId` (or `DriverMessageHeader.schemaId`) before decoding.
- Treat schema mismatches as non-fatal: ignore the fragment rather than throwing in hot paths.

## 2a. Source Layout (Aeron-style, Julian)
- `src/core`: shared constants and error types.
- `src/shm`: shared-memory helpers (canonical paths, mmap, superblocks, headers).
- `src/aeron`: Aeron helpers (try_claim, fragment assemblers, counters).
- `src/timers`: polled timers and timer sets.
- `src/config`: driver TOML/env config loading plus API defaults and path resolution.
- `src/agents/<role>`: role implementation split into `state.jl`, `mapping.jl`, `frames.jl`, `proxy.jl`, `handlers.jl`, and orchestration glue. Bridge adds `assembly.jl` and `adapters.jl`.
- `src/agents`: Agent.jl integration for each role.

## 3. Shared Constants (must match spec)
- superblock_size = 64
- header_slot_bytes = 256 (fixed by the wire spec; not configurable)
- magic = TPOLSHM1 (0x544F504C53484D31 LE)
- endianness = little-endian only
- slot mapping v1.2: payload_slot = header_index; pool nslots == header nslots
- driver prefault/zero on create: configurable via `policies.prefault_shm` (default: true)
- driver mlock on create: configurable via `policies.mlock_shm` (default: false; fatal if enabled and mlock fails)
- epoch GC: configurable via `policies.epoch_gc_enabled` / `policies.epoch_gc_keep` / `policies.epoch_gc_min_age_ns`; only delete epochs whose superblock `activity_timestamp_ns` is stale and whose producer PID is no longer alive
- client mlock: when enabled, each producer/consumer process SHOULD mlock its own SHM mappings (mlock is per-process)
- Stream IDs: follow `docs/STREAM_ID_CONVENTIONS.md` (informative defaults).

## 4. Producer Flow (spec §15.19)
1) header_index = seq & (nslots - 1)
2) seq_commit = (seq << 1) (store release)
3) Fill payload bytes; ensure visibility (flush DMA if needed)
4) Fill header (shape/strides, pool/slot, meta_version, etc.)
5) seq_commit = (seq << 1) | 1 (store release)
6) Publish FrameDescriptor; optional FrameProgress COMPLETE

Implementation notes:
- Aeron `try_claim`/`offer` returns NOT_CONNECTED when no subscribers are present; this is an expected transient state as consumers come and go. Producers MUST treat it as a retryable condition, not a fatal error.
- `publication_is_connected`/`channel_status` are observability hints only; do not gate correctness on them.
- Debug logging: `@tp_debug` uses `Base.@debug`, so set `JULIA_DEBUG=all` (or a narrower module filter) when you want debug-level output.

## 5. Consumer Flow (spec §15.19)
1) Validate epoch from FrameDescriptor; compute header_index
2) Read seq_commit (acquire); if LSB=0 → DROP
3) Read header + payload; validate SlotHeader.headerBytes length and embedded TensorHeader message header (templateId/schemaId/blockLength/version)
4) Re-read seq_commit (acquire); if changed/LSB=0 → DROP
5) Accept only if seq_commit stable/LSB=1 AND (seq_commit >> 1) == FrameDescriptor.seq
6) Track drops_gap (seq gaps) and drops_late (seqlock/identity failures)

Implementation notes:
- `values_len_bytes` may be zero; consumers MUST accept empty payloads and return an empty payload view.

## 6. Epoch and Mapping (spec §15.21)
- States: UNMAPPED → MAPPED(epoch). Remap on epoch change or validation failure; drop in-flight frames.
- On producer restart/layout change: bump epoch; reset seq to 0; republish announce.

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
  - `<shm_base_dir>/tensorpool-${USER}/<namespace>/<stream_id>/<epoch>/`
  - `header.ring` and `<pool_id>.pool` within the epoch directory.
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
- Consumers MUST validate FrameProgress against the current slot header: header_index range, seq/commit match, embedded headerBytes validity, and `payload_bytes_filled` ≤ `values_len_bytes`; progress MUST be monotonic per header_index.

## 9. QoS and Metrics
- drops_gap: sequence gaps detected from FrameDescriptor.
- drops_late: seqlock/identity failures (seq_commit instability or seq mismatch).
- Supervisor aggregates QosProducer/QosConsumer for liveness and throttling decisions.

## 9a. Discovery Service (v1.0)
- Discovery responses are advisory; clients MUST attach via the driver and validate epochs/layout.
- Embedded provider: `DiscoveryAgent` subscribes to `ShmPoolAnnounce` + metadata, serves requests on a discovery request channel.
- Registry mode: `DiscoveryRegistryAgent` aggregates multiple driver endpoints and serves the same request API.
- Cross-spec gating: discovery results and announces MUST be ignored unless their schema id/version matches the expected wire spec.

### 9a.1 Embedded Provider Config (example)
```toml
[discovery]
channel = "aeron:ipc?term-length=4m"
stream_id = 7000
announce_channel = "aeron:ipc?term-length=4m"
announce_stream_id = 7001
metadata_channel = "aeron:ipc?term-length=4m"
metadata_stream_id = 7002
driver_instance_id = "driver-1"
driver_control_channel = "aeron:ipc?term-length=4m"
driver_control_stream_id = 7003
max_results = 1000
expiry_ns = 3_000_000_000
response_buf_bytes = 65536
```

### 9a.2 Registry Config (example)
```toml
[discovery_registry]
channel = "aeron:udp?endpoint=localhost:9010"
stream_id = 7100
max_results = 1000
expiry_ns = 3_000_000_000
response_buf_bytes = 65536

[[discovery_registry.endpoints]]
driver_instance_id = "driver-1"
announce_channel = "aeron:udp?endpoint=localhost:9020"
announce_stream_id = 7101
metadata_channel = "aeron:udp?endpoint=localhost:9021"
metadata_stream_id = 7102
driver_control_channel = "aeron:udp?endpoint=localhost:9022"
driver_control_stream_id = 7103
```

### 9a.3 Client Usage (example)
```julia
client_state = init_discovery_client(
    client,
    "aeron:ipc?term-length=4m", 7000,       # request channel/stream
    "aeron:ipc?term-length=4m", UInt32(7004), # response channel/stream
    UInt32(42),              # client_id
)

results = Vector{DiscoveryEntry}()
request_id = discover_streams!(client_state, results; data_source_name = "camera-1")

slot = nothing
while slot === nothing
    slot = poll_discovery_response!(client_state, request_id)
    yield()
end

if slot.status == DiscoveryStatus.OK
    for entry in slot.out_entries
        @info "discovered stream" stream_id = entry.stream_id driver = view(entry.driver_instance_id)
    end
end
```

## 10a. Driver Control Plane
- Attach retries SHOULD use a backoff (exponential or capped linear). Avoid tight loops; reattach should be timer-driven.
- Attach validation MUST reject missing or null fields (lease_id/stream_id/epoch/layout_version/header_nslots/header_slot_bytes/max_dims) and invalid publish_mode values.

## 10. Operational Defaults
- Announce cadence: 1 Hz; liveness timeout: 3–5× cadence.
- nslots sizing: rate × worst-case consumer latency × safety factor (2–4).
- Stride classes: per deployment (e.g., 1 MiB, 4 MiB, 16 MiB on hugepages).
- NUMA: pin agents and place SHM on producing node.

## 11. Testing Checklist (spec §15.13)
- Superblock/URI validation fails closed (magic/layout/version/endianness; scheme/hugepage/stride rules).
- Seqlock prevents torn reads; seq_commit monotonic; drop if regress or identity mismatch.
- Epoch change triggers remap; in-flight frames dropped; header_index reuse guarded by seq_commit match.
- Progress gating respected; no progress when no subscriber supports it.
- Fallback path works when SHM invalid/unsupported.

### Phase 0 Allocation Baseline (2026-01-02)

- Full test suite: `julia --project=. -e 'using Pkg; Pkg.test()'`
- Allocation checks (all passing):
  - `Allocation checks`
  - `Allocation load checks`
  - `Allocation checks: seqlock helpers`
  - `Allocation checks: SHM URI parsing`
  - `Allocation checks: driver control-plane encoders`
  - `Allocation checks: producer/consumer loop`
- API export inventory: `docs/API_EXPORTS.md`

## 12. Role Notes
- Producer: single writer of header/payload regions; refresh activity_timestamp_ns at announce cadence.
- Consumer: must not spin-wait for commit; on any failure, drop and continue.
- Supervisor: detect stale activity_timestamp_ns or missing announces; issue ConsumerConfig; arbitrate consumer IDs.
- Bridge (optional): validate before republishing; preserve seq; maintain its own epoch/layout in announces.
- RateLimiter/Tap (optional): consumes STREAM, republishes RATE_LIMITED; may suppress progress for dropped frames.

## 13. Julia fast path guidance
- Keep hot paths allocation-free and type-stable: preallocate buffers for decoded headers and reuse; avoid VarData/VarAscii decoding in the frame loop.
- Use concrete structs for SlotHeader/TensorHeader/Superblock views; avoid Any/Union in critical paths.
- Ensure seq_commit loads/stores use acquire/release semantics; prefer `Base.llvmcall`/atomic wrappers only if needed—otherwise rely on SBE.jl’s generated accessors when they are type-stable.
- For progress/descriptor handling, stage work in small immutable structs to keep inference intact; avoid closures/allocating iterators in the poll loop.
- Pin frequently accessed buffers and avoid String allocations for URIs in the hot path; parse URIs once at startup.

## 13a. API stability and string lifetimes

- Public APIs return owned `String` values unless explicitly documented as view types.
- Driver response poller stores fixed-size string buffers; use `view(fs)` for zero-copy access or `String(fs)` when an owned `String` is required.
- Internal audit and call sites are tracked in `docs/API_STRINGREF_AUDIT.md`.

### String handling guidelines
- `StringView` is acceptable for ephemeral parsing inside a single poll cycle (e.g., decoding a control message and acting immediately).
- Use `FixedString` for control-plane responses that must be retained across polls without allocation.
- Use `String` for long-lived configuration and state (e.g., config structs, cached URIs).
- Avoid storing `StringView` in state structs or returning it from public APIs unless explicitly documented.

### Client API conventions
- Use Aeron-style proxies and pollers: `AttachRequestProxy`, `KeepaliveProxy`, `DetachRequestProxy`, and `DriverResponsePoller`.
- Prefer `DriverClientState` + `driver_client_do_work!` for control-plane orchestration; avoid exposing internal buffers to callers.
- Pollers are advanced APIs; higher-level init functions (`init_driver_client`, `init_producer`, `init_consumer`, `init_supervisor`) are the recommended entry points.

### Config scope (public vs internal)
- Public configs: `DriverConfig`, `ProducerConfig`, `ConsumerConfig`, `SupervisorConfig`, `BridgeConfig`.
- Internal helper configs and runtime structs should not be required for typical usage; keep them in module scope but document if exposed.

## 14. Codegen and build tasks
- Set MAX_DIMS in schemas/wire-schema.xml (DimsArray/StridesArray length) before codegen; bump layout_version when changing it.
- Generate codecs: `julia --project -e 'using Pkg; Pkg.build("AeronTensorPool")'`.
- Generated codecs live in `src/gen` and are ignored by git; run build after schema updates.
- Tooling: `scripts/run_tests.sh` wraps the full test run for CI/local workflows.
- Control CLI: `scripts/tp_tool.jl send-consumer-config` can push ConsumerConfig on the control stream.
- Driver CLI: `scripts/tp_tool.jl driver-attach|driver-keepalive|driver-detach` exercise the driver control plane.
- Notes: use `scripts/example_driver.jl`, `scripts/example_producer.jl`, and `scripts/example_consumer.jl` for simple end-to-end runs.
- System smoke test: `scripts/run_system_smoke.jl [config] [timeout_s]` runs a full in-process system using an embedded media driver.
- Driver smoke test: `scripts/run_driver_smoke.jl` runs an embedded media driver plus the SHM driver and exercises attach/keepalive/detach via the CLI.
- Optional CI/system test: `TP_RUN_SYSTEM_SMOKE=true julia --project -e 'using Pkg; Pkg.test()'` runs the end-to-end smoke test.
- Optional GC monitor: `TP_RUN_SYSTEM_SMOKE_GC=true TP_GC_MONITOR_ITERS=2000 TP_GC_ALLOC_LIMIT_BYTES=50000000 julia --project -e 'using Pkg; Pkg.test()'` runs the E2E loop and asserts GC allocation growth stays below the limit.

## 15. Configuration pattern (driver-first)
- Driver config is defined in the driver spec (TOML surface in Driver Spec §16) and owns SHM layout and policy. Use profiles and stream assignments to define pools and slot counts, and let the driver create regions on demand via `publishMode=EXISTING_OR_CREATE`.
- Driver MAY also accept environment overrides per the driver spec (uppercase keys, dots replaced by underscores).
- Clients do not use TOML or environment variables; they connect via API parameters supplied by the hosting application (Aeron dir/URI, control stream ID, client_id/role, keepalive cadence).
- Client API should mirror Aeron/Aeron Archive patterns (proxy/adapter style) for attach/keepalive/detach.
  - Suggested types (task-based): `AttachRequestProxy`, `KeepaliveProxy`, `DetachRequestProxy`, `DriverResponseAdapter`.
- Client responses should be polled (Aeron-style), not callback-based.
- Producers/consumers MUST treat SHM URIs, layout_version, nslots, and pool definitions as authoritative from the driver.
- Example (driver TOML; see Driver Spec §16 and `config/driver_camera_example.toml`):

```toml
[driver]
instance_id = "driver-01"
control_channel = "aeron:ipc?term-length=4m"
control_stream_id = 1000
announce_channel = "aeron:ipc?term-length=4m"
announce_stream_id = 1001
qos_channel = "aeron:ipc?term-length=4m"
qos_stream_id = 1200

[shm]
base_dir = "/dev/shm/tensorpool"
require_hugepages = false
page_size_bytes = 4096
permissions_mode = "660"

[policies]
allow_dynamic_streams = true
default_profile = "raw_profile"
announce_period_ms = 1000
lease_keepalive_interval_ms = 1000
lease_expiry_grace_intervals = 3

[profiles.raw_profile]
header_nslots = 1024

[[profiles.raw_profile.payload_pools]]
pool_id = 1
stride_bytes = 1048576

[streams.cam1]
stream_id = 10000
profile = "raw_profile"

```

## 16. Runtime wiring
- Aeron channels: default to ipc for control/descriptor/QoS/metadata; pick stream IDs as in the config example.
- Prefer keeping control/descriptor/QoS/metadata on distinct stream IDs to avoid head-of-line blocking; multiplexing them on one stream is acceptable for low-rate control paths if receivers still demux by message type.
- One Aeron URI is enough for these control-plane streams; keep separate URIs only when media params differ (e.g., smaller term-length for control vs larger for descriptors, or different endpoints/linger).
- Agents in play:
  - Producer agent: publishes ShmPoolAnnounce, FrameDescriptor, optional FrameProgress.
  - Consumer agent(s): subscribe to descriptors/progress, mmap SHM, apply mode (STREAM/RATE_LIMITED).
  - Supervisor agent: receives announces, issues ConsumerConfig, aggregates QoS, liveness checks.
  - Optional bridge/rate limiter/tap: republish or downsample while preserving seq semantics.

## 17. Operational playbook
- See `docs/OPERATIONAL_PLAYBOOK.md` for startup order, tuning guidance, and failure playbooks.

## 18. Integration examples
- See `docs/USER_GUIDE.md` for BGAPI2 buffer registration and invoker-mode integration.

## 19. Documentation pipeline
- Plan: add docstrings to all public API functions and generate a Documenter.jl site that references the spec and these examples.

## 20. Benchmarking
- Microbenchmarks: `julia --project scripts/run_benchmarks.jl`.
- System benchmark: `julia --project scripts/run_benchmarks.jl --system --duration 5 --config config/driver_integration_example.toml`.
- Bridge benchmark (single-thread): `julia --project scripts/run_benchmarks.jl --bridge --duration 5 --config config/driver_integration_example.toml`.
- Bridge benchmark (AgentRunners, requires `JULIA_NUM_THREADS>=2`): `JULIA_NUM_THREADS=2 julia --project scripts/run_benchmarks.jl --bridge-runners --duration 5 --config config/driver_integration_example.toml`.
- Results should include publish/consume rates and allocation behavior under load.
- Map config → SBE messages: producer fills ShmPoolAnnounce from API config (uris, nslots, stride_bytes, announce_clock_domain); MAX_DIMS comes from the compiled schema constant.
- Consumers refuse SHM if announce values differ from compiled schema (layout_version) or backend validation fails.

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
- On epoch mismatch or seq_commit regression: drop frame, increment drops_late, log at debug/info.
- On invalid superblock or failed mmap: log error, attempt fallback_uri if configured; otherwise fail the data source.
- Log drops_gap/drops_late counts, remap events, progress throttling decisions; export counters (e.g., Prometheus) per stream.
- Error taxonomy: SHM parsing/validation throws `ShmUriError` or `ShmValidationError` when used in strict contexts; most data-plane errors are handled by drops and counters rather than exceptions.

## 18. Progress policy
- Consumer hints: take smallest interval/deltas above producer floors; if none provided, use defaults (250 us, 64 KiB, rows unset).
- Disable progress by either: no consumer supports_progress, producer config flag off, or interval/deltas set to very large values.
- Never treat FrameProgress COMPLETE as commit; seq_commit remains canonical.

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
- Seqlock under overwrite: consumer detects seq_commit instability and drops_late increments.
- Epoch remap: producer bumps epoch; consumers drop in-flight, unmap, remap.
- Fallback path: invalid SHM triggers fallback_uri usage.
- Progress off/on: verify gating and throttling; COMPLETE does not bypass seq_commit.

## 22. Bridge/rate limiter specifics
- Bridge sender forwards `ShmPoolAnnounce` on the bridge control channel and rewrites `stream_id` to `dest_stream_id`.
- Bridge receiver MUST drop chunks until at least one forwarded announce is observed for the mapping.
- Bridge receiver validates `headerBytes.pool_id` against the most recent forwarded announce; invalid pool IDs are dropped.
- Bridge receiver selects the local payload pool by smallest stride that fits `payloadLength`, ignores source `pool_id`/`payload_slot`, and rewrites `pool_id`/`payload_slot` in the local header.
- Bridge receiver rematerializes with preserved `seq/frame_id`; it publishes local `FrameDescriptor` only on IPC.
- Bridge receiver MUST validate embedded TensorHeader message header (schema/template/version/block length) before accepting chunks.
- Publish ordering: receiver MUST write SHM (payload + header + commit) before republishing FrameDescriptor; progress forwarding MUST preserve ordering rules per spec.
- Progress forwarding: sender rewrites `stream_id`; receiver remaps `headerIndex` to the local header index (drop if mapping mismatch).
- QoS/FrameProgress forwarding is gated by `forward_qos`/`forward_progress` and uses per-mapping control stream IDs.
- Metadata forwarding uses the bridge metadata channel; forwarded `stream_id` is rewritten to `metadata_stream_id` (defaulting to `dest_stream_id`).
- Discovery visibility: to discover bridged streams, run discovery providers/registries that subscribe to the bridge control (announce) and metadata channels.
- Multi-mapping is supported via `BridgeSystemAgent`; each mapping uses separate sender/receiver state and counters.
- Schema/version mismatches are rejected at decode time; bridge does not attempt to coerce unknown templates.
- Bridge backpressure: `try_claim` failure drops chunks and increments bridge counters (no retries in hot path).
- RateLimiter/Tap may suppress progress for dropped frames; must keep seq identity and follow same seq_commit rules on republished descriptors.

## 23. Device DMA integration (zero-copy)
- Use the producer to allocate payload pools, then register each payload slot with your device SDK for DMA writes.
- Map the next header index to a payload slot (v1.2 uses slot == header_index), and hand the slot pointer to the device.
- Once the device fills the buffer, call `commit_slot!` to emit the descriptor without copying.

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
claim = try_claim_slot!(state, pool_id)
# Pass claim.ptr + claim.stride_bytes to the device SDK.

commit_slot!(
    state,
    claim,
    values_len,
    shape,
    strides,
    Dtype.UINT8,
    meta_version,
)
```

Example (claim + fill helper):

```julia
with_claimed_slot!(state, values_len, shape, strides, Dtype.UINT8, meta_version) do buffer
    fill_payload!(buffer)
end
```

## 24. Project Review
- Review answers and follow-on phases are tracked in `docs/PROJECT_REVIEW.md`.

Claim helper for multiple in-flight buffers:

```julia
claim = try_claim_slot!(state, pool_id)
# Pass claim.ptr + claim.stride_bytes to the device SDK.

commit_slot!(
    state,
    claim,
    values_len,
    shape,
    strides,
    Dtype.UINT8,
    meta_version,
)
```
