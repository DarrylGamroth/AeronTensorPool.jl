#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-docs/examples/driver_integration_example.toml}"
build_dir="${2:-c/build}"
interop_path="${3:-}"

if [[ ! -d "$build_dir" ]]; then
  echo "Build directory not found: $build_dir" >&2
  echo "Run: cmake -S c -B $build_dir -DTP_USE_BUNDLED_AERON=ON -DTP_BUILD_TESTS=ON -DTP_BUILD_INTEGRATION_TESTS=ON" >&2
  exit 1
fi

eval "$(scripts/interop_env.sh "$config_path" "$interop_path")"

ctest --test-dir "$build_dir" -R "tp_integration_smoke|tp_integration_detach" --output-on-failure
