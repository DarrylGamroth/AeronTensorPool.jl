# Benchmark Baseline

Baseline numbers for regression tracking. Each section lists the exact command used.

## System Bench (640 KiB payload)

Run at: 2026-01-14 12:17:15 PST

Command:
```bash
julia --project scripts/run_benchmarks.jl --system --duration 10 --payload-bytes 655360 --config config/driver_integration_example.toml
```

Results:
- Publish rate: 20,144.7 fps
- Consume rate: 20,144.3 fps
- Publish bandwidth: 12,590.4 MiB/s
- Consume bandwidth: 12,590.2 MiB/s
- GC allocd delta (loop): 27,514,328 bytes
- GC live delta (loop): 27,514,328 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 51,616 bytes

## Allocation Breakdown (640 KiB payload)

Command:
```bash
julia --project scripts/run_benchmarks.jl --system --duration 1 --payload-bytes 655360 --config config/driver_integration_example.toml --warmup 0.2 --alloc-breakdown --fixed-iters 256
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
JULIA_NUM_THREADS=2 julia --project scripts/run_benchmarks.jl --bridge-runners --duration 5 --payload-bytes 655360 --config config/driver_integration_example.toml
```

Results:
- Publish rate: 15,333.3 fps
- Consume rate: 1,034.8 fps
- Publish bandwidth: 9,583.3 MiB/s
- Consume bandwidth: 646.7 MiB/s
- GC allocd delta (loop): 39,306,224 bytes
- GC live delta (loop): 42,399,888 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 331,000 bytes

## Bridge Bench (Invoker path)

Command:
```bash
julia --project scripts/run_benchmarks.jl --bridge --duration 10 --payload-bytes 655360 --config config/driver_integration_example.toml
```

Results:
- Publish rate: 16,937.9 fps
- Consume rate: 227.3 fps
- Publish bandwidth: 10,586.2 MiB/s
- Consume bandwidth: 142.1 MiB/s
- GC allocd delta (loop): 27,778,848 bytes
- GC live delta (loop): 27,778,848 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 55,688 bytes

## Bridge Bench (Invoker path, udp-jumbo profile)

Run at: 2026-01-14 13:22:50 PST

Command:
```bash
julia --project scripts/run_benchmarks.jl --bridge --duration 10 --payload-bytes 655360 --bridge-profile udp-jumbo --config config/driver_integration_example.toml
```

Results:
- Publish rate: 13,103.6 fps
- Consume rate: 1,552.9 fps
- Publish bandwidth: 8,189.7 MiB/s
- Consume bandwidth: 970.6 MiB/s
- GC allocd delta (loop): 38,149,328 bytes
- GC live delta (loop): 38,149,328 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 54,792 bytes

## Bridge Bench (Invoker path, ipc-heavy profile)

Run at: 2026-01-14 13:22:50 PST

Command:
```bash
julia --project scripts/run_benchmarks.jl --bridge --duration 10 --payload-bytes 655360 --bridge-profile ipc-heavy --config config/driver_integration_example.toml
```

Results:
- Publish rate: 4,737.5 fps
- Consume rate: 4,147.0 fps
- Publish bandwidth: 2,960.9 MiB/s
- Consume bandwidth: 2,591.9 MiB/s
- GC allocd delta (loop): 57,346,560 bytes
- GC live delta (loop): 57,346,560 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 56,600 bytes
