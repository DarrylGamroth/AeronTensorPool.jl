#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-docs/examples/driver_integration_example.toml}"
build_dir="${2:-c/build}"

if [[ ! -d "$build_dir" ]]; then
  echo "Build directory not found: $build_dir" >&2
  echo "Run: cmake -S c -B $build_dir -DTP_USE_BUNDLED_AERON=ON -DTP_BUILD_TESTS=ON -DTP_BUILD_INTEGRATION_TESTS=ON" >&2
  exit 1
fi

readarray -t cfg < <(julia --project -e '
using TOML
cfg = TOML.parsefile(ARGS[1])
driver = get(cfg, "driver", Dict{String,Any}())
streams = get(cfg, "streams", Dict{String,Any}())
control_channel = get(driver, "control_channel", "aeron:ipc")
control_stream_id = get(driver, "control_stream_id", 1000)
stream_id = 1
for (_, stream) in streams
    if haskey(stream, "stream_id")
        stream_id = stream["stream_id"]
        break
    end
end
aeron_dir = get(driver, "aeron_dir", "")
println(control_channel)
println(control_stream_id)
println(stream_id)
println(aeron_dir)
' "$config_path")

control_channel="${cfg[0]}"
control_stream_id="${cfg[1]}"
stream_id="${cfg[2]}"
aeron_dir="${cfg[3]}"

export TP_CONTROL_CHANNEL="$control_channel"
export TP_CONTROL_STREAM_ID="$control_stream_id"
export TP_STREAM_ID="$stream_id"
if [[ -n "$aeron_dir" ]]; then
  export TP_AERON_DIR="$aeron_dir"
fi

ctest --test-dir "$build_dir" -R tp_integration_smoke --output-on-failure
