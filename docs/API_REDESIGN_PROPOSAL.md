# Julia Client API Redesign Proposal (Doc-Only)

This document proposes a clean, idiomatic Julia client API for AeronTensorPool.
It is based on lessons captured in `docs/API_ERGONOMICS.md` and the
kitchen-sink examples (`scripts/example_producer.jl`,
`scripts/example_consumer.jl`). No code changes are implied; this is a design
target.

The SHM_* specification files in `docs/` are authoritative for implementation
details. If any ambiguity arises, default to Aeron-style API choices unless a
spec explicitly states otherwise.

## Goals

- Idiomatic Julia (no fluent/builder chaining).
- Aeron-style mental model: Context → Client → explicit poll → explicit close.
- Minimize boilerplate around driver endpoints, QoS, and metadata.
- Keep hot-path operations explicit and allocation-free.
- Hot-path producer/consumer calls MUST remain zero-allocation after initialization.
- Mirror Aeron.jl naming and lifecycle patterns where practical, while staying idiomatic Julia.

## Proposed API Surface

### Core Types

- `Context`: runtime configuration (channels, stream IDs, discovery)
- `Client`: connects to Aeron and control plane
- `Producer`: handle for producing frames
- `Consumer`: handle for consuming frames
- `ClientConductor`: per-client agent that drives polling and control-plane work

### Aeron Naming Alignment (Selected)

- Prefer `MessageHandler` / `ControlledMessageHandler` over `FragmentHandler`
  since ATP operates on decoded messages, not raw fragments.
- Do not expose `Image` unless per-image state becomes a user-facing concept.

### Attach Functions

```julia
producer = attach_producer(client, producer_cfg; qos=true, metadata=true)
consumer = attach_consumer(client, consumer_cfg; qos=true, metadata=true)
```

Behavior:
- `qos=true` creates a `QosMonitor` owned by the handle.
- `metadata=true` creates a `MetadataCache` (consumer) or metadata publisher
  helpers (producer).

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
close(producer)
close(consumer)
close(client)
```

## Example: Producer (Target Shape)

```julia
ctx = Context(driver_cfg.endpoints; aeron_dir=aeron_dir)
client = connect(ctx)

producer = attach_producer(client, producer_cfg; qos=true, metadata=true)
announce_data_source!(producer, "example-producer")
set_metadata_attribute!(producer, attrs)

runner = run!(producer, app_agent)
wait(runner)

close(producer)
close(client)
```

## Example: Consumer (Target Shape)

```julia
ctx = Context(driver_cfg.endpoints; discovery_channel=discovery_channel)
client = connect(ctx)

consumer = attach_consumer(client, consumer_cfg; qos=true, metadata=true)
runner = run!(consumer, app_agent)
wait(runner)

close(consumer)
close(client)
```

## Config-less API Variant (Aeron-Style)

Prefer programmatic configuration with kwargs and defaults from
`docs/STREAM_ID_CONVENTIONS.md`:

```julia
ctx = Context(; aeron_dir="...", control_channel="aeron:ipc?term-length=4m")
client = connect(ctx)

