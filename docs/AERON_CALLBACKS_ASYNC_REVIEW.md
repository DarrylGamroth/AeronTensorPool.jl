# Aeron Callbacks and Async APIs Review

This note summarizes where Aeron callbacks (`on_*`) and async APIs (`async_*`) could
be useful in this project, along with risks and recommendations.

## Current Usage

- Callbacks: not used in `src/` (only appears in Aeron sample code).
- Async APIs: not used in `src/`; all publications/subscriptions are created synchronously.

## Aeron `on_*` Callbacks

### Where it could help
- Connection observability for consumer/bridge subscriptions without polling `Aeron.is_connected`.
- Debug or metrics hooks for image/session metadata in scripts or diagnostics tooling.

### Risks / constraints
- Callbacks run on Aeron conductor threads; handlers must be allocation-free and thread-safe.
- Heavy work should be deferred to agent loops via flags/queues.

### Recommendation
- Optional, for observability only. Avoid in hot paths unless explicitly enabled.

## Aeron `async_*` APIs

### Where it could help
- Producer per-consumer streams (dynamic creation of descriptor/control publications).
- High fan-out or frequent add/remove destination operations.
- Non-blocking startup for discovery/driver clients (if desired).

### Risks / constraints
- Adds state machine complexity: track async handles and poll to completion.
- Cleanup/error paths become more complex.

### Recommendation
- Not required for core correctness. Consider for dynamic runtime resource creation.

## Candidates If Adopted Later

- Callbacks:
  - Consumer/bridge subscriptions for readiness tracking or diagnostics.
  - Optional debug hooks in `scripts/*` or tooling.
- Async:
  - Producer per-consumer stream creation.
  - Bridge dynamic destination management.

