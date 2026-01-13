# Epoch GC Policy (Driver)

This document proposes a safe, spec-compliant garbage-collection policy for epoch-scoped SHM directories.
The driver is the sole authority for SHM lifecycle and epoch management; clients never delete epochs.

## Goals

- Prevent unbounded growth of `/dev/shm` by removing stale epochs.
- Preserve correctness: never delete data that could still be referenced by any active lease.
- Align with the Wire and Driver specs (epoch change is a hard remap boundary; cleanup is optional).

## Policy Overview (Safe Default)

**Keep:** current epoch and the immediately previous epoch.  
**Delete:** any epoch `< current_epoch - 1` that is not referenced by any active lease and is older than the freshness window.

### Safety Conditions

An epoch directory is eligible for deletion only if **all** are true:

- No active lease (producer or consumer) references that epoch.
- Superblock `activity_timestamp_ns` is stale relative to the GC freshness window:
  - `now_ns - activity_timestamp_ns > epoch_gc_min_age_ns` (default: `3 × announce_period_ns`).
- The superblock PID is no longer active on the OS (dead process).

## When GC Runs

- After a **producer attach** that increments the epoch.
- After **producer detach/revoke/expiry** (epoch increment).
- Optionally at **driver startup** (configurable).

If SHM allocation fails due to space:

1. Run GC once.
2. Retry allocation.
3. If still failing, return `ResponseCode.INTERNAL_ERROR` with a reason.

## Configuration Knobs

Suggested config keys:

- `policies.epoch_gc_enabled = true`
- `policies.epoch_gc_keep = 2`
  - Keep current + (N-1) previous epochs.
- `policies.epoch_gc_min_age_ns = 3 × announce_period_ns`
  - Derived by default if unset.
- `policies.epoch_gc_on_startup = false`

## Directory Layout (Spec)

Epoch directories are scoped as:

```
<shm_base_dir>/tensorpool-${USER}/<namespace>/<stream_id>/<epoch>/
```

This enables immediate abandonment on epoch change and lazy cleanup of stale epochs.

## Alignment With Specs

- Driver is authoritative for SHM lifecycle and epoch changes.
- Epoch changes are hard remap boundaries; consumers must drop in-flight frames and remap.
- Cleanup is optional; driver MAY remove epochs eagerly or lazily.

## Aeron Cleanup Analogy (Informative)

Aeron does not create epoch-scoped directories, but it does have a bounded “log buffer”
model with explicit lifecycle rules:

- **Term buffers** are fixed-size segments (default 64 MiB) that publications rotate through.
- **Images** are the receiver-side views of a publication; one image per subscription/stream.
- **Cleanup** is driven by liveness and position:
  - When an image becomes inactive (e.g., subscriber disconnects or times out),
    the driver reclaims and deletes it.
  - Term buffers are reused; they do not grow unbounded with time.

This bounded-buffer + liveness-cleanup model is the closest analogue to epoch GC:
epochs are like old images that should be reclaimed once all readers are gone and
freshness windows have elapsed.

## Implementation Notes

- GC should be **driver-only** and **lease-aware**.
- Use announce freshness to avoid deleting epochs that a lagging consumer could still observe.
- Keep the current and previous epoch even if they are stale to allow smooth remap.
