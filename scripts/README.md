# Scripts Overview

Quick reference for the scripts under `scripts/`. Most scripts accept a config path as the
first argument; defaults are shown below.

## Driver

- `example_driver.jl`  
  Starts the driver.  
  Usage: `julia --project scripts/example_driver.jl config/driver_integration_example.toml`

- `run_driver.jl`  
  Starts the driver from a config.  
  Usage: `julia --project scripts/run_driver.jl config/driver_integration_example.toml`

## Producer/consumer examples

- `example_producer.jl`  
  Producer example (patterned payload).  
  Usage:  
  `julia --project scripts/example_producer.jl config/driver_integration_example.toml config/defaults.toml 0 1048576`

- `example_consumer.jl`  
  Consumer example (validates pattern).  
  Usage:  
  `julia --project scripts/example_consumer.jl config/driver_integration_example.toml config/defaults.toml 0`

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
  Usage: `eval "$(scripts/interop_env.sh config/driver_integration_example.toml config/interop_env_example.toml)"`

- `interop_print_endpoints.sh`  
  Prints resolved endpoints from driver config + env.  
  Usage: `scripts/interop_print_endpoints.sh config/driver_integration_example.toml`

- `run_media_driver.jl`  
  Starts a standalone Aeron MediaDriver.  
  Usage: `julia --project scripts/run_media_driver.jl`

- `run_benchmarks.jl`  
  Runs benchmark suite.  
  Usage: `julia --project scripts/run_benchmarks.jl`

- `run_tests.jl` / `run_tests.sh`  
  Runs the Julia test suite.  
  Usage: `julia --project scripts/run_tests.jl`

- `tp_tool.jl`  
  CLI for control-plane inspection (announce/QoS/metadata).  
  Usage: `julia --project scripts/tp_tool.jl`
