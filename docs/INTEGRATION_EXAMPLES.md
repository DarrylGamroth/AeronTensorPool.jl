# Integration Examples

This document provides a concrete, working example using three applications:
1) Driver
2) Frame Producer (application-defined Agent)
3) Frame Consumer (application-defined Agent)

It uses the driver model and client API to attach to driver-provisioned SHM.

## Application 1: Driver

- Uses an `AgentRunner` to run `DriverAgent`.
- Loads a config file for the driver.

### Example driver config

Use `docs/examples/driver_integration_example.toml`:

```toml
[driver]
instance_id = "driver-example"
aeron_dir = ""
control_channel = "aeron:ipc?term-length=4m"
control_stream_id = 15000
announce_channel = "aeron:ipc?term-length=4m"
announce_stream_id = 15001
qos_channel = "aeron:ipc?term-length=4m"
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
payload_pools = [
  { pool_id = 1, stride_bytes = 1048576 }
]

[streams.cam1]
stream_id = 1
profile = "camera"
```

### Start driver (AgentRunner)

```bash
julia --project scripts/example_driver.jl docs/examples/driver_integration_example.toml
```

## Application 2: Frame Producer (application-defined Agent)

The application defines its own Agent, runs it with an `AgentRunner`, and uses
the driver client API to attach and map SHM. The example uses a simple pattern
generator, but the same flow applies to BGAPI2 buffer registration.

### Producer Agent outline

```julia
struct AppProducerAgent
    producer::ProducerState
    control_asm::Aeron.FragmentAssembler
    qos_asm::Aeron.FragmentAssembler
end

Agent.name(::AppProducerAgent) = "app-producer"

function Agent.do_work(agent::AppProducerAgent)
    # Application-defined work loop
    payload = agent.producer.runtime.payload_buf
    # fill payload with a known pattern...
    offer_frame!(agent.producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
    return producer_do_work!(agent.producer, agent.control_asm; qos_assembler = agent.qos_asm)
end
```

### Working example script

```bash
julia --project scripts/example_producer.jl \
  docs/examples/driver_integration_example.toml \
  config/defaults.toml \
  0 1048576
```

Arguments:
- Driver config path
- Producer config path
- Frame count (0 = run forever)
- Payload bytes (default: first pool stride)

Notes:
- You can keep the application-defined Agent and call `ProducerAgent` in invoker mode
  (i.e., directly call `Agent.do_work`) if you want to avoid a second runner.
- For BGAPI2, use the same attach flow then register SHM slots as camera buffers.

## Application 3: Frame Consumer (application-defined Agent)

The application defines its own Agent, runs it with an `AgentRunner`, and uses
the driver client API to attach and map SHM. The example below verifies a known
pattern, but the handler can perform any processing.

### Consumer Agent outline

```julia
struct AppConsumerAgent
    consumer::ConsumerState
    desc_asm::Aeron.FragmentAssembler
    ctrl_asm::Aeron.FragmentAssembler
end

Agent.name(::AppConsumerAgent) = "app-consumer"

function Agent.do_work(agent::AppConsumerAgent)
    consumer_do_work!(agent.consumer, agent.desc_asm, agent.ctrl_asm)
    view = agent.consumer.runtime.frame_view
    # process payload view...
    return 1
end
```

### Working example script

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

Notes:
- You can keep the application-defined Agent and call `ConsumerAgent` in invoker mode
  if you want to avoid a second runner.
- The example consumer verifies the byte pattern and prints `frame=<id> ok`.
- Consumers must treat `FrameDescriptor` as the canonical availability signal.

## Manual BGAPI2 Integration (outline)

To integrate with a camera SDK that accepts pre-registered buffers (e.g., BGAPI2),
use the same attach flow as the example producer, but replace the generator loop:

1) Reserve slots via `try_claim_slot!` and register each slot pointer with the camera.
2) On frame completion, call `commit_slot!` with the known shape/strides.
3) Requeue the slot by claiming a new slot or reusing the completed claim.

## Summary

- The driver owns SHM allocation and announces layout via `ShmPoolAnnounce`.
- Producers/consumers attach via the driver client API and map SHM from responses.
- The example producer/consumer scripts are a working end-to-end reference.

## C ↔ Julia Interop Helpers

These scripts align the C client env vars with a driver config and provide
end-to-end smoke checks.

### Export interop env (shared between C and Julia)

```bash
eval "$(scripts/interop_env.sh docs/examples/driver_integration_example.toml docs/examples/interop_env_example.toml)"
```

### C integration smoke (attach + claim + commit + read)

```bash
scripts/run_c_integration_smoke.sh docs/examples/driver_integration_example.toml c/build
```

### Interop sweep (driver + C smoke + Julia consumer/producer)

```bash
scripts/run_interop_all.sh docs/examples/driver_integration_example.toml c/build
```

Defaults:
- `TP_INTEROP_USE_EMBEDDED=1` (starts a standalone MediaDriver via `scripts/run_media_driver.jl` with a temp `AERON_DIR`)
- `TP_INTEROP_TIMEOUT_S=30`

### Cross-check C ↔ Julia (C producer → Julia consumer, Julia producer → C consumer)

```bash
scripts/run_interop_crosscheck.sh docs/examples/driver_integration_example.toml c/build
```

### Inspect endpoints and live attach response

```bash
scripts/interop_print_endpoints.sh docs/examples/driver_integration_example.toml docs/examples/interop_env_example.toml
```

### Decode raw control-plane messages

```bash
scripts/interop_decode_message.jl /path/to/buffer.bin
scripts/interop_decode_message.jl hex:01020304
```
