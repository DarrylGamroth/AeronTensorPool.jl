# API Refactor Plan

## Goals
- Clarify API ownership and lifetimes (especially for driver response strings).
- Keep hot paths type-stable and allocation-free.
- Align public surface with Aeron/Archive/Cluster patterns (poller/proxy, explicit ownership).
- Minimize breaking changes; stage compatibility shims where needed.
- Zero-allocation requirement remains in force for hot paths; any new API must preserve allocation-free fast paths.
- Prefer fixed-size string buffers for control-plane responses to avoid arena/GC churn.

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
- Driver response snapshots use fixed-size buffers (FixedSizeArrays).
- Response structs use unified `*Response` names (no view/owned split).
- `FixedString` is an `AbstractString` wrapper with Base methods (`length`, `view`, `copyto!`, `String`) and null-terminated length detection.

## Decision Log
- 2026-01-02: Replace StringRef arena with fixed-size string buffers backed by FixedSizeArrays; reject overflow.
- 2026-01-02: Use unified `*Response` structs; remove `materialize(poller)`.

## Phase 0: Allocation Baseline (Prerequisite) — Completed
- Run existing allocation tests (`test/test_allocations*.jl`) and document current state.
- Identify any unexpected allocations in hot paths that need fixing regardless of this refactor.
- Document current allocation budget per role (producer/consumer/supervisor hot paths).
- Audit current exports vs internal usage of response string accessors and reconcile with current implementation.
- Exit criteria: baseline documented in IMPLEMENTATION.md; no pre-existing hot-path regressions; export inventory complete.

## Phase 1: Public API Surface Audit — Completed
- Inventory exported types/functions; annotate each as public vs internal.
- Identify return types that expose internal lifetimes.
- Identify consumers of response string accessors.
- Add a short "API stability" section to `docs/IMPLEMENTATION.md` describing fixed-buffer responses.
- Exit criteria: published inventory + stability section merged; response string access documented; consumer call sites documented.

## Phase 2a: Driver Response Fixed-Buffer Strings — Completed
- Replace StringRef arena with fixed-size string buffers (FixedSizeArrays).
  - Introduce `FixedString{N}` (buffer + length) and helpers (`clear!`, `set!`, `as_stringview`).
  - Use fixed buffers inside response structs (no view/owned split, no generation counter).
- Sizes:
  - `URI_MAX_BYTES = 4096` (matches Aeron URI max length including NUL; store up to 4095).
  - `ERROR_MAX_BYTES = 1024` (matches spec; explicit error on overflow).
- Update driver response snapshots to copy SBE varData into fixed buffers.
- Update `map_from_attach_response!` to use fixed-buffer accessors (StringView) without allocation.
- Remove `string_ref_view`, `string_ref_string`, and `materialize(poller)`.
- Exit criteria: no arena code remains; fixed-buffer types used; overflow returns explicit error; tests updated; docs updated; no hot-path allocation regression.

**Progress**:
- Fixed buffer types implemented; `FixedString` moved to `src/core/fixed_string.jl`.
- Response types migrated; `materialize(poller)` removed from call sites.
- Driver response poller uses `copyto!(::FixedString, ::AbstractString)`.
- Tests and docs updated to use `view(fs)`/`String(fs)`.

## Phase 2b: Fixed-Buffer Policy + Configurability (Optional Enhancement)
- Make buffer sizes configurable in client config with safe defaults.
- Add overflow tests for URI/error message fields.
- Exit criteria: config-driven buffer sizing documented; tests cover overflow/reject; docs updated with sizing guidance.

## Phase 3: Type-Stable String Handling Guidelines — Completed
- Document which fields are allowed to be StringView-backed and why.
  - **Example**: StringView OK in `FrameDescriptor` handler (ephemeral, consumed immediately); NOT OK in config structs (persisted across poll cycles).
- Require fixed buffers for control-plane responses and String for long-lived configs.
- Add a fixed-buffer usage note (length bounds, overflow behavior).
- Exit criteria: guideline section merged; examples show view vs fixed-buffer usage; sizing defaults documented.

## Phase 4: Config + Client API Harmonization — Pending
- Review config types for public use vs internal.
- Decide whether `DriverResponsePoller` and similar poller types should be public or internal-only.
  - **Recommendation**: Keep pollers internal; users interact only through agent interfaces and high-level client API.
- Align naming with Aeron conventions (proxy/poller/agent naming consistency).
- Provide simple constructors for common use cases (driver client/producer/consumer) without exposing internal buffers.
- Exit criteria: configs tagged public/internal; poller export decision made and documented; naming aligned; constructors added; docs updated; no new allocations on hot paths.

## Phase 5: Deprecations and Compatibility — Pending
- Prioritize correctness and alignment with Aeron APIs; shims are not required. Prefer adopting the new API directly when it is more correct/idiomatic.
- Update tests and docs to use the new response types.
- Exit criteria: tests/docs updated to new APIs; release notes enumerate any renamed/removed APIs and rationale.

## Phase 6: Validation + Benchmarks — Pending
- Add allocation tests to ensure response polling remains allocation-free.
- Verify no regressions in existing allocation and integration tests.
- Add overflow tests for fixed buffers (URI/error message).
- Add integration test: driver attach → consumer polls → remap triggered → new attach → verify no stale refs used in mapping.
- Benchmark hot paths before/after to ensure no allocation regression.
- Exit criteria: all new tests pass; allocations unchanged on hot paths; overflow tests green; integration test covers full remap flow; benchmark shows no regression.

## Review Findings (Current)
- String arena adds lifetime complexity and implicit invalidation; fixed buffers simplify ownership.
- `map_from_attach_response!` should consume fixed buffers or owned strings to avoid stale refs.
- Driver response polling is warm path (control-plane), but zero allocations are still preferred.

## Recommendations for Open Decisions

### 1. Response naming
**Recommendation**: Use `*Response` names and remove `*View`/`*Info` splits once fixed buffers are in place.
- Rationale: Fixed buffers remove lifetime ambiguity; a single response type is clearer.

### 2. Fixed buffer sizes?
**Recommendation**: Use fixed sizes with explicit overflow reject; make configurable later if needed.
- Rationale: Fixed buffers keep ownership simple and remove arena logic. Aeron URI cap is 4096 bytes; error messages can be capped (e.g., 1024).

### 3. `map_from_attach_response!` safety?
**Recommendation**: Accept fixed-buffer response structs; use StringView accessors.
- Rationale: Keeps remap allocation-free while ensuring stable data.

### 4. Generation counter placement?
**Recommendation**: Not needed once fixed buffers replace arena.

## Open Decisions (resolve before Phase 2a merges)
- Fixed buffer sizes (URI, error message) and whether to make them configurable.

**Action**: Review recommendations above, decide, and record outcomes in the Decision Log before starting Phase 2a.
