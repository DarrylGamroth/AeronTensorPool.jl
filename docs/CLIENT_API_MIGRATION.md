# Client API Migration Guide

This guide maps prior low-level usage to the new Aeron-aligned client API.

## Core Entry Point

- Old: manual Aeron client + driver/discovery client wiring
- New: `TensorPoolContext` + `connect(ctx)`

```julia
ctx = TensorPoolContext(endpoints; discovery_channel = "aeron:ipc", discovery_stream_id = 16000)
client = connect(ctx)
```

## Attach (Sync)

- Old: `init_driver_client` + `send_attach_request!` + `poll_attach!`
- New: `attach_consumer` / `attach_producer`

```julia
consumer = attach_consumer(client, consumer_settings; discover = true)
producer = attach_producer(client, producer_config; discover = false)
```

## Attach (Async)

- Old: manual correlation handling
- New: `request_attach_consumer` / `request_attach_producer` + `poll_attach`

```julia
req = request_attach_consumer(client, settings)
resp = poll_attach(req)
```

## Work Loop

- Old: `consumer_do_work!` / `producer_do_work!`
- New: `do_work(handle)`

```julia
do_work(consumer)
do_work(producer)
```

## Close

- Old: close pubs/subs manually
- New: `close(handle)` and `close(client)`

```julia
close(consumer)
close(client)
```

## Discovery

- Old: `init_discovery_client` + `discover_streams!` + `poll_discovery_response!`
- New: `attach_*` with `discover=true` (uses context discovery settings)

## Notes

- Invoker mode uses `do_work(client)` when `use_invoker=true`.
- Low-level client/agent types remain available, but the high-level client API is the preferred entry point.
