# Refactor Plan (AeronTensorPool.jl)

This file tracks the ongoing refactor to align structure with Aeron-style organization while staying Julian.
Progress updates should be checked off as changes land.

## Goals

- Keep the public wire-level API stable.
- Separate infra (SHM, Aeron helpers, timers, counters, errors) from agent logic.
- Make agent roles and responsibilities obvious.
- Reduce clutter in large structs by grouping related state.

## Target Layout

```
src/
  AeronTensorPool.jl
  core/
    constants.jl
    errors.jl
    types.jl
  shm/
    shm_paths.jl
    shm_io.jl
  aeron/
    aeron_utils.jl
    assemblies.jl
    counters.jl
  timers/
    polled_timer.jl
    timer_set.jl
  config/
    config_loader.jl
  agents/
    producer/
      state.jl
      handlers.jl
      logic.jl
    consumer/
      state.jl
      handlers.jl
      logic.jl
    supervisor/
      state.jl
      handlers.jl
      logic.jl
    bridge/
      state.jl
      logic.jl
    decimator/
      state.jl
      logic.jl
  agent_glue/
    producer_agent.jl
    consumer_agent.jl
    supervisor_agent.jl
```

## Progress Checklist

- [x] Phase 1: Move files into new folders without changing logic.
- [x] Phase 2: Split agents into `state/handlers/logic` files.
- [x] Phase 3: Introduce `Runtime`, `Mappings`, `Metrics` sub-structs for agent state.
- [x] Phase 4: Update exports and include order in `src/AeronTensorPool.jl`.
- [x] Phase 5: Update tests/benchmarks to new module paths (no behavior changes).
- [x] Phase 6: Document the new layout in `docs/IMPLEMENTATION.md`.

## Notes

- Keep public API and behavior stable during refactor.
- Prefer small commits per phase to keep changes reviewable.
