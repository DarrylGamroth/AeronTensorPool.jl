# Julia API Ergonomics (AeronTensorPool)

This note outlines API ergonomics guidance for the Julia client API. It aims to
stay familiar to Aeron users while remaining idiomatic Julia (no fluent/builder
style).

## Principles

- Keep Aeron-style mental models: Context + Client + explicit poll + explicit
  close.
- Prefer simple functions and plain data structs over fluent/builder chains.
- Use `!` for mutating operations and explicit resource lifecycle.
- Provide clear, stable error types for attach/poll failures.

## Naming and Structure

- Use short, Aeron-familiar names as aliases:
  - `TensorPoolContext` → `Context` (alias)
  - `TensorPoolClient` → `Client` (alias)
  - `attach_producer` / `attach_consumer` → `add_publication` / `add_subscription`
    (aliases only; keep existing names)
- Keep the current explicit role functions as the primary API surface.

## Attach Workflow (Idiomatic Julia)

Preferred flow:

```julia
ctx = TensorPoolContext(...)
client = TensorPoolClient(ctx)

producer = attach_producer(client, producer_config)
consumer = attach_consumer(client, consumer_config)
```

Optional lower-level flow (explicit polling):

```julia
req = request_attach_producer(client, producer_config)
while (attach = poll_attach!(req)) === nothing
    do_work(client)
end
```

No fluent/builder chains; keep functions and structs explicit.

## End-to-End Workflow (Kitchen-Sink)

This flow mirrors `scripts/example_producer.jl` and
`scripts/example_consumer.jl` and highlights where the API could be streamlined.

### Producer workflow

1. Load driver + producer config.
2. Override producer config with driver endpoints (control/qos channels).
3. Build `TensorPoolContext` and `connect`.
4. Create `QosMonitor` (optional) and metadata attributes.
5. `attach_producer` to obtain `ProducerHandle`.
6. Announce data source + publish metadata.
7. Run agent loop (CompositeAgent with app logic + handle agent).
8. Close handle and client.

### Consumer workflow

1. Load driver + consumer config.
2. Override consumer config with driver endpoints.
3. Build `TensorPoolContext` and `connect` (optionally discovery channel).
4. `attach_consumer` to obtain `ConsumerHandle`.
5. Create `QosMonitor` + `MetadataCache`.
6. Run agent loop (CompositeAgent).
7. Close metadata, qos, handle, and client.

## Warts Observed in Examples

These are not bugs, but places where the API is more verbose than needed:

- **Manual config overrides**: examples copy driver endpoints into producer/
  consumer config fields before attach.
- **Discovery opt-in**: discovery toggling requires manual channel/stream setup.
- **Repeated `handle_state` access**: callers often fetch state repeatedly for
  logging; a cached snapshot helper would reduce boilerplate.
- **Manual QoS + metadata setup**: consumers must explicitly construct and poll
  `QosMonitor` and `MetadataCache`.
- **Agent plumbing**: user app logic must be wrapped in CompositeAgent to share
  the handle’s internal agent loop.

## Suggested Streamlining (Still Aeron-Style)

These changes keep explicit lifecycle and polling but reduce boilerplate:

- Add a `with_driver_endpoints(config, driver_cfg)` helper to apply endpoint
  overrides consistently for producer/consumer configs.
- Provide optional `attach_consumer(...; qos=true, metadata=true)` convenience
  to create and own `QosMonitor`/`MetadataCache`.
- Add `handle_snapshot(handle)` returning a cached immutable snapshot for
  logging and diagnostics.
- Add `run!(handle, app_agent)` wrapper that builds the CompositeAgent and
  starts a runner (still explicit; no background threads unless called).

## Resource Lifecycle

- Provide explicit `close!(handle)` for producer/consumer handles.
- Keep `do_work(client)` as the explicit poll loop entrypoint.

## Polling and Work Loops

- Offer `poll(handle, fragment_limit)` style helpers as thin wrappers around
  `do_work` to mirror Aeron’s polling patterns.
- Keep `driver_client_do_work!` available for low-level control-plane polling.

## Errors

- Export stable error types: `AttachTimeoutError`, `AttachRejectedError`,
  `ProtocolError`.
- Prefer throwing on unrecoverable control-plane failures; encourage explicit
  retry loops in user code.

## Notes

- Keep control-plane and data-plane helpers distinct; avoid implicit background
  tasks unless explicitly enabled.
- Do not hide Aeron-like lifecycle (initialize → poll → close) behind magic.