producer = attach_producer(client; stream_id=10000, producer_id=1)
consumer = attach_consumer(client; stream_id=10000, consumer_id=2)
```

Defaults (if not specified):
- `control_stream_id = 1000`
- `descriptor_stream_id = 1100`
- `qos_stream_id = 1200`
- `metadata_stream_id = 1300`
- Channels default to `control_channel` unless overridden.

### Discovery Example

```julia
entry = discover_stream!(client; data_source_name="camera-1")
producer = attach_producer(client, entry; producer_id=1)
```

Preferred overload (explicit, idiomatic):

```julia
entry = discover_stream!(client; data_source_name="camera-1")
producer = attach_producer(client, entry; producer_id=1)
consumer = attach_consumer(client, entry; consumer_id=2)
```

Use accessor functions for discovery entries; avoid direct field access to keep
the entry representation opaque.

## Additional Recommendations

- Provide `poll!(client, fragment_limit)` and `poll!(handle, fragment_limit)`
  helpers that return work counts for idle strategy integration.
- Allow attach timeouts via kwargs:
  `attach_producer(...; timeout_ns=..., retry_ns=...)`.
- Consolidate attach errors into a small typed error hierarchy or enum for
  consistent handling and logging.
- Add `Base.show` methods for Context/Client/Handle/DiscoveryEntry to improve
  REPL diagnostics (keep them concise and non-allocating in hot paths).
- Consider a `LowLevel` namespace for request/poll/claim helpers to keep the
  primary API surface small.

## Phased Implementation Plan

Phase 0 — Decisions & Doc Updates
- Replace any fragment terminology with `MessageHandler` / `ControlledMessageHandler`.
- Keep programmatic API only; remove config-based examples.
- Lock in control-plane polling split (attach/detach/revoke/shutdown).

Phase 1 — Core Types & Lifecycle
- Introduce `ClientConductor` as the per-client agent loop.
- Standardize on `Base.close` for all user-facing types; ensure idempotency.
- Add `handle_status(handle)` and `poll!(handle, fragment_limit)`.

Phase 2 — Attach API + Discovery
- Implement kwargs-based `attach_producer/attach_consumer` with defaults from
  `STREAM_ID_CONVENTIONS.md`.
- Add overloads: `attach_producer(client, entry::DiscoveryEntry; ...)`.
- Enforce accessor-only access to user-facing types.

Phase 3 — Callbacks & Type Stability
- Implement `ClientCallbacks{F1,F2,F3,F4}` with functor defaults.
- Add `CallbackAction` and controlled message handling semantics.
- Parameterize handles on callback types to avoid boxing.

Phase 4 — QoS/Metadata Ergonomics
- Unify `set_metadata_attribute!` with multiple dispatch/varargs.
- Add `poll_qos!(handle)` returning a concrete snapshot or `nothing`.
- Define `MetadataStore` and `QosSink` interfaces.

Phase 5 — Interface Seams
- Implement `ControlPlaneTransport`, `SHMBackend`, `CounterBackend` seams.
- Provide Aeron/SBE/SHM implementations behind these interfaces.

Phase 6 — Validation & Performance
- Add zero-allocation checks for hot-path entrypoints.
- Add `@code_warntype` checks for key APIs.
- Update examples to use programmatic + discovery-entry flows only.

## Lessons Incorporated

- Make QoS/metadata optional but ergonomic.
- Keep polling/agent lifecycle explicit (Aeron style).
- Provide a single, stable attach entrypoint per role.

## Non-Goals

- No fluent/builder API.
- No hidden background tasks.
- No implicit global state.

## Encapsulation Guidelines

- Prefer accessor functions over direct field access for user-facing types.
- Keep struct fields internal so representations can evolve without breaking API.

## Proposed Final Surface (Breaking Changes OK)

Keep as canonical:
- `Context`, `Client`
- `attach_producer`, `attach_consumer`
- `request_attach_producer`, `request_attach_consumer` (low-level)
- `poll_attach!` (low-level)
- `do_work`, `driver_client_do_work!`
- `Base.close` for handles and client
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
- `handle_status`
- `run!` (agent runner convenience)

## Cleanup and Teardown

Explicitly document shutdown order to avoid dangling keepalives or background
pollers:

1. `close(producer)` / `close(consumer)` — stop agents, QoS/metadata helpers.
2. `close(client)` — close Aeron client and control-plane resources.
3. Optional: `close(runner)` if an explicit runner is used.

Handles should be idempotent to close; repeated `close` calls must be safe.

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

struct ClientCallbacks{F1,F2,F3,F4}
    on_frame!::F1        # (state, frame) -> CallbackAction
    on_qos_producer!::F2 # (state, snapshot) -> CallbackAction
    on_qos_consumer!::F3 # (state, snapshot) -> CallbackAction
    on_metadata!::F4     # (state, entry) -> CallbackAction
end
```

Construction guidance (type-stable):
- Provide a keyword constructor that returns a fully concrete
  `ClientCallbacks{F1,F2,F3,F4}` by inferring the function object types.
- Use small callable structs for defaults (e.g., `NoopFrame`, `NoopQos`)
  instead of `Function`-typed fields.
