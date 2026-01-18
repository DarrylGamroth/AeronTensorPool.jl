# AeronTensorPoolRecorder Integration Notes

These notes summarize the recent client/runtime interface changes and how they affect AeronTensorPoolRecorder.jl integration.

## Summary
AeronTensorPool now defines a small interface contract for client/runtime objects. Agents and pollers consume `AbstractTensorPoolClient` rather than raw `Aeron.Client`. This enables a clean API boundary for Recorder and future transport swaps.

## What Changed
- Added `AbstractTensorPoolClient` contract and accessors:
  - `client_context(client)`
  - `aeron_client(client)` (Aeron-backed implementations)
  - `control_runtime(client)` (optional, may be `nothing`)
- Agents now accept `AbstractTensorPoolClient` in constructors.
- New poller wrappers exist in AeronTensorPool:
  - `FrameDescriptorPoller`, `ConsumerConfigPoller`, `FrameProgressPoller`, `TraceLinkPoller`
- `TensorPoolClient` and `TensorPoolRuntime` implement the contract; both can wrap an existing Aeron client.

## Recorder Guidance (No Direct Aeron)
- Recorder should depend only on AeronTensorPool client/poller APIs, not Aeron.jl types.
- Use a `TensorPoolContext` and `connect(...)` to create a `TensorPoolClient` and pass it to pollers.
- Avoid calling `Aeron.add_subscription` or `Aeron.poll` directly in Recorder.

## Minimal Example (Recorder)
```julia
using AeronTensorPool

ctx = TensorPoolContext(
    DriverEndpoints(
        "recorder",
        "",
        "aeron:ipc", Int32(1000),
        "aeron:ipc", Int32(1001),
        "aeron:ipc", Int32(1200),
    )
)

client = connect(ctx)

handler = (poller, decoder) -> begin
    # Handle FrameDescriptor / TraceLinkSet here
end

poller = FrameDescriptorPoller(client, "aeron:ipc", Int32(1100), handler)
# Or TraceLinkPoller(client, "aeron:ipc", Int32(17310), handler)

# In loop:
#   poll!(poller)

close(poller)
close(client)
```

## Notes
- `with_client` / `with_runtime` helpers are for setup/teardown, not hot loops.
- If Recorder needs to support non-Aeron backends later, it should keep its dependency limited to the client/poller interface defined here.
