# Discovery Service Implementation Phases

This document tracks phased implementation of the Discovery Service described in
`docs/SHM_Discovery_Service_Spec_v_1.0.md`. The implementation should follow existing
Agent patterns (state structs, poller registry, preallocated buffers, no allocations
in hot paths).

## Phase 1: Schema and Codegen

- Add discovery SBE schema file (schemaId=910) alongside other schemas.
- Generate codecs into `src/gen` using the same build pipeline.
- Export template IDs and message types in `src/AeronTensorPool.jl`.
- Ensure field ordering follows SBE varData rules (all varData at end).

## Phase 2: Core Types and Constants

- Define `DiscoveryConfig` (channels/stream IDs, limits, expiry).
- Define `DiscoveryEntry` (driver_instance_id, stream_id, epoch, layout, URIs, pools, metadata).
- Define `DiscoveryResult` view for responses (StringView-friendly, no allocation).
- Add `DISCOVERY_SCHEMA_ID`, template IDs, default limits (max results, dataSourceName length).

## Phase 3: Provider Agent (Embedded Mode)

- Add `DiscoveryProviderState` with:
  - Aeron pub/sub (request channel + response pubs).
  - Cache index keyed by `(driver_instance_id, stream_id)`.
  - Timestamp tracking for expiry.
  - Preallocated buffers for responses.
- Input handlers:
  - `ShmPoolAnnounce` updates cache (epoch monotonic rules).
  - `DataSourceAnnounce` / `DataSourceMeta` update metadata.
  - DiscoveryRequest handling with AND filters and tag matching.
- Response logic:
  - Validate response endpoint.
  - Emit `DiscoveryResponse` with `status=OK/NOT_FOUND/ERROR`.
  - Enforce response cap (default 1,000).

## Phase 4: Registry Agent (Standalone Mode)

- Add registry state that subscribes to multiple driver announce/control endpoints.
- Multi-driver indexing by `(driver_instance_id, stream_id)`.
- Expiry policy (3× announce period) and prune timer.
- Configuration to list multiple driver endpoints.

## Phase 5: Client API

- Add `DiscoveryClient` with:
  - request sender (try_claim + SBE encode).
  - response poller and correlation tracking.
  - optional timeout helper (non-blocking, caller-driven loop).
- Provide `discover_streams!` that fills an output container (no allocations).

## Phase 6: CLI Tooling

- Extend `scripts/tp_tool.jl` with:
  - `discover` command (filters, tags).
  - JSON or line output for tooling.

## Phase 7: Tests

- Unit tests for filtering semantics (AND, tag matching, name matching).
- Expiry tests (stale entries removed).
- Response validation tests (empty channel, stream_id=0).
- Integration test with driver + embedded discovery provider.

## Phase 8: Documentation

- Add discovery overview to `docs/IMPLEMENTATION.md`.
- Add example config snippets and client usage examples.
- Document embedded vs standalone registry deployment.

## Status

- Phase 1: completed
- Phase 2: pending
- Phase 3: pending
- Phase 4: pending
- Phase 5: pending
- Phase 6: pending
- Phase 7: pending
- Phase 8: pending
