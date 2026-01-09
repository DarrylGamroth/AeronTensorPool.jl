#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-docs/examples/driver_interop_example.toml}"
build_dir="${2:-c/build}"
interop_path="${3:-}"
count="${4:-10}"
timeout_s="${TP_INTEROP_TIMEOUT_S:-30}"
use_embedded="${TP_INTEROP_USE_EMBEDDED:-1}"
verbose="${TP_INTEROP_VERBOSE:-0}"
driver_cmd=(julia --project scripts/example_driver.jl)
driver_ready_retries="${TP_INTEROP_DRIVER_RETRIES:-}"

cleanup() {
  if [[ -n "${CONS_PID:-}" ]]; then kill "$CONS_PID" 2>/dev/null || true; fi
  if [[ -n "${C_CONS_PID:-}" ]]; then kill "$C_CONS_PID" 2>/dev/null || true; fi
  if [[ -n "${DRIVER_PID:-}" ]]; then kill "$DRIVER_PID" 2>/dev/null || true; fi
  if [[ -n "${MEDIA_PID:-}" ]]; then kill "$MEDIA_PID" 2>/dev/null || true; fi
  wait || true
  if [[ -n "${TP_INTEROP_AERON_DIR:-}" ]]; then
    rm -rf "$TP_INTEROP_AERON_DIR" || true
  fi
  if [[ -n "${READY_FILE:-}" ]]; then
    rm -f "$READY_FILE" || true
  fi
}

trap cleanup EXIT INT TERM

if [[ "$use_embedded" == "1" ]]; then
  if [[ -z "${AERON_DIR:-}" ]]; then
    TP_INTEROP_AERON_DIR="$(mktemp -d /tmp/tp-aeron-XXXXXX)"
    export AERON_DIR="$TP_INTEROP_AERON_DIR"
  fi
  export TP_AERON_DIR="${TP_AERON_DIR:-$AERON_DIR}"
  export LAUNCH_MEDIA_DRIVER=false
  nohup julia --project scripts/run_media_driver.jl "$AERON_DIR" > /tmp/tp_media_driver.log 2>&1 &
  MEDIA_PID=$!
  sleep 1
fi

eval "$(scripts/interop_env.sh "$config_path" "$interop_path")"

example_env=()
export TP_PATTERN=interop
export TP_FAIL_ON_MISMATCH=1
export TP_PRODUCER_TIMEOUT_MS="$((timeout_s * 1000))"
export TP_WAIT_CONNECT="${TP_WAIT_CONNECT:-1}"
export TP_CONNECT_TIMEOUT_MS="${TP_CONNECT_TIMEOUT_MS:-$((timeout_s * 1000))}"
READY_FILE="$(mktemp /tmp/tp-consumer-ready-XXXXXX)"
export TP_READY_FILE="$READY_FILE"
if [[ "$verbose" == "1" ]]; then
  example_env+=(TP_EXAMPLE_VERBOSE=1 TP_EXAMPLE_LOG_EVERY=1)
  export TP_LOG=1
  export TP_LOG_MODULES=Driver,Control
  driver_cmd=(julia --project --compiled-modules=no scripts/example_driver.jl)
  if [[ -z "$driver_ready_retries" ]]; then
    driver_ready_retries=30
  fi
else
  if [[ -z "$driver_ready_retries" ]]; then
    driver_ready_retries=10
  fi
fi

nohup "${driver_cmd[@]}" "$config_path" > /tmp/tp_interop_driver.log 2>&1 &
DRIVER_PID=$!
sleep 1

driver_ready=0
for _ in $(seq 1 "$driver_ready_retries"); do
  if out="$(julia --project scripts/tp_tool.jl driver-attach "${TP_AERON_DIR:-}" "$TP_CONTROL_CHANNEL" "$TP_CONTROL_STREAM_ID" 7 producer "$TP_STREAM_ID" REQUIRE_EXISTING 0 UNSPECIFIED 1000 2>/dev/null)"; then
    lease_id="$(printf "%s\n" "$out" | awk -F= '/lease_id=/{print $2; exit}')"
    if [[ -n "$lease_id" ]]; then
      julia --project scripts/tp_tool.jl driver-detach "${TP_AERON_DIR:-}" "$TP_CONTROL_CHANNEL" "$TP_CONTROL_STREAM_ID" 7 producer "$TP_STREAM_ID" "$lease_id" 1000 >/dev/null 2>&1 || true
      driver_ready=1
      break
    fi
  fi
  sleep 1
done
if [[ "$driver_ready" != "1" ]]; then
  echo "driver not ready after ${driver_ready_retries} attempts" >&2
  exit 1
fi

echo "C producer -> Julia consumer"
env "${example_env[@]}" timeout "${timeout_s}s" julia --project scripts/example_consumer.jl "$config_path" config/defaults.toml "$count" &
CONS_PID=$!
for _ in $(seq 1 "$driver_ready_retries"); do
  [[ -f "$READY_FILE" ]] && break
  sleep 1
done
sleep 1

TP_COUNT="$count" timeout "${timeout_s}s" "${build_dir}/tp_producer_example"
wait "$CONS_PID"

echo "Julia producer -> C consumer"
TP_COUNT="$count" timeout "${timeout_s}s" "${build_dir}/tp_consumer_example" &
C_CONS_PID=$!
sleep 1

env "${example_env[@]}" TP_COUNT="$count" timeout "${timeout_s}s" julia --project scripts/example_producer.jl "$config_path" config/defaults.toml "$count" 0
wait "$C_CONS_PID"
