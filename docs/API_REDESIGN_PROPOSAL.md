# Julia Client API Redesign Proposal (Doc-Only)

This document proposes a clean, idiomatic Julia client API for AeronTensorPool.
It is based on lessons captured in `docs/API_ERGONOMICS.md` and the
kitchen-sink examples (`scripts/example_producer.jl`,
`scripts/example_consumer.jl`). No code changes are implied; this is a design
target.

## Goals

- Idiomatic Julia (no fluent/builder chaining).
- Aeron-style mental model: Context → Client → explicit poll → explicit close.
- Minimize boilerplate around driver endpoints, QoS, and metadata.
- Keep hot-path operations explicit and allocation-free.
- Hot-path producer/consumer calls MUST remain zero-allocation after initialization.

## Proposed API Surface

### Core Types

- `Context`: runtime configuration (channels, stream IDs, discovery)
- `Client`: connects to Aeron and control plane
- `Producer`: handle for producing frames
- `Consumer`: handle for consuming frames

### Attach Functions

```julia
producer = attach_producer(client, producer_cfg; qos=true, metadata=true)
consumer = attach_consumer(client, consumer_cfg; qos=true, metadata=true)
```

Behavior:
- `qos=true` creates a `QosMonitor` owned by the handle.
- `metadata=true` creates a `MetadataCache` (consumer) or metadata publisher
  helpers (producer).

### Config Helpers

```julia
producer_cfg = with_driver_endpoints(producer_cfg, driver_cfg)
consumer_cfg = with_driver_endpoints(consumer_cfg, driver_cfg)
```

This eliminates manual copying of control/qos/metadata endpoints.

### Status Helpers

```julia
status = handle_status(producer)  # cached immutable status
```

Designed for logging without repeated `handle_state` lookups.

### Metadata Helpers (Unified)

Replace `set_metadata_attributes!` with a single function name and use
multiple dispatch (or varargs) for batching:

```julia
set_metadata_attribute!(producer, attr::MetadataAttribute)
set_metadata_attribute!(producer, attrs::AbstractVector{MetadataAttribute})
# allow pairs directly
set_metadata_attribute!(producer, pair::Pair{<:AbstractString, <:Tuple})
set_metadata_attribute!(producer, pairs::AbstractVector{<:Pair})
# optional convenience:
set_metadata_attribute!(producer, attrs::MetadataAttribute...)
```

### Agent/Runner Helper

```julia
runner = run!(producer, app_agent; idle_strategy=BackoffIdleStrategy(), core_id=nothing)
```

Creates a CompositeAgent with the handle’s internal agent and the user agent,
starts an `AgentRunner`, and returns it for explicit lifecycle control.
This is an optional convenience; users can build the runner manually.

`core_id` is an optional CPU pinning hint. If `nothing`, the runner thread is not pinned.

The helper should also support `AgentInvoker` use (e.g., return a CompositeAgent
or expose a `run!` variant that yields an invoker-friendly object).

### Explicit Lifecycle

```julia
close!(producer)
close!(consumer)
close!(client)
```

## Example: Producer (Target Shape)

```julia
ctx = Context(driver_cfg.endpoints; aeron_dir=aeron_dir)
client = connect(ctx)
producer_cfg = with_driver_endpoints(producer_cfg, driver_cfg)

producer = attach_producer(client, producer_cfg; qos=true, metadata=true)
announce_data_source!(producer, "example-producer")
set_metadata_attribute!(producer, attrs)

runner = run!(producer, app_agent)
wait(runner)

close!(producer)
close!(client)
```

## Example: Consumer (Target Shape)

```julia
ctx = Context(driver_cfg.endpoints; discovery_channel=discovery_channel)
client = connect(ctx)
consumer_cfg = with_driver_endpoints(consumer_cfg, driver_cfg)

consumer = attach_consumer(client, consumer_cfg; qos=true, metadata=true)
runner = run!(consumer, app_agent)
wait(runner)

close!(consumer)
close!(client)
```

## Lessons Incorporated

- Avoid manual endpoint patching by adding `with_driver_endpoints`.
- Make QoS/metadata optional but ergonomic.
- Keep polling/agent lifecycle explicit (Aeron style).
- Provide a single, stable attach entrypoint per role.

## Non-Goals

- No fluent/builder API.
- No hidden background tasks.
- No implicit global state.

## Proposed Final Surface (Breaking Changes OK)

Keep as canonical:
- `Context`, `Client`
- `attach_producer`, `attach_consumer`
- `request_attach_producer`, `request_attach_consumer` (low-level)
- `poll_attach!` (low-level)
- `do_work`, `driver_client_do_work!`
- `close!` for handles and client
- `offer_frame!`, `try_claim_slot!`, `try_claim_slot_by_size!`, `commit_slot!`,
  `with_claimed_slot!`
