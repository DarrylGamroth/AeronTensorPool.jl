#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/run_all.sh <config_path>"
  exit 1
fi

config_path="$1"

cleanup() {
  if [[ -n "${PROD_PID:-}" ]]; then kill "$PROD_PID" 2>/dev/null || true; fi
  if [[ -n "${CONS_PID:-}" ]]; then kill "$CONS_PID" 2>/dev/null || true; fi
  if [[ -n "${SUP_PID:-}" ]]; then kill "$SUP_PID" 2>/dev/null || true; fi
  wait || true
}

trap cleanup EXIT INT TERM

julia --project scripts/run_role.jl supervisor "$config_path" &
SUP_PID=$!
julia --project scripts/run_role.jl producer "$config_path" &
PROD_PID=$!
julia --project scripts/run_role.jl consumer "$config_path" &
CONS_PID=$!

wait
