# Benchmark Suite

This directory contains microbenchmarks and end-to-end benchmarks for AeronTensorPool.

## Microbenchmarks
Run with:

```
julia --project scripts/run_benchmarks.jl
```

## System benchmark (embedded media driver)
Run with:

```
julia --project scripts/run_benchmarks.jl --system --duration 5 --config config/defaults.toml
```

The system benchmark publishes frames in a tight loop and measures publish/consume throughput.
