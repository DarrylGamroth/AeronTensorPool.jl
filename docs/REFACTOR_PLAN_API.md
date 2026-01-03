# API Refactor Plan

## Goals
- Clarify API ownership and lifetimes (especially for driver response strings).
- Keep hot paths type-stable and allocation-free.
- Align public surface with Aeron/Archive/Cluster patterns (poller/proxy, explicit ownership).
- Minimize breaking changes; stage compatibility shims where needed.
- Zero-allocation requirement remains in force for hot paths; any new API must preserve allocation-free fast paths.

## Path Classification (Hot/Warm/Cold)
**Hot paths** (zero allocation required):
- `poll_descriptor!`, `poll_progress!` (consumer frame ingestion)
- Seqlock validation and commit word checks
- Header slot reads from SHM
- `do_work` methods in producer/consumer agents (frame processing loop)

**Warm paths** (minimal allocation acceptable):
- Control-plane polling (`poll_control!`, driver response poller)
- QoS emission (periodic, 1 Hz)
- Timer polling

**Cold paths** (allocation acceptable):
- Remap/attach flows (`map_from_attach_response!`)
- Epoch transitions and region unmapping
- Agent initialization and shutdown
- Configuration loading

## Execution Cadence and Ownership
- Target release window: next minor (e.g., 0.x+1). Freeze breaking changes after Phase 4 lands.
- Owners: Phase 0 (baseline) — **TBD**; Phase 1–2 (API/strings) — **TBD**; Phase 3–4 (docs/config harmonization) — **TBD**; Phase 5–6 (deprecations/tests/bench) — **TBD**. Assign before Phase 0 starts.
- Decision log: maintain a short bullet log in this file with dates and outcomes for each open decision; resolve all open decisions before Phase 2 merges.

## Current State (Implemented)
- Driver response snapshots use a StringRef arena (see `DriverResponsePoller`).
- StringRef helpers exist (`string_ref_view`, `string_ref_string`), but are internal-only.
- Some call sites already use StringRef and StringView in control-plane flows.

## Decision Log
- 2026-01-02: View types kept internal; expose `materialize(poller)` returning owned snapshots.
- 2026-01-02: Arena size fixed at 64 KiB for now; configurable sizing deferred to Phase 2b.
- 2026-01-02: Public API will export `materialize(poller)` only; per-response helpers stay internal.
- 2026-01-02: `map_from_attach_response!` will require `AttachResponseOwned` (materialize before mapping).
- 2026-01-02: Generation counter stored in `DriverResponsePoller`, captured per response view.

## Phase 0: Allocation Baseline (Prerequisite)
- Run existing allocation tests (`test/test_allocations*.jl`) and document current state.
- Identify any unexpected allocations in hot paths that need fixing regardless of this refactor.
- Document current allocation budget per role (producer/consumer/supervisor hot paths).
- Audit current exports vs internal usage of StringRef utilities and reconcile with current implementation.
- Exit criteria: baseline documented in IMPLEMENTATION.md; no pre-existing hot-path regressions; export inventory complete.

## Phase 1: Public API Surface Audit
- Inventory exported types/functions; annotate each as public vs internal.
- Identify return types that expose internal lifetimes (e.g., `StringRef`).
- Identify consumers of StringRef utilities (who calls `string_ref_view`, from where).
- Add a short "API stability" section to `docs/IMPLEMENTATION.md` describing view vs owned types.
- Exit criteria: published inventory + stability section merged; no undocumented exported `StringRef` returns remain; consumer call sites documented.

## Phase 2a: Driver Response Views + Generation Counter
- Introduce explicit view vs owned types for driver responses:
  - `AttachResponseView`, `DetachResponseView`, `LeaseRevokedView`, `DriverShutdownView` (StringRef fields).
  - `AttachResponseOwned`, etc. (String fields).
- Add helpers:
  - `materialize(::AttachResponseView)` -> owned copy.
  - `materialize_all!(poller)` to snapshot and own all current responses.
- Export `string_ref_view`/`string_ref_string` or replace with view/owned helpers.
- Safety: add a generation counter/epoch on views to detect stale reads.
  - **Design note**: Generation counter lives in `DriverResponsePoller`; bumped on arena wrap. Each `*ResponseInfo` captures generation at snapshot time. Views validate generation on access.
  - Overflow handling: counter is `UInt64`; wraparound at 2^64 is unreachable in practice (treat as incompatible if encountered).
- Update `map_from_attach_response!` to accept `AttachResponseOwned` (force materialization before mapping).
- Exit criteria: view/owned types in place; generation counter enforced; `map_from_attach_response!` safety implemented; generation invalidation test passes; helpers exported; docs updated; no hot-path allocation regression.

## Phase 2b: Arena Overflow Fallback (Optional Enhancement)
- String arena policy: make arena size configurable with a documented default (64 KiB).
- On overflow, fall back to heap-allocated owned strings and log once per interval.
  - **Design note**: Overflow fallback requires discriminated union or separate handling; consider deferring to later release if complexity is high.
  - Allocation in overflow path is acceptable (exceptional/cold path).
- Exit criteria: arena size configurable; overflow fallback implemented and tested; overflow test forces >64 KiB response and confirms fallback; docs updated with sizing guidance.

