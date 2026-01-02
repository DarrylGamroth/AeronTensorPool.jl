# Per-Stream HSM Implementation Phases

This plan defines the per-stream lifecycle HSM. It complements the driver lifecycle
and per-lease HSM work by explicitly modeling stream-level state transitions.

## Phase S-0: Design Alignment

Goals
- Define stream states and events for driver-managed streams.
- Identify integration points (attach, detach, epoch bump, shutdown).

Deliverables
- Stream lifecycle state diagram with states and events.
- Decision on whether stream HSM owns announce/QoS cadence decisions.

Validation
- Reviewed against driver spec sections for stream provisioning.

Status
- Pending.

## Phase S-1: HSM Scaffolding

Goals
- Introduce a StreamLifecycle HSM type and state hierarchy.

Deliverables
- StreamLifecycle HSM with initial state and core states (Init, Active, Draining, Closed).
- Root handler to count unhandled events (if desired).

Validation
- Unit tests for state transitions (Init -> Active, Active -> Draining -> Closed).

Status
- Pending.

## Phase S-2: Attach/Detach Integration

Goals
- Dispatch stream HSM events from attach/detach paths.

Deliverables
- Dispatch `:StreamProvisioned` on initial provisioning.
- Dispatch `:ProducerAttached`/`:ProducerDetached` and `:ConsumerAttached`/`:ConsumerDetached`.
- Optional transition to Draining when stream has no active producer.

Validation
- Unit tests for attach/detach driven transitions.
- No allocations in hot paths after init.

Status
- Pending.

## Phase S-3: Epoch/Remap Integration

Goals
- Model epoch bumps and remap events in stream state.

Deliverables
- Dispatch `:EpochBumped` on bump.
- Define whether epoch bump influences state (e.g., stay Active).

Validation
- Existing epoch bump tests still pass.

Status
- Pending.

## Phase S-4: Shutdown/Draining Integration

Goals
- Integrate with driver lifecycle for shutdown and draining behavior.

Deliverables
- Dispatch `:DriverDraining` or `:DriverShutdown` to transition to Draining/Closed.
- Ensure stream HSM state prevents new stream provisioning when draining.

Validation
- Driver shutdown tests pass; stream HSM transitions observed.

Status
- Pending.

