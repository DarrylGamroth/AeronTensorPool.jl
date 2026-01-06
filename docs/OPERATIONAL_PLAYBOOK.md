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
- Throughput: larger nslots, larger stride classes (hugepages), relaxed consumer mode (RATE_LIMITED).
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

## GC Monitoring (Julia)
- Track `GC.num()` and `GC.gc_time_ns()` under load for jitter spikes.
- Use allocation tests and keep hot loops allocation-free after init.

## Troubleshooting Checklist
- Verify SHM file paths exist and permissions are correct.
- Confirm layout_version/epoch match between announce and superblock.
- Confirm descriptor/control/QoS stream IDs align across roles.
- Check that consumers remap after epoch changes and drop in-flight frames.
- Verify that payload_slot == header_index for v1.1 mapping.

## CLI Examples (Driver Control Plane)
Attach (producer role):
- `julia --project scripts/tp_tool.jl driver-attach /dev/shm/aeron aeron:ipc 1000 7 producer 42`

Keepalive:
- `julia --project scripts/tp_tool.jl driver-keepalive /dev/shm/aeron aeron:ipc 1000 7 producer 42 123`

Detach:
- `julia --project scripts/tp_tool.jl driver-detach /dev/shm/aeron aeron:ipc 1000 7 producer 42 123`

## Julia Apps (1.12+)
- Build app executables:
  - `julia --project -e 'using Pkg; Pkg.build()'`
- Run tp_tool app:
  - `./bin/tp_tool <command> ...`
- Run driver app:
  - `./bin/tp_driver [driver_config]`
