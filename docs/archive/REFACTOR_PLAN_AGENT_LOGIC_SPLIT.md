# Agent Logic File Split Plan

Goal: split `logic.jl` grab-bag files into focused modules for clarity and reference implementation readability.

Status: completed; logic files have been decomposed into init/work/lifecycle (and handlers where appropriate).

## Guiding Principles
- Preserve behavior and APIs; move functions only.
- Keep hot-path code close to related types (minimize cross-file indirection).
- Prefer consistent file names across agents.

## Proposed File Layout (per agent)
- `init.jl`: constructors and resource wiring (Aeron pubs/subs, timers, runtime structs)
- `work.jl`: `*_do_work!`, pollers, timers, work counters
- `lifecycle.jl`: attach/remap/shutdown/driver event handling, state transitions
- `handlers.jl`: message handlers (if not already separate)
- `logic.jl`: should become a thin include shim or be removed

## Candidate Moves

### Producer (`src/agents/producer`)
- From `logic.jl` → `init.jl`:
  - `init_producer`, `init_producer_from_attach`, `producer_config_from_attach`
- From `logic.jl` → `work.jl`:
  - `producer_do_work!`, `emit_periodic!`, timer polling helpers
- From `logic.jl` → `lifecycle.jl`:
  - `handle_driver_events!`, `remap_producer_from_attach!`, `producer_driver_active`

### Consumer (`src/agents/consumer`)
- From `logic.jl` → `init.jl`:
  - `init_consumer`, `init_consumer_from_attach`
- From `logic.jl` → `work.jl`:
  - `consumer_do_work!`, timer polling helpers
- From `logic.jl` → `lifecycle.jl`:
  - `handle_driver_events!`, `remap_consumer_from_attach!`, `consumer_driver_active`

### Supervisor (`src/agents/supervisor`)
- From `logic.jl` → `init.jl`:
  - `init_supervisor`
- From `logic.jl` → `work.jl`:
  - `supervisor_do_work!`, timer polling helpers
- From `logic.jl` → `lifecycle.jl`:
  - liveness or shutdown helpers if any exist there

### Bridge (`src/agents/bridge`)
- From `sender.jl` / `receiver.jl` → `init.jl` (if init routines are mixed)
- Ensure `*_do_work!` lives in `work.jl` for both sender/receiver

## Include Order Updates
- Update `src/agents/*/agent.jl` and `src/agents/*/agent_name.jl` includes to match the new files.
- Keep `state.jl` and `frames.jl` before `work.jl`.

## Verification
- Run full test suite after each agent split (small, incremental commits).

## Done Criteria
- `logic.jl` removed or reduced to a minimal include list.
- All agents follow the same structural pattern.
- Tests pass unchanged.
