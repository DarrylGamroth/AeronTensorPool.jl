# Implementation Plan: Review Findings (Jan 2026)

Specs are authoritative. This plan addresses the current review gaps and refactor suggestions.

## Phase 0: Spec Compliance (High/Medium)
Status: completed
- Consumer epoch preference:
  - Track highest observed `epoch` per `stream_id`.
  - Ignore `ShmPoolAnnounce` with `epoch < highest_epoch`.
  - Remap only on `epoch > current_epoch`.
  - Update tests for regression epoch announcements.
- Superblock `activity_timestamp_ns` freshness:
  - Decode superblock `activity_timestamp_ns` during announce handling.
  - Reject announces when activity timestamp is older than freshness window.
  - Add tests for stale activity timestamps.
- Descriptor sequence regression:
  - Detect `seq < last_seq_seen` and trigger remap/reset per spec.
  - Add test for seq regression handling.

## Phase 1: API Ergonomics (Optional)
Status: completed
- Discovery attach overloads:
  - `attach(client, entry::DiscoveryEntry; ...)`.
  - `request_attach(client, entry::DiscoveryEntry; ...)`.
- Avoid hidden config mutation:
  - Return resolved entry on handle or provide a `resolved_stream_id` field.
  - Add doc notes about discovery stream selection.

## Phase 2: Structure & Naming (Optional)
Status: completed
- Clarify discovery layering:
  - Renamed `src/discovery/` to `src/discovery_client/`.
  - Update module path to avoid confusion with `src/agents/discovery/`.

## Phase 3: Hsm Migration Candidates (Optional)
Status: completed
- Consumer mapping phase:
  - Migrate UNMAPPED → MAPPED → FALLBACK transitions to Hsm.
  - Centralize remap/reject/teardown transitions.
- Producer driver reattach flow:
  - Migrate pending attach → remap → active to Hsm.
  - Centralize lease revoke/retry/drain transitions.
- Bridge assembly lifecycle:
  - Model `Idle → Assembling → Complete/Timeout` with Hsm.
  - Ensure timeouts/duplicates handled in one place.
- RateLimiter mapping binding:
  - Model `Unbound → Bound → Active` to formalize single-consumer binding.

## Phase 4: Refactor Opportunities (Optional)
Status: completed
- Extract a helper for Aeron pub/sub init + log fields to reduce drift across agents.
- Consolidate repeated logging patterns for channel/stream status.

## Phase 5: Docs/Matrix Update
Status: completed
- Update `docs/SPEC_COMPLIANCE_MATRIX.md` after Phase 0 fixes.
- Add brief notes to `docs/USER_GUIDE.md` for discovery attach overloads (if Phase 1 done).