- `set_metadata_attribute!` (single name, multi-dispatch + varargs)
- `announce_data_source!`, `metadata_version`, `set_metadata!`
- `poll_qos!`, `producer_qos`, `consumer_qos`

Remove or move to `LowLevel`:
- `set_metadata_attributes!` (replaced)
- Any duplicate alias names once canonical names are chosen
- Any attach wrappers that only forward to `attach_*` without adding behavior

Optional convenience helpers:
- `with_driver_endpoints`
- `handle_status`
- `run!` (agent runner convenience)

## Cleanup and Teardown

Explicitly document shutdown order to avoid dangling keepalives or background
pollers:

1. `close!(producer)` / `close!(consumer)` — stop agents, QoS/metadata helpers.
2. `close!(client)` — close Aeron client and control-plane resources.
3. Optional: `close!(runner)` if an explicit runner is used.

Handles should be idempotent to close; repeated `close!` calls must be safe.

## Callback Redesign (Aeron-Style)

Use a single callbacks struct with explicit return codes, similar to Aeron
`ControlledFragmentHandler`:

```julia
@enum CallbackAction::UInt8 begin
    CONTINUE = 0
    ABORT    = 1
    BREAK    = 2
    COMMIT   = 3
end

struct ClientCallbacks
    on_frame!::Function        # (state, frame) -> CallbackAction
    on_qos_producer!::Function # (state, snapshot) -> CallbackAction
    on_qos_consumer!::Function # (state, snapshot) -> CallbackAction
    on_metadata!::Function     # (state, entry) -> CallbackAction
end
```

Rules:
- Callbacks run on the agent thread; MUST be non-allocating and non-blocking.
- `CONTINUE` is the default action.
- `ABORT` means re-deliver the same event later.
- `BREAK` means stop polling for this work cycle.
- `COMMIT` can be reserved for future use or treated as `CONTINUE`.

If no callbacks are provided, default to no-op handlers that return `CONTINUE`.

## Targeted Improvements (QoS, Discovery, Producer/Consumer)

### QoS
- Provide `poll_qos!(handle)` that updates both producer/consumer QoS and
  returns a single summary struct (or `nothing`).
- Keep QoS helpers non-throwing; return `nothing` when no data is available.
- Make QoS polling cadence explicit in handle config instead of external timers.

### Discovery
- Define a `DiscoveryBackend` interface with a single
  `discover_stream!(backend, criteria)` entrypoint.
- Expose explicit freshness/staleness policy on the client (`freshness_ns`,
  `drop_stale::Bool`).

### Producer/Consumer
- Add `handle_status(handle)` for lightweight logging snapshots.
- Ensure `close!(handle)` tears down internal timers and agent state cleanly.
- Provide `with_driver_endpoints(config, driver_cfg)` to reduce config boilerplate.

## Interface Seams (Swappable Implementations)

Define minimal interfaces to allow swapping implementations without touching
the hot path. The following are conceptual contracts (signatures shown in
Julia-ish pseudocode).

### ControlPlaneTransport

```
send_request!(transport, msg) -> correlation_id::Int64
poll_response!(transport, correlation_id::Int64, now_ns::UInt64) -> Union{AttachResponse,Nothing}
send_keepalive!(transport, lease_id::UInt64, now_ns::UInt64) -> Bool
```

### ClockProvider (Clocks.jl)

Use Clocks.jl to provide monotonic and cached timestamps:

```
now_ns(clock::MonotonicClock) -> UInt64
now_ns(clock::CachedEpochClock) -> UInt64
```

### QosSink

```
record_qos!(sink, snapshot) -> nothing
```

### MetadataStore

```
publish_metadata!(store, stream_id, attributes) -> nothing  # attributes: Pair/MetadataAttribute collection
poll_metadata!(store) -> nothing
lookup_metadata(store, stream_id) -> entry_or_nothing
```

### AgentDriver

```
start!(driver, agent) -> handle
do_work!(driver, agent) -> Int
stop!(driver, handle) -> nothing
```

### SHMBackend

```
map_region!(backend, uri, bytes) -> buffer
unmap_region!(backend, buffer) -> nothing
validate_region!(backend, superblock, announce) -> Union{Nothing,ValidationError}
```

### CounterBackend

```
counter!(backend, name, label) -> counter_handle
inc!(counter_handle, delta::Int64=1) -> nothing
set!(counter_handle, value::Int64) -> nothing
```
