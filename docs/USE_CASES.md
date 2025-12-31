# Use Cases (Aeron Tensor Pool, Julia)

## Integrate into a server application (GenICamServer-style)

Embed the producer/consumer agents inside your app and drive them from your main loop.

```julia
state = init_producer(cfg)

while running
    # Poll control subscriptions if you have them.
    # poll_control!(state, control_asm)

    # Handle frame acquisition (copy path).
    payload = get_frame_bytes()
    publish_frame!(state, payload, shape, strides, Dtype.UINT8, meta_version)

    # Periodic announce/QoS.
    emit_periodic!(state)
end
```

This keeps Aeron + SHM management inside AeronTensorPool and lets your server own device control and lifecycle.

## Device DMA into SHM (BGAPI2-style)

Register SHM payload slots as device buffers, then publish descriptors when DMA completes.

```julia
pool_id = UInt16(1)
slot = next_header_index(state)
ptr, stride = payload_slot_ptr(state, pool_id, slot)

# Register (ptr, stride) as a DMA buffer with the device SDK.
```

When the device signals completion:

```julia
publish_frame_from_slot!(
    state,
    pool_id,
    slot,
    values_len,
    shape,
    strides,
    Dtype.UINT8,
    meta_version,
)
```

Notes
- In v1.1, `payload_slot == header_index` is required; use `next_header_index` before handing the buffer to the device.
- If you need multiple in-flight DMA buffers, reserve the next slot in order and publish in the same order to avoid seq gaps.

## Reservation helper (multiple in-flight buffers)

Use a reservation to keep the slot/seq pairing explicit:

```julia
reservation = reserve_slot!(state, pool_id)
# Register reservation.ptr with the device. Use reservation.stride_bytes for size.
```

On completion:

```julia
publish_reservation!(
    state,
    reservation,
    values_len,
    shape,
    strides,
    Dtype.UINT8,
    meta_version,
)
```
