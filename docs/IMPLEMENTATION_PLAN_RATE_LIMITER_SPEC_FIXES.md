# RateLimiter Spec Fixes Plan

Spec: `docs/SHM_RateLimiter_Spec_v1.0.md` is authoritative.

## Phase 0: Confirm schema/behavior alignment
- Verify no schema changes are needed for fixes below (all runtime logic only).
- Re-read sections covering rematerialization, progress forwarding, per-consumer rate limits.
Status: completed.

## Phase 1: Pending rematerialization failure handling
- **Current**: pending frame is retained when `try_claim_slot!` fails.
- **Spec**: drop on claim failure.
- **Fix**:
  - In `publish_pending!`, if `try_claim_slot!` returns `nothing`, increment drop counters and clear pending (do not retain).
  - Add log at debug level for dropped pending due to claim failure.
- **Tests**:
- Add unit test where claim fails (force backpressure) and assert pending is cleared and next frames can flow.
Status: completed.

## Phase 2: FrameProgress headerIndex rewrite
- **Current**: forwarded `FrameProgress.headerIndex` preserves source index.
- **Spec**: destination headerIndex must be derived from `seq` and dest `nslots`.
- **Fix**:
  - In progress forward path, compute `dest_header_index = seq & (nslots - 1)` using mapped dest `nslots` and use that when publishing progress.
  - Ensure headerIndex rewrite applies for both COMPLETE and IN_PROGRESS states.
- **Tests**:
- Add progress forwarding test with mismatched source/dest `nslots` to verify headerIndex rewrite.
Status: completed.

## Phase 3: Per-consumer rate policy enforcement
- **Current**: multiple ConsumerHello overwrite `max_rate_hz` (not per-consumer).
- **Spec**: per-consumer rate-limits; RateLimiter should either track per consumer or enforce single consumer.
- **Fix** (minimal):
  - Enforce single consumer per mapping: track first `consumer_id` for dest and ignore/deny subsequent hellos (log warning and ignore updates).
  - Document in code and user docs that one consumer per mapping is supported for v1.
- **Alternative** (if expanding scope):
  - Maintain per-consumer limit map and select strictest or per-consumer streams; defer unless required.
- **Tests**:
- Add test for multiple ConsumerHello with different consumer IDs; ensure only first affects rate.
Status: completed.

## Phase 4: Cleanup / unused fields
- **Current**: `RateLimiterMapping.profile` unused.
- **Fix**:
  - Remove field or wire it to select rate profile; prefer removal if spec does not require.
- **Tests**:
- Update any config parsing tests and example TOML accordingly if field removed.
Status: completed.

## Phase 5: Documentation updates
- Update `docs/USER_GUIDE.md` and `docs/IMPLEMENTATION_PLAN_RATE_LIMITER.md` to reflect fixes.
- Add a short note on single-consumer mapping restriction if adopted.
Status: completed.

## Completion checklist
- All new tests pass.
- `docs/IMPLEMENTATION_PLAN_RATE_LIMITER.md` updated with completed status and references to this plan.
