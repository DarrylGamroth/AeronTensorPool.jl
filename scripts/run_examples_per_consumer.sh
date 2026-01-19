#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-config/driver_integration_example.toml}"
count="${2:-10}"
payload_bytes="${3:-65536}"
max_rate_hz="${4:-30}"
timeout_s="${TP_EXAMPLE_TIMEOUT:-30}"

export TP_LOG=1
export TP_LOG_LEVEL="${TP_LOG_LEVEL:-20}"
export LAUNCH_MEDIA_DRIVER="${LAUNCH_MEDIA_DRIVER:-true}"

julia --project scripts/run_driver.jl "${config_path}" &
driver_pid=$!

cleanup() {
  kill -INT "${driver_pid}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 1

ready_file="$(mktemp)"
export TP_READY_FILE="${ready_file}"

timeout "${timeout_s}" julia --project scripts/example_rate_limited_consumer.jl "${config_path}" "${count}" "${max_rate_hz}" &
consumer_pid=$!

deadline=$((SECONDS + timeout_s))
while [[ ! -f "${ready_file}" && ${SECONDS} -lt ${deadline} ]]; do
  sleep 0.1
done

timeout "${timeout_s}" julia --project scripts/example_producer.jl "${config_path}" "${count}" "${payload_bytes}" &
producer_pid=$!

wait "${producer_pid}"
wait "${consumer_pid}"
