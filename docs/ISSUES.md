# Issue Tracker

## Open

- Allocation-free consumer payload access vs type safety.
  - Finding: allocations come from returning a tuple `(header, payload)` where `payload` is a `SubArray`.
  - Fix: `try_read_frame!` returns `Bool` and fills a reusable `ConsumerFrameView` with `PayloadSlice`.
- Aeron poll allocations.
  - Could not reproduce in minimal Aeron/IPC tests; `@allocated Aeron.poll(...)` returns 0 with `FragmentAssembler`.
  - `@code_warntype Aeron.poll` shows stable types for `FragmentAssembler` handler.
  - Suspect allocations (if any) come from handler logic or downstream processing, not Aeron.poll itself.

## Closed

- None yet.
