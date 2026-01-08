# Benchmark Baseline

Baseline numbers for regression tracking. All runs use `config/defaults.toml` with the embedded
Aeron media driver.

## System Bench (640 KiB payload)

Command:
```bash
julia --project scripts/run_benchmarks.jl --system --duration 10 --payload-bytes 655360
```

Results:
- Publish rate: 16,501.5 fps
- Consume rate: 16,501.2 fps
- Publish bandwidth: 10,313.4 MiB/s
- Consume bandwidth: 10,313.2 MiB/s
- GC allocd delta (loop): 4,872,352 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 18,384 bytes

## Allocation Breakdown (640 KiB payload)

Command:
```bash
julia --project -e 'include("bench/system_bench.jl"); run_system_bench("config/defaults.toml", 1.0; payload_bytes=655360, warmup_s=0.2, alloc_breakdown=true, fixed_iters=256, do_yield=true)'
```

Results:
- `producer_do_work`: 0 bytes
- `consumer_do_work`: 0 bytes
- `consumer_do_work (with frame)`: 0 bytes
- `supervisor_do_work`: 0 bytes
- `publish_frame`: 0 bytes
- `producer_poll_timers`: 0 bytes
- `consumer_poll_timers`: 0 bytes
- `emit_consumer_hello`: 0 bytes
- `emit_consumer_qos`: 0 bytes
- `supervisor_poll_timers`: 0 bytes
- `yield`: 0 bytes
- Empty loop (256 iters): 0 bytes
- Loop alloc delta: 128 bytes (over 256 iters)

## Bridge Bench (AgentRunner path)

Command:
```bash
JULIA_NUM_THREADS=2 julia --project scripts/run_benchmarks.jl --bridge-runners --duration 5 --payload-bytes 655360 --config config/defaults.toml
```
## System Bench (Single Process, Producer/Consumer/Supervisor)

### 640 KiB payloads (10s)
- payload_bytes: 655,360
- Published: 198,495 frames in 10.0s
- Consumed: 198,495 frames in 10.0s
- Publish rate: 19,849.4 fps
- Consume rate: 19,849.4 fps
- Publish bandwidth: 12,405.9 MiB/s
- Consume bandwidth: 12,405.9 MiB/s
- GC allocd delta (loop): 4,195,872 bytes
- GC live delta (loop): 4,243,312 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 45,024 bytes