## Phase 3: Type-Stable String Handling Guidelines
- Document which fields are allowed to be `StringView`-backed and why.
  - **Example**: StringView OK in `FrameDescriptor` handler (ephemeral, consumed immediately); NOT OK in config structs (persisted across poll cycles).
- Require `String` for long-lived config/state.
- Add a `StringArena` usage note and lifetime diagram.
  - Diagram should show: arena wrap scenarios, generation invalidation, and poll-after-poll invalidation.
- Exit criteria: guideline section merged; concrete examples show view vs owned usage; arena sizing/defaults and overflow behavior documented; lifetime diagram included.

## Phase 4: Config + Client API Harmonization
- Review config types for public use vs internal.
- Decide whether `DriverResponsePoller` and similar poller types should be public or internal-only.
  - **Recommendation**: Keep pollers internal; users interact only through agent interfaces and high-level client API.
- Align naming with Aeron conventions (proxy/poller/agent naming consistency).
- Provide simple constructors for common use cases (driver client/producer/consumer) without exposing internal buffers.
- Exit criteria: configs tagged public/internal; poller export decision made and documented; naming aligned; constructors added; docs updated; no new allocations on hot paths.

## Phase 5: Deprecations and Compatibility
- Prioritize correctness and alignment with Aeron APIs; shims are not required. Prefer adopting the new API directly when it is more correct/idiomatic.
- Update tests and docs to use the new view/owned types.
- Exit criteria: tests/docs updated to new APIs; release notes enumerate any renamed/removed APIs and rationale.

## Phase 6: Validation + Benchmarks
- Add a test that verifies view lifetimes (arena overwrite invalidation).
- Add a generation counter invalidation test: poll twice, verify first result is stale/rejected.
- Add allocation tests to ensure view creation remains allocation-free.
- Verify no regressions in existing allocation and integration tests.
- Add an overflow test that forces arena rollover and confirms fallback-to-owned strings (if Phase 2b implemented).
- Add integration test: driver attach → consumer polls → remap triggered → new attach → verify no stale refs used in mapping.
- Benchmark hot paths before/after to ensure no allocation regression.
- Exit criteria: all new tests pass; generation/stale ref tests green; allocations unchanged on hot paths; integration test covers full remap flow; benchmark shows no regression.

## Review Findings (Current)
- String arena is fixed at 64 KiB and throws on overflow; consider configurability or a safe fallback to owned Strings when a response exceeds capacity.
- StringRef lifetimes are only documented; add a generation counter or materialize helpers to prevent stale reads.
- map_from_attach_response! consumes StringRef views; callers who map after another poll can see invalid URIs without warning.
- string_ref_view creates a SubArray; consider a non-allocating accessor for hot-loop access if needed.
- map_from_attach_response! should be updated to accept owned/materialized responses or validate generation before use.
- `string_ref_view` and `string_ref_string` are currently internal (not exported); tests should use `materialize(poller)` for owned snapshots.
- Driver response polling is warm path (control-plane), not hot path; one allocation on remap (cold path) is acceptable.

## Recommendations for Open Decisions

### 1. View types exported or wrapped?
**Recommendation**: Keep `*ResponseView` types internal; export only `materialize(poller)` returning owned types.
- Rationale: View lifetimes are tricky; forcing materialization at API boundary is safer and clearer.
- Users interact through agent interfaces; advanced users needing direct poller access can use internal APIs with documented risks.

### 2. Per-message arena sizing or fixed?
**Recommendation**: Keep fixed 64 KiB with overflow fallback (Phase 2b); make configurable later if needed.
- Rationale: 64 KiB handles typical attach responses (~10 pools × ~200 bytes/URI + error messages). Variable sizing adds complexity without clear benefit.
- Configurability can be added in Phase 2b if deployment requirements emerge.

### 3. `materialize_*` API public or internal?
**Recommendation**: Export `materialize(poller)` returning all responses as owned; keep per-response helpers internal.
- Rationale: Users shouldn't need to know about StringRef internals; single clear API for "make this safe to keep" is sufficient.
- Signature: `materialize(poller::DriverResponsePoller) -> (attach::Union{AttachResponseOwned,Nothing}, detach::Union{DetachResponseOwned,Nothing}, ...)`.

### 4. `map_from_attach_response!` safety?
**Recommendation**: Change signature to accept `AttachResponseOwned`; caller must materialize first.
- Rationale: Simplest and safest; one allocation on remap (cold path) is acceptable. Avoids generation validation complexity at every `string_ref_view` call.
- Alternative rejected: validating generation before each use is error-prone and easy to miss.

### 5. Generation counter placement?
**Recommendation**: Counter in `DriverResponsePoller` (bumped on arena wrap); each `*ResponseInfo` captures generation at snapshot.
- Rationale: Per-poller counter is simple; per-response capture enables validation without global state.
- Overflow: `UInt64` wraparound is unreachable (1 poll/ns for 584 years); treat as incompatible if encountered.

## Open Decisions (resolve before Phase 2a merges)
- View types exported or wrapped (see Recommendations).
- Fixed arena size vs configurable (see Recommendations).
- Public materialize API vs internal-only (see Recommendations).
- `map_from_attach_response!` safety contract (see Recommendations).
- Generation counter placement (see Recommendations).

**Action**: Review recommendations above, decide, and record outcomes in the Decision Log before starting Phase 2a.
