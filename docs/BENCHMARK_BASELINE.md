# Benchmark Baseline

Baseline numbers for regression tracking. All runs use `config/defaults.toml` with the embedded
Aeron media driver.

## System Bench (640 KiB payload)

Command:
```bash
julia --project -e 'include("bench/system_bench.jl"); run_system_bench("config/defaults.toml", 3.0; payload_bytes=655360, warmup_s=0.5)'
```

Results:
- Publish rate: 15,643.8 fps
- Consume rate: 15,643.8 fps
- GC allocd delta (loop): 10,912,448 bytes
- GC allocd delta (total): 0 bytes
- GC live delta (total): 25,104 bytes

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
- `yield`: 0 bytes
- Loop alloc delta: 128 bytes (over 256 iters)
