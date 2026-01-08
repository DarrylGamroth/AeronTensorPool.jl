# Client Quickstart

This quickstart shows the minimal flow to attach, publish, and consume frames using the client API. It also shows the optional `ClientCallbacks` facade for wiring common callbacks.

## 1) Connect to the driver

```julia
using AeronTensorPool

driver_cfg = load_driver_config("docs/examples/driver_integration_example.toml")
ctx = TensorPoolContext(driver_cfg.endpoints)
client = connect(ctx)
```

## 2) Attach a producer

```julia
producer_cfg = load_producer_config("config/defaults.toml")

callbacks = ClientCallbacks(
    producer = ProducerCallbacks(
        on_frame_published! = (_, seq, header_index) ->
            @info "frame published" seq header_index,
    ),
)

producer = attach_producer(client, producer_cfg; callbacks = callbacks)
```

## 3) Attach a consumer

```julia
consumer_cfg = load_consumer_config("config/defaults.toml")

callbacks = ClientCallbacks(
    consumer = ConsumerCallbacks(
        on_frame! = (_, frame) -> begin
            payload = Consumer.payload_view(frame.payload)
            @info "frame ok" bytes = length(payload)
        end,
    ),
)

consumer = attach_consumer(client, consumer_cfg; callbacks = callbacks)
```

## 4) Publish a frame

```julia
payload = fill(UInt8(1), 1024)
shape = Int32[1024]
strides = Int32[1]
offer_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
```

## 5) Cleanup

```julia
close(producer)
close(consumer)
close(client)
```

## Notes

- `ClientCallbacks` is optional. You can pass `ConsumerCallbacks` or `ProducerCallbacks` directly to `attach_consumer`/`attach_producer`.
- For external devices (zero-copy), use `try_claim_slot!` or `try_claim_slot_by_size!` and then `commit_slot!`.
- If you use discovery, pass `discover=true` and a `data_source_name` to the attach call.
