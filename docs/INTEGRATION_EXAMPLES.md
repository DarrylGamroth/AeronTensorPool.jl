# Integration Examples

This document shows a concrete, end-to-end integration using three applications:
1) Driver
2) Frame Producer (BGAPI2-backed)
3) Frame Consumer

The example uses the driver model and the client API to attach to driver-provisioned SHM.

## Application 1: Driver

### Example driver config

Create `docs/examples/driver_integration_example.toml`:

```toml
[driver]
instance_id = "driver-example"
aeron_dir = ""
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
stream_id = 42
profile = "camera"
```

### Start driver

```bash
julia --project scripts/run_role.jl driver docs/examples/driver_integration_example.toml
```

## Application 2: Frame Producer (BGAPI2)

Goal: attach to the driver, register SHM payload buffers with BGAPI2, then publish frames on completion.

Sketch:

```julia
using Aeron
using AeronTensorPool
# using BGAPI2  # pseudo-code

ctx = Aeron.Context()
client = Aeron.Client(ctx)

driver_client = init_driver_client(client, "aeron:ipc", Int32(15000), UInt32(7), DriverRole.PRODUCER)
attach_id = send_attach_request!(driver_client; stream_id = UInt32(42))

attach = nothing
while attach === nothing
    attach = poll_attach!(driver_client, attach_id, UInt64(time_ns()))
    yield()
end

prod_cfg = load_producer_config("config/defaults.toml")
producer = init_producer_from_attach(prod_cfg, attach; driver_client = driver_client, client = client)
ctrl_asm = make_control_assembler(producer)

pool_id = UInt16(1)
inflight = InflightQueue(producer.config.nslots)

# Pre-register buffers with BGAPI2
for _ in 1:producer.config.nslots
    res = reserve_slot!(producer, pool_id)
    push!(inflight, res)
    # BGAPI2.register_buffer!(res.ptr, res.stride_bytes)
end

while running
    # BGAPI2 callback returns the buffer id you registered; map it to SlotReservation.
    res = popfirst!(inflight)
    values_len = actual_bytes_from_device()
    shape = Int32[height, width]
    strides = Int32[width, 1]
    ok = publish_reservation!(producer, res, values_len, shape, strides, Dtype.UINT8, UInt32(0))
    ok || handle_publish_failure()
    push!(inflight, reserve_slot!(producer, pool_id))

    producer_do_work!(producer, ctrl_asm)
    yield()
end
```

Notes:
- If the device completes buffers out-of-order, keep a lookup from device buffer ID to SlotReservation.
- Use `reserve_slot!` and `publish_reservation!` to avoid extra copies and preserve seqlock order.

## Application 3: Frame Consumer

Goal: attach to the driver, map SHM regions, and process frames.

Sketch:

```julia
using Aeron
using AeronTensorPool

ctx = Aeron.Context()
client = Aeron.Client(ctx)

driver_client = init_driver_client(client, "aeron:ipc", Int32(15000), UInt32(21), DriverRole.CONSUMER)
attach_id = send_attach_request!(driver_client; stream_id = UInt32(42))

attach = nothing
while attach === nothing
    attach = poll_attach!(driver_client, attach_id, UInt64(time_ns()))
    yield()
end

cons_cfg = load_consumer_config("config/defaults.toml")
consumer = init_consumer_from_attach(cons_cfg, attach; driver_client = driver_client, client = client)
desc_asm = make_descriptor_assembler(consumer)
ctrl_asm = make_control_assembler(consumer)

while running
    consumer_do_work!(consumer, desc_asm, ctrl_asm)

    view = consumer.runtime.frame_view
    if view.header.frame_id != 0
        payload = payload_view(view.payload)
        # process payload (e.g., checksum, log, or copy out)
    end

    yield()
end
```

Notes:
- `consumer_do_work!` updates `consumer.runtime.frame_view` when a frame is accepted.
- Consumers must treat `FrameDescriptor` as the canonical availability signal.

## Summary

- The driver owns SHM allocation and announces layout via `ShmPoolAnnounce`.
- Producers/consumers attach via the driver client API and map SHM from responses.
- Producers can hand SHM slots directly to BGAPI2 for DMA, then publish descriptors when complete.
