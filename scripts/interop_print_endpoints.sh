#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-docs/examples/driver_integration_example.toml}"
interop_path="${2:-}"

eval "$(scripts/interop_env.sh "$config_path" "$interop_path")"

echo "Driver config:"
julia --project scripts/interop_print_driver_config.jl "$config_path"
echo

client_id="${TP_CLIENT_ID:-$$}"
role="${TP_ROLE:-producer}"
stream_id="${TP_STREAM_ID:-1}"

echo "Live attach response:"
output="$(julia --project scripts/tp_tool.jl driver-attach "${TP_AERON_DIR:-}" "$TP_CONTROL_CHANNEL" "$TP_CONTROL_STREAM_ID" "$client_id" "$role" "$stream_id")"
printf "%s\n" "$output"

lease_id="$(printf "%s\n" "$output" | awk -F= '/lease_id=/{print $2; exit}')"
if [[ -n "$lease_id" ]]; then
  julia --project scripts/tp_tool.jl driver-detach "${TP_AERON_DIR:-}" "$TP_CONTROL_CHANNEL" "$TP_CONTROL_STREAM_ID" "$client_id" "$role" "$stream_id" "$lease_id" >/dev/null
fi
