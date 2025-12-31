# Integration Examples

These examples show how to embed AeronTensorPool in an application loop or connect a camera driver that expects pre-registered buffers.

## BGAPI2 Producer (DMA Into Shared Slots)

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

## GenICamServer Integration (Invoker Mode)

Goal: run producer/consumer/supervisor in an application loop without a dedicated agent runner.

Pattern:
- Call `*_do_work!` from your host loop (e.g., GenICamServer.jl tick).
- Fetch clocks once per tick; pass now_ns through to the worker functions.

Sketch:

```julia
producer = init_producer(prod_cfg)
consumer = init_consumer(cons_cfg)
supervisor = init_supervisor(sup_cfg)

while running
    now_ns = UInt64(Clocks.time_nanos(producer.clock))
    producer_do_work!(producer, now_ns)
    consumer_do_work!(consumer, now_ns)
    supervisor_do_work!(supervisor, now_ns)
end
```

Notes:
- Invoker mode avoids an AgentRunner; it is appropriate when you already manage a main loop.
- If you run only producer+consumer, the supervisor is optional; you lose centralized QoS and config updates.
