# Refactoring Targets

This document tracks non-urgent refactors that are intentionally deferred.
Keep entries short and include rationale and any blockers.

## Candidates

### Poller unification (future)
- Goal: align `DriverResponsePoller` and new descriptor/config/progress pollers under a shared interface and ownership model.
- Rationale: consistent API surface and lifecycle.
- Status: deferred; prioritize stable control-plane wiring first.
- Notes: add abstract interface (`poll!`, `close!`, optional `rebind!`) without forcing ownership changes.

