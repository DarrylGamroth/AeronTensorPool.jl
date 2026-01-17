# Implementation Plan: Descriptor/Control/Progress Pollers

Goal: provide a clean AeronTensorPool API boundary for AeronTensorPoolRecorder.jl so it never touches Aeron types or `Aeron.poll`.

## Status
- [x] Spec/API alignment confirmed
- [x] Implementation completed
- [x] Tests passing
- [ ] Recorder updated (separate repo)

## Decisions (locked)
- Use `TensorPoolClient` directly; no extra PollerRuntime wrapper.
- Add pollers for descriptors, consumer config, and progress.
- Pollers own subscriptions + fragment assemblers and expose `poll!`.
- Provide `rebind!` for per-consumer stream reassignment (spec-driven).

## Open Questions
- None currently. (Add new questions here if they arise.)

## Public API (draft)
- Abstract interface:
  - `abstract type AbstractControlPoller end`
  - Required methods: `poll!`, `close!`
  - Optional: `rebind!`
- Types:
  - `FrameDescriptorPoller{H}`
  - `ConsumerConfigPoller{H}`
  - `FrameProgressPoller{H}`
- Constructors:
  - `FrameDescriptorPoller(client::TensorPoolClient, channel::AbstractString, stream_id::Int32, handler::H)`
  - `ConsumerConfigPoller(client::TensorPoolClient, channel::AbstractString, stream_id::Int32, handler::H)`
  - `FrameProgressPoller(client::TensorPoolClient, channel::AbstractString, stream_id::Int32, handler::H)`
- Methods:
  - `poll!(poller, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)::Int`
  - `rebind!(poller, channel::AbstractString, stream_id::Int32)::Nothing`
  - `Base.close(poller)::Nothing`

Handler contract (type-stable):
- Handler is a concrete callable type `H` (functor or function with no captures).
- Callback signature: `handler(poller, decoder)`.

## Implementation Steps
- [x] Add `src/control/descriptor_pollers.jl`.
- [x] Wire into `src/control/Control.jl` exports.
- [x] Add `AbstractControlPoller` and define `poll!`/`close!` interface docs.
- [x] Implement schema/template/version gating with `MessageHeader.schemaId`.
- [x] Use SBE decoders (`FrameDescriptor`, `ConsumerConfigMsg`, `FrameProgress`).
- [x] `rebind!` closes the old subscription and updates the subscription handle.
- [x] Ensure pollers are allocation-free in steady state (preallocate decoders/assembler).

## Tests (AeronTensorPool.jl)
- [x] `test/test_control_descriptor_pollers.jl`
  - [x] Valid FrameDescriptor invokes handler.
  - [x] Invalid schema/template ignored.
  - [x] Valid ConsumerConfig invokes handler.
  - [x] Invalid template ignored.
  - [x] Valid FrameProgress invokes handler.
  - [x] Invalid schema ignored.
  - [x] `rebind!` updates subscription channel/stream correctly.

## Recorder follow-up (AeronTensorPoolRecorder.jl)
- [ ] Replace direct Aeron usage with pollers.
- [ ] Keep recorder logic unchanged (per-stream assignment, handshake).

## Notes
- Spec-driven stream reassignment rules: `docs/SHM_Tensor_Pool_Wire_Spec_v1.2.md:372`.
- Maintain zero-allocation hot paths after initialization.
