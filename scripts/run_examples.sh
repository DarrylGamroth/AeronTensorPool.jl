#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-config/driver_integration_example.toml}"
count="${2:-10}"
payload_bytes="${3:-65536}"
timeout_s="${TP_EXAMPLE_TIMEOUT:-30}"

export TP_LOG=1
export TP_LOG_LEVEL="${TP_LOG_LEVEL:-20}"

julia --project scripts/example_driver.jl "${config_path}" &
driver_pid=$!

cleanup() {
  kill "${driver_pid}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 1

timeout "${timeout_s}" julia --project scripts/example_producer.jl "${config_path}" "${count}" "${payload_bytes}" &
producer_pid=$!
timeout "${timeout_s}" julia --project scripts/example_consumer.jl "${config_path}" "${count}" &
consumer_pid=$!

wait "${producer_pid}"
wait "${consumer_pid}"
