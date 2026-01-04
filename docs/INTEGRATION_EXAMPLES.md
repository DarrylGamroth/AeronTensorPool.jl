# Integration Examples

This document provides a concrete, working example using three applications:
1) Driver
2) Frame Producer (pattern generator)
3) Frame Consumer (pattern verifier)

It uses the driver model and client API to attach to driver-provisioned SHM.

## Application 1: Driver

### Example driver config

Use `docs/examples/driver_integration_example.toml`:

```toml
[driver]
instance_id = "driver-example"
aeron_dir = "/dev/shm/aeron-${USER}"
control_channel = "aeron:ipc"
control_stream_id = 15000
announce_channel = "aeron:ipc"
announce_stream_id = 15001
qos_channel = "aeron:ipc"
qos_stream_id = 15002

[shm]
base_dir = "/dev/shm"
require_hugepages = false
page_size_bytes = 4096
permissions_mode = "660"

[policies]
allow_dynamic_streams = false
default_profile = "camera"
announce_period_ms = 1000
lease_keepalive_interval_ms = 1000
lease_expiry_grace_intervals = 3

[profiles.camera]
header_nslots = 64
header_slot_bytes = 256
max_dims = 8
payload_pools = [
  { pool_id = 1, stride_bytes = 655360 }
]

[streams.cam1]
stream_id = 1
profile = "camera"
```

### Start driver

```bash
julia --project scripts/example_driver.jl docs/examples/driver_integration_example.toml
```

## Application 2: Frame Producer (pattern generator)

The producer attaches to the driver and publishes a deterministic byte pattern
(`frame_id % 256`) into SHM, then publishes descriptors.

```bash
julia --project scripts/example_producer.jl \
  docs/examples/driver_integration_example.toml \
  config/defaults.toml \
  0 655360
```

Arguments:
- Driver config path
- Producer config path
- Frame count (0 = run forever)
- Payload bytes (default: first pool stride)

## Application 3: Frame Consumer (pattern verifier)

The consumer attaches to the driver and verifies the byte pattern produced by
the generator.

```bash
julia --project scripts/example_consumer.jl \
  docs/examples/driver_integration_example.toml \
  config/defaults.toml \
  0
```

Arguments:
- Driver config path
- Consumer config path
- Frame count (0 = run forever)

## Manual BGAPI2 Integration (outline)

To integrate with a camera SDK that accepts pre-registered buffers (e.g., BGAPI2),
use the same attach flow as the example producer, but replace the generator loop:

1) Reserve slots via `reserve_slot!` and register each slot pointer with the camera.
2) On frame completion, call `publish_reservation!` with the known shape/strides.
3) Requeue the slot by reserving a new slot or reusing the completed reservation.

## Summary

- The driver owns SHM allocation and announces layout via `ShmPoolAnnounce`.
- Producers/consumers attach via the driver client API and map SHM from responses.
- The example producer/consumer scripts are a working end-to-end reference.
