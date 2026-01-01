# Issue Tracker

## Open

- Allocation-free consumer payload access vs type safety.
  - Current: `try_read_frame!` returns `view(payload_mmap, ...)`, which allocates per frame.
  - Prior zero-alloc option: `UnsafeArray` payload return, but uses unsafe access.
  - Alternative: return a safe `PayloadSlice` (mmap + offset + len) and provide helpers; caller chooses to copy or view.
  - Goal: zero allocations in hot path without unsafe pointer exposure.
- Aeron poll allocations.
  - `Aeron.poll` allocates when delivering fragments (upstream in Aeron.jl).
  - Decide whether to accept, work around in tests, or patch upstream.

## Closed

- None yet.
