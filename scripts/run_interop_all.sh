#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-docs/examples/driver_integration_example.toml}"
build_dir="${2:-c/build}"
interop_path="${3:-}"
count="${4:-10}"

cleanup() {
  if [[ -n "${CONS_PID:-}" ]]; then kill "$CONS_PID" 2>/dev/null || true; fi
  if [[ -n "${DRIVER_PID:-}" ]]; then kill "$DRIVER_PID" 2>/dev/null || true; fi
  wait || true
}

trap cleanup EXIT INT TERM

eval "$(scripts/interop_env.sh "$config_path" "$interop_path")"

nohup julia --project scripts/example_driver.jl "$config_path" > /tmp/tp_interop_driver.log 2>&1 &
DRIVER_PID=$!
sleep 1

scripts/run_c_integration_smoke.sh "$config_path" "$build_dir" "$interop_path"

julia --project scripts/example_consumer.jl "$config_path" config/defaults.toml "$count" &
CONS_PID=$!
sleep 1

TP_COUNT="$count" julia --project scripts/example_producer.jl "$config_path" config/defaults.toml "$count" 0
wait "$CONS_PID"
