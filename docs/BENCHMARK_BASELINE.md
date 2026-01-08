# Benchmark Baseline

Baseline numbers for regression tracking. Each section lists the exact command used.

## System Bench (640 KiB payload)

Run at: 2026-01-07 17:01:29 PST

Command:
```bash
cat <<'EOF' >/tmp/tp_system_bench.toml
[producer]
aeron_dir = ""
aeron_uri = "aeron:ipc?term-length=4m"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
metadata_stream_id = 1300
stream_id = 1
producer_id = 1
layout_version = 1
nslots = 64
shm_base_dir = "/dev/shm"
shm_namespace = "tensorpool"
producer_instance_id = ""
header_uri = ""
max_dims = 8
announce_interval_ns = 1000000000
qos_interval_ns = 1000000000
progress_interval_ns = 250000
progress_bytes_delta = 65536

[[producer.payload_pools]]
pool_id = 1
uri = ""
stride_bytes = 1048576
nslots = 64

[consumer]
aeron_dir = ""
aeron_uri = "aeron:ipc?term-length=4m"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
stream_id = 1
consumer_id = 1
expected_layout_version = 1
max_dims = 8
mode = "STREAM"
decimation = 1
max_outstanding_seq_gap = 0
use_shm = true
supports_shm = true
supports_progress = false
max_rate_hz = 0
payload_fallback_uri = ""
shm_base_dir = "/dev/shm"
allowed_base_dirs = ["/dev/shm"]
require_hugepages = false
progress_interval_us = 250
progress_bytes_delta = 65536
progress_rows_delta = 0
hello_interval_ns = 1000000000
qos_interval_ns = 1000000000

[supervisor]
aeron_dir = ""
aeron_uri = "aeron:ipc?term-length=4m"
control_stream_id = 1000
qos_stream_id = 1200
stream_id = 1
liveness_timeout_ns = 5000000000
liveness_check_interval_ns = 1000000000
EOF

julia --project scripts/run_benchmarks.jl --system --duration 10 --payload-bytes 655360 --config /tmp/tp_system_bench.toml
```

Results:
- Publish rate: 20,130.1 fps
- Consume rate: 20,129.7 fps
- Publish bandwidth: 12,581.3 MiB/s
- Consume bandwidth: 12,581.0 MiB/s
- GC allocd delta (loop): 13,748,752 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 18,224 bytes

## Allocation Breakdown (640 KiB payload)

Command:
```bash
julia --project scripts/run_benchmarks.jl --system --duration 1 --payload-bytes 655360 --config config/defaults.toml --warmup 0.2 --alloc-breakdown --fixed-iters 256
```

Results:
- `producer_do_work`: 0 bytes
- `composite_do_work`: 0 bytes
- `producer_do_work_raw`: 0 bytes
- `producer_do_work_agent`: 0 bytes
- `producer_counter_updates`: 0 bytes
- `consumer_do_work`: 0 bytes
- `consumer_do_work_raw`: 0 bytes
- `consumer_do_work_agent`: 0 bytes
- `consumer_do_work (with frame)`: 0 bytes
- `supervisor_do_work`: 0 bytes
- `supervisor_do_work_raw`: 0 bytes
- `supervisor_do_work_agent`: 0 bytes
- `publish_frame`: 0 bytes
- `producer_poll_timers`: 0 bytes
- `consumer_poll_timers`: 0 bytes
- `emit_consumer_hello`: 0 bytes
- `emit_consumer_qos`: 0 bytes
- `supervisor_poll_timers`: 0 bytes
- `yield`: 0 bytes
- Empty loop (256 iters): 0 bytes
- Loop alloc delta: 0 bytes (over 256 iters)

## Bridge Bench (AgentRunner path)

Command:
```bash
JULIA_NUM_THREADS=2 julia --project scripts/run_benchmarks.jl --bridge-runners --duration 5 --payload-bytes 655360 --config config/defaults.toml
```
