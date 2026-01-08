#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-docs/examples/driver_integration_example.toml}"
interop_path="${2:-}"

if [[ ! -f "$config_path" ]]; then
  echo "Driver config not found: $config_path" >&2
  exit 1
fi

julia --project -e '
using AeronTensorPool
using TOML

function first_stream_id(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    return first(values(cfg.streams)).stream_id
end

function first_payload_stride(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    profile = cfg.profiles[first(values(cfg.streams)).profile]
    isempty(profile.payload_pools) && return UInt32(0)
    return profile.payload_pools[1].stride_bytes
end

config_path = ARGS[1]
interop_path = length(ARGS) >= 2 ? ARGS[2] : ""

env = Dict(ENV)
if haskey(ENV, "AERON_DIR")
    env["DRIVER_AERON_DIR"] = ENV["AERON_DIR"]
end
if haskey(ENV, "TP_CONTROL_CHANNEL")
    env["DRIVER_CONTROL_CHANNEL"] = ENV["TP_CONTROL_CHANNEL"]
end
if haskey(ENV, "TP_CONTROL_STREAM_ID")
    env["DRIVER_CONTROL_STREAM_ID"] = ENV["TP_CONTROL_STREAM_ID"]
end

cfg = load_driver_config(config_path; env = env)

overrides = Dict{String, Any}()
if !isempty(interop_path) && isfile(interop_path)
    raw = TOML.parsefile(interop_path)
    overrides = get(raw, "interop", Dict{String, Any}())
end

function override(key::String, fallback)
    return haskey(overrides, key) ? overrides[key] : fallback
end

aeron_dir = String(override("aeron_dir", cfg.endpoints.aeron_dir))
control_channel = String(override("control_channel", cfg.endpoints.control_channel))
control_stream_id = Int(override("control_stream_id", cfg.endpoints.control_stream_id))
stream_id = Int(override("stream_id", first_stream_id(cfg)))
descriptor_channel = String(override("descriptor_channel", ""))
descriptor_stream_id = Int(override("descriptor_stream_id", 0))
payload_stride = Int(override("payload_stride_bytes", first_payload_stride(cfg)))

println("export TP_CONTROL_CHANNEL=$(control_channel)")
println("export TP_CONTROL_STREAM_ID=$(control_stream_id)")
println("export TP_STREAM_ID=$(stream_id)")
if !isempty(aeron_dir)
    println("export TP_AERON_DIR=$(aeron_dir)")
    println("export AERON_DIR=$(aeron_dir)")
end
if !isempty(descriptor_channel)
    println("export TP_DESCRIPTOR_CHANNEL=$(descriptor_channel)")
end
if descriptor_stream_id != 0
    println("export TP_DESCRIPTOR_STREAM_ID=$(descriptor_stream_id)")
end
if payload_stride != 0
    println("export TP_PAYLOAD_BYTES=$(payload_stride)")
end
' "$config_path" "$interop_path"
