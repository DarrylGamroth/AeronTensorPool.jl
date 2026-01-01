# Integration Examples

These examples show how to embed AeronTensorPool in an application loop or connect a camera driver that expects pre-registered buffers.

## BGAPI2 Producer (Standalone, DMA Into Shared Slots)

Goal: hand SHM payload slots to BGAPI2 so the device DMA fills them, then publish the descriptor after completion.

Outline:
1) Initialize a ProducerState and map SHM pools via `init_producer`.
2) Select a pool_id with stride_bytes >= max payload.
3) Reserve slots and give their pointers to BGAPI2 as DMA buffers.
4) On frame completion, call `publish_reservation!` with the known shape/strides.

Sketch (pseudo-code, not executable):

```julia
state = init_producer(cfg)
pool_id = UInt16(1)
inflight = InflightQueue(cfg.nslots)

# Pre-register buffers with BGAPI2
for _ in 1:cfg.nslots
    reservation = reserve_slot!(state, pool_id)
    inflight_push!(inflight, reservation)
    # Provide reservation.ptr and reservation.stride_bytes to BGAPI2 buffer registration.
end

while running
    # BGAPI2 signals a completed buffer; you map it back to the reservation.
    reservation = inflight_pop!(inflight)
    values_len = actual_bytes_from_device()
    shape = Int32[height, width]
    strides = Int32[width, 1]
    ok = publish_reservation!(state, reservation, values_len, shape, strides, Dtype.UINT8, meta_version)
    ok || handle_publish_failure()
    inflight_push!(inflight, reserve_slot!(state, pool_id))
end
```

Notes:
- `publish_reservation!` enforces frame_id == seq and header_index mapping.
- If device completion order differs from reservation order, use a mapping from device buffer ID to SlotReservation.
- For fixed-size frames, you can set shape/strides once and reuse.

## GenICamServer Integration (Invoker Mode, Standalone)

Goal: run producer/consumer/supervisor in an application loop without a dedicated agent runner.

Pattern:
- Call `*_do_work!` from your host loop (e.g., GenICamServer.jl tick).
- Fetch clocks once per tick; pass now_ns through to the worker functions.

Sketch:

```julia
producer = init_producer(prod_cfg)
consumer = init_consumer(cons_cfg)
supervisor = init_supervisor(sup_cfg)

prod_ctrl = make_control_assembler(producer)
cons_desc = make_descriptor_assembler(consumer)
cons_ctrl = make_control_assembler(consumer)
sup_ctrl = make_control_assembler(supervisor)
sup_qos = make_qos_assembler(supervisor)

while running
    producer_do_work!(producer, prod_ctrl)
    consumer_do_work!(consumer, cons_desc, cons_ctrl)
    supervisor_do_work!(supervisor, sup_ctrl, sup_qos)
    yield()
end
```

Notes:
- Invoker mode avoids an AgentRunner; it is appropriate when you already manage a main loop.
- If you run only producer+consumer, the supervisor is optional; you lose centralized QoS and config updates.

## Driver-Mode Producer/Consumer (Attach + Keepalive)

Goal: attach via the SHM driver and map driver-owned regions before producing/consuming.

Sketch:

```julia
driver_client = init_driver_client(client, "aeron:ipc", Int32(1000), UInt32(7), DriverRole.PRODUCER)
consumer_client = init_driver_client(client, "aeron:ipc", Int32(1000), UInt32(21), DriverRole.CONSUMER)

prod_attach_id = send_attach_request!(driver_client; stream_id = UInt32(42))
cons_attach_id = send_attach_request!(consumer_client; stream_id = UInt32(42))

prod_attach = await_attach!(driver_client, clock, prod_attach_id)
cons_attach = await_attach!(consumer_client, clock, cons_attach_id)

producer = init_producer_from_attach(prod_cfg, prod_attach; driver_client = driver_client)
consumer = init_consumer_from_attach(cons_cfg, cons_attach; driver_client = consumer_client)

prod_ctrl = make_control_assembler(producer)
cons_desc = make_descriptor_assembler(consumer)
cons_ctrl = make_control_assembler(consumer)

while running
    producer_do_work!(producer, prod_ctrl)
    consumer_do_work!(consumer, cons_desc, cons_ctrl)
    yield()
end
```

Notes:
- The driver owns SHM layout/paths; clients must not create or truncate SHM files.
- Keepalives are sent automatically by `driver_client_do_work!` (called inside `*_do_work!`).

## BGAPI2 Producer (Driver Mode)

Use the attach response to map driver-owned SHM, then hand slot pointers to BGAPI2.

```julia
driver_client = init_driver_client(client, "aeron:ipc", Int32(1000), UInt32(7), DriverRole.PRODUCER)
attach_id = send_attach_request!(driver_client; stream_id = UInt32(42))
attach = await_attach!(driver_client, clock, attach_id)
state = init_producer_from_attach(cfg, attach; driver_client = driver_client)

pool_id = UInt16(1)
inflight = InflightQueue(state.config.nslots)
for _ in 1:state.config.nslots
    res = reserve_slot!(state, pool_id)
    inflight_push!(inflight, res)
    # Register res.ptr/res.stride_bytes with BGAPI2.
end
```

## Driver Deployment Example

- Config file: `docs/examples/driver_camera_example.toml`
- One-shot launcher: `scripts/run_all_driver.sh docs/examples/driver_camera_example.toml`
- CLI attach/keepalive/detach: `scripts/tp_tool.jl driver-attach|driver-keepalive|driver-detach`
