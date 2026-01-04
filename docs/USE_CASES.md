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
    offer_frame!(state, payload, shape, strides, Dtype.UINT8, meta_version)

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
## Extras

### Claim helper (multiple in-flight buffers)

Use a claim to keep the slot/seq pairing explicit:

```julia
claim = try_claim_slot!(state, pool_id)
# Register claim.ptr with the device. Use claim.stride_bytes for size.
```

On completion:

```julia
commit_slot!(
    state,
    claim,
    values_len,
    shape,
    strides,
    Dtype.UINT8,
    meta_version,
)
```
