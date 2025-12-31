# Operational Playbook (Aeron Tensor Pool)

This playbook complements the spec and implementation guide with deployment and troubleshooting guidance.

## Startup Order
- Start Aeron media driver (embedded or standalone).
- Start supervisor (optional but recommended for liveness/QoS and config).
- Start producer(s) to publish announces and descriptors.
- Start consumer(s).

## Health Checks
- Producer: ShmPoolAnnounce arriving at 1 Hz; activity_timestamp_ns updated in all superblocks.
- Consumer: QosConsumer drops_gap/drops_late remain bounded; frame_id matches seq.
- Supervisor: liveness checks show active producers/consumers; config publishes only when needed.

## Common Profiles
- Low-latency: small nslots, smaller stride classes, IPC transport, pinned CPU for producer/consumer.
- Throughput: larger nslots, larger stride classes (hugepages), relaxed consumer mode (LATEST/DECIMATED).
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

## Observability
- Aeron counters expose: frames_published, drops_gap, drops_late, announces, qos_published.
- Use counters for alerting thresholds before QoS messages are processed.

## Hugepages Checklist
- Mount hugetlbfs (example): `mount -t hugetlbfs none /dev/hugepages`.
- Ensure SHM URIs use `require_hugepages=true` only when hugepages are available.
- Verify stride_bytes is multiple of hugepage size.
