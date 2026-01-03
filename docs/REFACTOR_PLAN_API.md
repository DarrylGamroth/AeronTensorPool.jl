# API Refactor Plan

## Goals
- Clarify API ownership and lifetimes (especially for driver response strings).
- Keep hot paths type-stable and allocation-free.
- Align public surface with Aeron/Archive/Cluster patterns (poller/proxy, explicit ownership).
- Minimize breaking changes; stage compatibility shims where needed.

## Phase 1: Public API Surface Audit
- Inventory exported types/functions; annotate each as public vs internal.
- Identify return types that expose internal lifetimes (e.g., `StringRef`).
- Add a short "API stability" section to `docs/IMPLEMENTATION.md` describing view vs owned types.

## Phase 2: Driver Response Views
- Introduce explicit view vs owned types for driver responses:
  - `AttachResponseView`, `DetachResponseView`, `LeaseRevokedView`, `DriverShutdownView` (StringRef fields).
  - `AttachResponseOwned`, etc. (String fields).
- Add helpers:
  - `materialize(::AttachResponseView)` -> owned copy.
  - `materialize_all!(poller)` to snapshot and own all current responses.
- Export `string_ref_view`/`string_ref_string` or replace with view/owned helpers.

## Phase 3: Type-Stable String Handling Guidelines
- Document which fields are allowed to be `StringView`-backed and why.
- Require `String` for long-lived config/state.
- Add a `StringArena` usage note and lifetime diagram.

## Phase 4: Config + Client API Harmonization
- Review config types for public use vs internal.
- Align naming with Aeron conventions (proxy/poller/agent naming consistency).
- Provide simple constructors for common use cases (driver client/producer/consumer) without exposing internal buffers.

## Phase 5: Deprecations and Compatibility
- Provide deprecation shims if any renamed types/functions are introduced.
- Update tests and docs to use the new view/owned types.

## Phase 6: Validation + Benchmarks
- Add a test that verifies view lifetimes (arena overwrite invalidation).
- Add allocation tests to ensure view creation remains allocation-free.
- Verify no regressions in existing allocation and integration tests.

## Review Findings (Current)
- String arena is fixed at 64 KiB and throws on overflow; consider configurability or a safe fallback to owned Strings when a response exceeds capacity.
- StringRef lifetimes are only documented; add a generation counter or materialize helpers to prevent stale reads.
- map_from_attach_response! consumes StringRef views; callers who map after another poll can see invalid URIs without warning.
- string_ref_view creates a SubArray; consider a non-allocating accessor for hot-loop access if needed.

## Open Decisions
- Whether view types should be exported or wrapped by higher-level API.
- Whether to provide per-message arena sizing or keep fixed size.
- Whether to add a `materialize_*` API in public surface or keep internal.
