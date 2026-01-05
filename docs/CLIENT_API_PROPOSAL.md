# Client API Proposal (Aeron-Inspired)

This document proposes adjustments to the user-facing API based on patterns in Aeron’s `aeron-client` (Java), with the goal of reducing surface complexity and aligning lifecycle/ownership expectations.

The Aeron client model is the explicit reference for API and lifecycle decisions unless noted otherwise.

## Aeron Client Patterns Worth Mirroring

- **Single entry point**: `Aeron.connect(ctx)` produces a client instance; “one client per driver per process.”
- **Context builder**: `Aeron.Context` holds configuration, defaults applied in `conclude()`. Context is not reused across clients.
- **Ownership semantics**: `Aeron` owns its `Context` after `connect()`, and `close()` cleans up.
- **Invoker vs runner**: client can run its conductor via `AgentRunner` (threaded) or `AgentInvoker` (caller-driven).
- **Simple API surface**: `addPublication`, `addSubscription`, `close`. Internals hidden behind the client.
- **Sync waits use invoker**: if configured, the driver `AgentInvoker` is invoked while awaiting synchronous responses.
- **Explicit callbacks**: e.g., `AvailableImageHandler`/`UnavailableImageHandler` instead of exposing protocol details.

## Observations vs Current API

- Users must reason about driver clients, control channels, and agent wiring to get started.
- Attach/discovery flows are currently woven into example code rather than encapsulated in a high-level client.
- Multiple “agent” types are exposed where a single client handle could manage lifecycle and polling.

## Proposed Actions

### 1. Introduce a Primary Client Type

Create `TensorPoolClient` as the entry point (analogous to `Aeron`):

- `TensorPoolClient.connect(ctx::TensorPoolContext)` returns a client handle.
- Client owns its context; `close(client)` cleans up.
- One client per process per driver (documented).

### 2. Define a Context Builder

Create `TensorPoolContext` (fluent config setters):

- Driver endpoints (control/announce, discovery).
- Aeron client integration (`Aeron.Client` handle or factory).
- Execution model: `use_invoker::Bool` to run client conductor in caller loop.
- Defaults applied during `connect(ctx)` (Julia does not expose `conclude()`).

### 3. Collapse Attach/Discovery into Client Methods

Expose simple, user-facing methods:

- `attach_consumer(client, settings; discover=true)` → `ConsumerHandle`
- `attach_producer(client, config; discover=true)` → `ProducerHandle`
- `detach(handle)` or `close(handle)`

Internals:

- If `discover=true`, run discovery and resolve endpoints internally.
- If `discover=false`, use configured endpoints directly.
- Use blocking “await” with optional invoker support (like Aeron’s driver invoker).

### 4. Offer Sync vs Async Variants

Provide a minimal async API for integration:

- `request_attach_consumer(...) -> correlation_id`
- `poll_attach(client, correlation_id) -> AttachResponse?`

Keep these in a “low-level” namespace, but prefer sync wrappers for the default path.

### 5. Hide Agent Wiring

Avoid exposing `DriverClientState`, `DiscoveryClientState`, or raw agent constructors to app code.

- Examples should only create a `TensorPoolClient` and call `attach_*`.
- Internals can still use agents + timers, but should not leak into the public API.

### 6. Align Naming with Aeron

Use terminology consistent with Aeron:

- `connect`, `close`, `add_*` semantics
- “Invoker mode” rather than “invoker mode” in docstrings

### 7. Error Handling and Contracts

- Define a small set of public error types (e.g., `AttachTimeoutError`, `DiscoveryTimeoutError`).
- Document error handling expectations (like Aeron’s `DriverTimeoutException`).

## Suggested Implementation Steps

1. Define `TensorPoolContext` and `TensorPoolClient` types.
2. Add `connect(ctx)` and `close(client)` with ownership semantics.
3. Wrap discovery + attach into `attach_consumer`/`attach_producer`.
4. Update examples to use the new high-level API.
5. Deprecate direct use of `DriverClientState`/`DiscoveryClientState` in user code.

## Open Questions

- Do we allow user-supplied `Aeron.Client` or always create one internally?
- Should invoker mode be default for single-threaded apps?
- Should attach methods return richer handles with convenience helpers (e.g., `offer_frame!`)?

## Proposed Answers

- **Aeron.Client ownership**: Support both. If the user supplies a client, we do not own it and never close it; if we construct it internally, `TensorPoolClient.close()` closes it. This mirrors Aeron’s “one client per process” guidance while supporting embedding.
- **Invoker mode default**: Default `use_invoker=false` to match Aeron. When invoker mode is enabled, expose `do_work(client)` so callers can drive progress explicitly (mirrors Aeron’s invoker model). When invoker mode is disabled, run the client conductor on an `AgentRunner` thread.
- **Richer handles**: Provide ergonomic handles in Julia (e.g., `ProducerHandle` with `try_claim_slot!`, `commit_slot!`, `offer_frame!`). Keep them thin wrappers over the core API, similar to how Aeron exposes `Publication` and `Subscription` objects with convenience methods.

The Aeron client provides a clear, minimal surface with explicit lifecycle ownership. Mirroring this model should make the API more ergonomic while keeping the internals flexible for advanced use.

## Aeron Invoker Example (Reference)