- Functors (callable structs) or FunctionWrappers are acceptable alternatives
  when you need dynamic behavior without boxing.
- Ensure handles are parameterized on callback types:
  `ProducerHandle{CB}` / `ConsumerHandle{CB}` to avoid boxing.

Rules:
- Callbacks run on the agent thread; MUST be non-allocating and non-blocking.
- Callbacks MUST NOT throw in the hot path; use return actions for control flow.
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
- Ensure `close(handle)` tears down internal timers and agent state cleanly.

## Multiple Dispatch Opportunities (No Dynamic Dispatch)

Use dispatch to improve ergonomics while keeping concrete types:

- `set_metadata_attribute!(producer, attr::MetadataAttribute)`
- `set_metadata_attribute!(producer, pair::Pair{<:AbstractString, <:Tuple})`
- `set_metadata_attribute!(producer, attrs::AbstractVector{MetadataAttribute})`
- `set_metadata_attribute!(producer, attrs::MetadataAttribute...)`
- `attach_consumer(client, cfg::ConsumerConfig)` vs `attach_consumer(client; kwargs...)`
  by materializing a concrete config struct for keyword paths.
- `poll_qos!(::ProducerHandle)` and `poll_qos!(::ConsumerHandle)` returning concrete snapshots.
- `handle_status(::ProducerHandle)` / `handle_status(::ConsumerHandle)` with role-specific structs.
- `try_claim_slot!(::ProducerHandle, bytes::Integer)` vs `try_claim_slot!(::ProducerHandle, payload::AbstractVector)`.

## Type-Stability Checklist

- Avoid abstract-typed fields in hot-path structs (prefer parametric concrete types).
- Avoid `Function` fields; use functors or FunctionWrappers.
- Keep hot-path collections typed (e.g., `Vector{UInt8}` not `Vector{Any}`).
- Use small unions (`Union{T,Nothing}`) rather than large union types.
- For larger unions, consider WrappedUnions.jl to preserve type stability.
- Avoid non-`const` globals and `AbstractDict` in hot paths.

## Performance Notes (Hot Path)

- Prefer `@inline` for small, frequently called helpers in the hot path.
- Avoid splatting (`f(args...)`) in hot paths; it can allocate.
- Preallocate temporary buffers/workspaces; do not grow vectors during polling.
- Avoid `String` conversions or interpolation in hot paths.
- Use `@inbounds`/`@simd` only when bounds are guaranteed and measured.

## Aeron Publication Notes

- Prefer the normal `FragmentAssembler` unless controlled polling is required.
- Internally, `ExclusivePublication` is safe when a single publishing thread is
  guaranteed (matches the single-writer model). Use regular `Publication` when
  a publication might be shared across threads.

## Threading Model

- Handles are owned by a single agent thread; hot-path calls assume single-thread
  ownership.
- If multi-threaded access is needed, it must be explicit and coordinated outside
  the handle (no implicit locking).
- We can adopt Aeron’s “client conductor” terminology: a per-client Agent that
  runs `do_work` / `driver_client_do_work!`, driven by an `AgentRunner` or
  `AgentInvoker`.

## Testing and Validation

- Add allocation checks for hot-path calls (e.g., `@allocated` in microbenchmarks).
- Include a zero-allocation smoke test for producer/consumer hot loops.
- Validate type stability with `@code_warntype` on hot-path entrypoints.

## Interface Seams (Swappable Implementations)

Define minimal interfaces to allow swapping implementations without touching
the hot path. The following are conceptual contracts (signatures shown in
Julia-ish pseudocode).

### ControlPlaneTransport

```
send_request!(transport, msg) -> correlation_id::Int64
poll_attach_response!(transport, correlation_id::Int64, now_ns::UInt64) -> Union{AttachResponse,Nothing}
poll_detach_response!(transport, correlation_id::Int64, now_ns::UInt64) -> Union{DetachResponse,Nothing}
poll_lease_revoked!(transport, now_ns::UInt64) -> Union{LeaseRevoked,Nothing}
poll_driver_shutdown!(transport, now_ns::UInt64) -> Union{DriverShutdown,Nothing}
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
