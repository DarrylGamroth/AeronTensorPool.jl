# Issue Tracker

## Open

- Aeron poll allocations.
  - Could not reproduce in minimal Aeron/IPC tests; `@allocated Aeron.poll(...)` returns 0 with `FragmentAssembler`.
  - `@code_warntype Aeron.poll` shows stable types for `FragmentAssembler` handler.
  - Suspect allocations (if any) come from handler logic or downstream processing, not Aeron.poll itself.
  - Next: add a targeted test that wraps `Aeron.poll` around real handlers if a regression appears.

## Closed

- Allocation-free consumer payload access vs type safety.
  - Finding: allocations came from returning a tuple `(header, payload)` where `payload` is a `SubArray`.
  - Fix: `try_read_frame!` now returns `Bool` and fills a reusable `ConsumerFrameView` with `PayloadSlice`.
  - Verified: allocation tests (loop + E2E) report zero allocations after init.
  - Status: fixed on `main`.