```julia
using Aeron

Aeron.Context() do ctx
    Aeron.use_conductor_agent_invoker!(ctx, true)

    Aeron.Client(ctx) do client
        channel = "aeron:udp?endpoint=localhost:20121"
        stream_id = 1001

        pub = Aeron.add_publication(client, channel, stream_id)
        while true
            work = Aeron.do_work(client)
            work == 0 && yield()

            result = Aeron.offer(pub, Vector{UInt8}(codeunits("hello")))
            result > 0 && break
        end
    end
end
```

For TensorPool, the equivalent should be `do_work(client)` on a `TensorPoolClient` configured with invoker mode, so callers can drive client progress in the same pattern.

## Additional Considerations (Aeron Reference Model)

- **Lifecycle ownership**: Be explicit about who owns and closes `TensorPoolContext`, `TensorPoolClient`, and any supplied `Aeron.Client`/`Aeron.Context`. Follow Aeron’s “client owns context after connect” pattern.
- **Threading model**: Define whether `TensorPoolClient` is thread-safe or single-threaded like Aeron; if single-threaded, document required external synchronization.
- **Thread safety (Aeron model)**: Default to single-threaded client usage; multi-threaded access requires an explicit lock in context (mirrors Aeron `clientLock`). Invoker mode is always single-threaded.
- **Blocking vs polling**: Provide sync `attach_*` with timeout/backoff, and async `request/poll` for integration; invoker mode should be the default for single-threaded callers.
- **Error model**: Public error types for attach/discovery timeouts and protocol errors (mirrors Aeron’s explicit exceptions).
- **Resource limits**: Per-consumer streams and attach outstanding limits; define cleanup/timeout behavior.
- **Naming parity**: Prefer Aeron-like names (`connect`, `close`, `do_work`) to reduce cognitive load.
- **Counters/metrics**: Surface counters on handles similar to Aeron’s counters; avoid leaking internal agent types.
- **Config separation**: Driver uses TOML; client prefers programmatic API and only needs connection endpoints (Aeron-like).
- **Context reuse policy**: Aeron forbids reusing `Context`; decide and document the same for `TensorPoolContext`.
- **Async callbacks**: consider Aeron-style available/unavailable callbacks for stream/image lifecycle vs polling only.
- **Backpressure semantics**: define how `try_claim`/`offer` failures are surfaced and whether to expose publication status.
- **Graceful shutdown**: define ordering and linger durations similar to Aeron’s close/resource linger settings.
- **Client naming**: optional `client_name` for diagnostics (Aeron `clientName` analog).
- **Driver invoker integration**: if driver runs in-process, define whether client invoker should drive driver invoker (Aeron `driverAgentInvoker` analog).
- **Versioning/compat**: surface layout/schema compatibility checks in attach responses and API errors.
- **Idle strategies**: provide `IdleStrategy` hooks (Aeron-style) for client invoker loops and waiting behaviors.
- **Error handlers**: allow a user-supplied error handler to mirror Aeron’s `ErrorHandler` pattern.
- **Close semantics**: define timeouts and linger behavior when closing clients and handles.
- **Client identity**: consider exposing a client ID or label for diagnostics (Aeron `clientId`/`clientName` analog).
- **Retry policy**: make attach/discovery retry backoff configurable rather than fixed.
- **Metrics toggles**: enable/disable counters for minimal deployments.
- **Testing hooks**: decide whether any testing-only toggles should be exposed or hidden.
- **Context immutability**: consider freezing `TensorPoolContext` after `connect` like Aeron.
- **API versioning**: plan how the public API versioning aligns with schema/layout versions.
- **Migration guidance**: provide a mapping from current low-level calls to the new client API.
- **Deprecation strategy**: define how to phase out low-level APIs without breaking users.
- **Cross-language parity**: ensure the Julia client API can map cleanly to a future C client.

## Phased Implementation Plan

### Phase 0: Design Freeze (Completed)
- Confirm ownership rules for supplied vs internal `Aeron.Client`.
- Confirm invoker default and `do_work(client)` contract.
- Confirm error types and naming parity.

### Phase 1: Core Types and Context (Completed)
- Implement `TensorPoolContext` with `conclude()` defaults.
- Implement `TensorPoolClient` and `connect(ctx)`/`close(client)`.
- Add `use_invoker` flag and `do_work(client)` support.

### Phase 2: Attach/Discovery API (Completed)
- Implement `attach_consumer`/`attach_producer` sync APIs.
- Add async `request_attach_*` + `poll_attach` variants.
- Integrate discovery internally with optional opt-out.

### Phase 3: Handles and Convenience Methods (Completed)
- Define `ConsumerHandle`/`ProducerHandle` with thin convenience helpers.
- Expose counters/metrics on handles in an Aeron-like style.

### Phase 4: Error and Retry Policy (Completed)
- Add public error types and map protocol failures to them.
- Make retry/backoff policy configurable (context fields).

### Phase 5: Examples and Migration (Completed)
- Update examples to the new client API.
- Provide a migration guide mapping old calls to new API.
- Deprecate direct use of low-level client/agent types in examples.

### Phase 6: Validation and Parity (Completed)
- Add tests for invoker vs runner modes.
- Add tests for supplied vs internal Aeron client ownership.
- Ensure API surface matches cross-language constraints for future C client.
