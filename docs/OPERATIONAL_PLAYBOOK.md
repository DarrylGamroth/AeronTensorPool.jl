# Operational Playbook (Aeron Tensor Pool)

This playbook complements the spec and implementation guide with deployment and troubleshooting guidance.

## Startup Order
- Start Aeron media driver (embedded or standalone).
- Start SHM driver (driver mode only).
- Start supervisor (optional but recommended for liveness/QoS and config).
- Start producer(s) to publish announces and descriptors.
- Start consumer(s).

## Health Checks
- Producer: ShmPoolAnnounce arriving at 1 Hz; activity_timestamp_ns updated in all superblocks.
- Consumer: QosConsumer drops_gap/drops_late remain bounded; frame_id matches seq.
- Supervisor: liveness checks show active producers/consumers; config publishes only when needed.
- Counters: frames_published increasing; drops counters stable; announce/qos counters non-zero.

## Common Profiles
- Low-latency: small nslots, smaller stride classes, IPC transport, pinned CPU for producer/consumer.
- Throughput: larger nslots, larger stride classes (hugepages), rate-limited delivery when needed.
- Multi-consumer: increase nslots for worst-case consumer latency; set supervisor liveness timeout to 3-5x announce cadence.

## Tuning Matrix
- nslots = rate_hz * worst_case_latency_s * safety_factor(2-4).
- stride_bytes = next power-of-two >= max payload; prefer hugepage-aligned strides.
- announce_hz = 1.0; liveness timeout = 3-5x announce interval.

## Failure Playbook
- No ShmPoolAnnounce: check producer running, Aeron directory, control stream IDs.
- Consumer remap loop: verify superblock magic/layout/epoch and URI validation (hugepages).
- drops_gap increasing: producer/consumer scheduling delays; increase nslots or reduce consumer work.
- drops_late increasing: seqlock contention; verify single writer and avoid long payload writes.
- QosConsumer missing: verify consumer has QoS publication and supervisor subscription stream IDs match.
- FrameDescriptor received but payload invalid: verify payload pool URI, stride_bytes, and pool_id mapping.

## Observability
- Aeron counters expose: frames_published, drops_gap, drops_late, announces, qos_published.
- Producer counters also expose descriptor publication health: descriptor_backpressured, descriptor_not_connected, descriptor_admin_action, descriptor_closed, descriptor_max_position_exceeded, descriptor_errors.
- Producer logs "Producer descriptor backpressure" at most once per second while backpressured.
- Producer counter labels include `stream=<id>` and `instance=<producer_instance_id>` for per-stream debugging.
- Use counters for alerting thresholds before QoS messages are processed.

Suggested thresholds (tune per deployment)
- drops_gap sustained > 0.1% of frames: increase nslots or reduce consumer load.
- drops_late sustained > 0.1% of frames: reduce payload write time or check scheduler jitter.
- No announces for > 5 seconds: consider producer down or Aeron connectivity issue.

## Hugepages Checklist
- Mount hugetlbfs (example): `mount -t hugetlbfs none /dev/hugepages`.
- Ensure SHM URIs use `require_hugepages=true` only when hugepages are available.
- Verify stride_bytes is multiple of hugepage size.

## Driver Mode Notes
- Clients must attach via the SHM driver and MUST NOT create/truncate SHM files.
- In standalone mode, run the SHM driver in-process (analogous to an embedded driver pattern).
- Use driver announce/qos streams for operator visibility.

## Configuration References
- Driver and bridge configuration: `docs/CONFIG_REFERENCE.md`
- Authoritative driver spec: `docs/SHM_Driver_Model_Spec_v1.0.md`
- Authoritative bridge spec: `docs/SHM_Aeron_UDP_Bridge_Spec_v1.1.md`
- Stream ID conventions: `docs/STREAM_ID_CONVENTIONS.md`

## GC Monitoring (Julia)
- Track `GC.num()` and `GC.gc_time_ns()` under load for jitter spikes.
- Use allocation tests and keep hot loops allocation-free after init.

## Troubleshooting Checklist
- Verify SHM file paths exist and permissions are correct.
- Confirm layout_version/epoch match between announce and superblock.
- Confirm descriptor/control/QoS stream IDs align across roles.
- Check that consumers remap after epoch changes and drop in-flight frames.
- If `/dev/shm` fills up, enable epoch GC (`policies.epoch_gc_enabled`) or run a manual cleanup of stale epoch directories.
- Verify that payload_slot == header_index for v1.2 mapping.

## Deployment & Liveness Validation Checklist (Wire §15.14)
- Verify superblock fields (`magic`, `layout_version`, `epoch`, `pid`, `start_timestamp_ns`, `activity_timestamp_ns`) are present and updated.
- Confirm producers refresh `activity_timestamp_ns` at announce cadence and supervisors treat stale activity as dead (3-5x announce interval).
- Validate remap triggers: any change to `magic`, `layout_version`, or `epoch` causes consumer remap.
- Confirm single-writer rule: concurrent writers or pid changes trigger remap/unmap.
- Check clean shutdown behavior: optional unlink or clean-close flag, and epoch GC removes stale epochs.
- Validate permissions/ownership on SHM files match policy (restrictive modes).

## CLI Examples (Driver Control Plane)
Attach (producer role):
- `./bin/tp_tool driver-attach /dev/shm/aeron aeron:ipc 1000 7 producer 42`

Keepalive:
- `./bin/tp_tool driver-keepalive /dev/shm/aeron aeron:ipc 1000 7 producer 42 123`

Detach:
- `./bin/tp_tool driver-detach /dev/shm/aeron aeron:ipc 1000 7 producer 42 123`

Listen for control-plane traffic:
- `./bin/tp_tool announce-listen /dev/shm/aeron aeron:ipc 1000`
- `./bin/tp_tool control-listen /dev/shm/aeron aeron:ipc 1000`
- `./bin/tp_tool metadata-listen /dev/shm/aeron aeron:ipc 1300`
- `./bin/tp_tool metadata-dump /dev/shm/aeron aeron:ipc 1300`
- `./bin/tp_tool qos-listen /dev/shm/aeron aeron:ipc 1200`
- `./bin/tp_tool discovery-list /dev/shm/aeron aeron:ipc 7000 aeron:ipc 7004`

## Julia Apps (1.12+)
- Build app executables:
  - `julia --project -e 'using Pkg; Pkg.build()'`
- Run tp_tool app:
  - `./bin/tp_tool <command> ...`
- Run driver app:
  - `./bin/tp_driver [driver_config]`
- Script fallback:
  - `julia --project scripts/tp_tool.jl <command> ...`
