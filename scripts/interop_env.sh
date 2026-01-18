#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-config/driver_integration_example.toml}"

if [[ ! -f "$config_path" ]]; then
  echo "Driver config not found: $config_path" >&2
  exit 1
fi

julia --project -e '
using AeronTensorPool

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

function first_header_nslots(cfg::DriverConfig)
    isempty(cfg.streams) && error("driver config has no streams")
    profile = cfg.profiles[first(values(cfg.streams)).profile]
    return profile.header_nslots
end

config_path = ARGS[1]

cfg = from_toml(DriverConfig, config_path; env = true)

aeron_dir = String(cfg.endpoints.aeron_dir)
control_channel = String(cfg.endpoints.control_channel)
control_stream_id = Int(cfg.endpoints.control_stream_id)
stream_id = Int(first_stream_id(cfg))
descriptor_channel = ""
descriptor_stream_id = 0
if isempty(descriptor_channel)
    descriptor_channel = control_channel
end
if descriptor_stream_id == 0
    descriptor_stream_id = 1100
end
consumer_descriptor_channel = ""
consumer_descriptor_stream_id = 0
consumer_control_channel = ""
consumer_control_stream_id = 0
payload_stride = Int(first_payload_stride(cfg))
header_nslots = Int(first_header_nslots(cfg))

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
if !isempty(consumer_descriptor_channel)
    println("export TP_CONSUMER_DESCRIPTOR_CHANNEL=$(consumer_descriptor_channel)")
end
if consumer_descriptor_stream_id != 0
    println("export TP_CONSUMER_DESCRIPTOR_STREAM_ID=$(consumer_descriptor_stream_id)")
end
if !isempty(consumer_control_channel)
    println("export TP_CONSUMER_CONTROL_CHANNEL=$(consumer_control_channel)")
end
if consumer_control_stream_id != 0
    println("export TP_CONSUMER_CONTROL_STREAM_ID=$(consumer_control_stream_id)")
end
if payload_stride != 0
    println("export TP_PAYLOAD_BYTES=$(payload_stride)")
end
if header_nslots != 0
    println("export TP_HEADER_NSLOTS=$(header_nslots)")
end
' "$config_path"
