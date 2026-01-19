# Scripts Overview

Quick reference for the scripts under `scripts/`. Most scripts accept a config path as the
first argument; defaults are shown below.

## Driver

- `run_driver.jl`  
  Starts the driver from a config (set `LAUNCH_MEDIA_DRIVER=true` to launch an embedded MediaDriver).  
  Usage: `julia --project scripts/run_driver.jl config/driver_integration_example.toml`

- `run_examples.sh`  
  Runs the driver/producer/consumer example triplet with logging enabled (defaults to embedded MediaDriver).  
  Usage: `scripts/run_examples.sh [config/driver_integration_example.toml] [count] [payload_bytes]`

- `run_examples_per_consumer.sh`  
  Runs the driver/producer + per-consumer stream consumer example (rate-limited consumer).  
  Usage:  
  `scripts/run_examples_per_consumer.sh [config/driver_integration_example.toml] [count] [payload_bytes] [max_rate_hz] [descriptor_base] [control_base] [dynamic] [consumer_id] [channel]`
  `dynamic=1` requests driver-assigned per-consumer stream IDs (requires driver stream-id ranges).
  The wrapper scales producer count to satisfy `max_rate_hz` when non-zero, using `TP_PRODUCER_SEND_INTERVAL_NS`
  (defaults to `1e9 / max_rate_hz` when unset).

## Bridge

- `run_bridge.jl`  
  Starts the bridge from a config.  
  Usage: `julia --project scripts/run_bridge.jl config/bridge_config_example.toml [config/driver_integration_example.toml]`

- `run_bridge_chain.jl`  
  Runs a two-bridge chain test (embedded MediaDriver).  
  Usage: `julia --project scripts/run_bridge_chain.jl [config/bridge_chain_a_example.toml] [config/bridge_chain_b_example.toml] [duration_s]`

## Rate limiter

- `run_rate_limiter.jl`  
  Starts the rate limiter from a config.  
  Usage: `julia --project scripts/run_rate_limiter.jl config/rate_limiter_example.toml`

## Producer/consumer examples

- `example_producer.jl`  
  Producer example (patterned payload).  
  Usage:  
  `julia --project scripts/example_producer.jl config/driver_integration_example.toml 0 1048576`

- `example_consumer.jl`  
  Consumer example (validates pattern).  
  Usage:  
  `julia --project scripts/example_consumer.jl config/driver_integration_example.toml 0`

- `example_progress_consumer.jl`  
  Consumer that listens for `FrameProgress`.  
  Usage: `julia --project scripts/example_progress_consumer.jl config/driver_integration_example.toml`

- `example_rate_limited_consumer.jl`  
  Consumer requesting per-consumer streams and max rate.  
  Usage: `julia --project scripts/example_rate_limited_consumer.jl config/driver_integration_example.toml`

## Control-plane helpers

- `example_discovery.jl`  
  Discovery request/response example.  
  Usage: `julia --project scripts/example_discovery.jl config/driver_integration_example.toml`

- `example_join_barrier_sequence.jl`  
  JoinBarrier sequence example (in-memory).  
  Usage: `julia --project scripts/example_join_barrier_sequence.jl`

- `example_join_barrier_timestamp.jl`  
  JoinBarrier timestamp example (in-memory).  
  Usage: `julia --project scripts/example_join_barrier_timestamp.jl`

- `example_join_barrier_latest.jl`  
  JoinBarrier latest-value example (in-memory).  
  Usage: `julia --project scripts/example_join_barrier_latest.jl`

- `example_qos_monitor.jl`  
  QoS snapshot monitor.  
  Usage: `julia --project scripts/example_qos_monitor.jl config/driver_integration_example.toml`

- `example_detach.jl`  
  Detach lease example.  
  Usage: `julia --project scripts/example_detach.jl config/driver_integration_example.toml`

- `example_reattach.jl`  
  Detach + reattach example.  
  Usage: `julia --project scripts/example_reattach.jl config/driver_integration_example.toml`

- `example_invoker.jl`  
  Runs client in invoker mode.  
  Usage: `julia --project scripts/example_invoker.jl config/driver_integration_example.toml`

## Utilities

- `interop_env.sh`  
  Emits env vars based on a driver config (used by interop tooling).  
  Usage: `eval "$(scripts/interop_env.sh config/driver_integration_example.toml)"`

- `interop_print_endpoints.sh`  
  Prints resolved endpoints from driver config + env.  
  Usage: `scripts/interop_print_endpoints.sh config/driver_integration_example.toml`

- `run_benchmarks.jl`  
  Runs benchmark suite.  
  Usage: `julia --project scripts/run_benchmarks.jl`

- `run_tests.jl` / `run_tests.sh`  
  Runs the Julia test suite.  
  Usage: `julia --project scripts/run_tests.jl`

- `tp_tool.jl`  
  CLI for control-plane inspection (announce/QoS/metadata). Prefer the `tp_tool` app when available.  
  Usage: `julia --project scripts/tp_tool.jl`
