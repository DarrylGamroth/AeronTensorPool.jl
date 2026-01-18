# TensorPool Client/Runtime Interface

This document defines the internal interface contract for client/runtime objects used by agent initialization and poller constructors. It is authoritative for this repository.

## Normative Language
The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT", and "MAY" are to be interpreted as described in RFC 2119.

## AbstractTensorPoolClient Contract (Aeron-backed)
- Implementations MUST provide `client_context(client)` that returns a stable `TensorPoolContext` instance for the lifetime of the client.
- Implementations MUST provide `aeron_client(client)` that returns the `Aeron.Client` handle used for Aeron publications/subscriptions.
- Implementations MUST implement `Base.close` to release only resources they own and MUST NOT close externally owned handles.
- Implementations SHOULD provide `control_runtime(client)` that returns a `ControlPlaneRuntime` when available, or `nothing` when absent.

Callers should prefer `client_context`, `aeron_client`, and `control_runtime` accessors instead of relying on field names.

## Concrete Implementations

### TensorPoolClient
- `do_work(client)` MUST return `0` when invoker mode is disabled and MUST delegate to `Aeron.do_work` when invoker mode is enabled.

### TensorPoolRuntime
- When constructed with `create_control=true`, `control_runtime` MUST return a non-`nothing` `ControlPlaneRuntime`.
- When constructed with `create_control=false`, `control_runtime` MUST return `nothing`.

## Hot-Path Guidance (Informative)
`with_client` and `with_runtime` helpers use try/finally and are intended for setup/teardown rather than hot loops.
