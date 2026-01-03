# Driver HSM Mapping (Design Notes)

This document maps the current driver flow to a hierarchical state machine structure.
It is a design aid only (no code changes implied).

## Top-Level Driver HSM

States:
- `Init`: init, Aeron pubs/subs, timers.
- `Running`: normal operation.
- `Running.Draining`: reject new attaches; allow detach/expiry.
- `Stopped`: shutdown complete.

Event mapping (current code → HSM events):
- `init_driver` → `Init → Running`
- `driver_do_work!` loop → `Running` tick
- `emit_driver_shutdown!` (Agent.on_close) → `Running → Running.Draining → Stopped`

Timers as events:
- `DriverAnnounceHandler` → `announce_timer_fired` in `Running`
- `DriverLeaseCheckHandler` → `lease_check_timer_fired` in `Running`

## Per-Stream HSM (driver-owned)

States:
- `STREAM.UNCLAIMED`: stream not provisioned or epoch=0.
- `STREAM.READY`: SHM provisioned and announced.
- `STREAM.PRODUCER_ATTACHED`: producer lease active.

Event mapping:
- `get_or_create_stream!` → `STREAM.UNCLAIMED → STREAM.READY` (if provisioned)
- `bump_epoch!`/`provision_stream_epoch!` → stay in `STREAM.READY` with new epoch.
- Producer attach → `STREAM.READY → STREAM.PRODUCER_ATTACHED`
- Producer revoke/detach/expiry → `STREAM.PRODUCER_ATTACHED → STREAM.READY` (epoch bump + announce)

## Per-Lease HSM (per client_id + stream_id + role)

States:
- `LEASE.UNATTACHED`
- `LEASE.ACTIVE`
- `LEASE.EXPIRED`
- `LEASE.REVOKED`
- `LEASE.DETACHED`

Event mapping (current functions):
- `handle_attach_request!`
  - `attach_ok` → `UNATTACHED → ACTIVE`
  - `attach_reject` → stay `UNATTACHED`
- `handle_keepalive!` → `ACTIVE` refresh (extends expiry)
- `check_leases!` → `lease_timeout` → `ACTIVE → EXPIRED`
- `handle_detach_request!` → `ACTIVE → DETACHED`
- `revoke_lease!` (explicit or expiry) → `ACTIVE → REVOKED` (producers also bump epoch + announce)

Liveness:
- Lease expiry uses `lease_keepalive_interval_ms * lease_expiry_grace_intervals`.
- `check_leases!` emits `ShmLeaseRevoked` and removes lease from `state.leases`.

## Control-Plane Event Sources

- `handle_driver_control!` → dispatches:
  - `ShmAttachRequest` → `handle_attach_request!`
  - `ShmDetachRequest` → `handle_detach_request!`
  - `ShmLeaseKeepalive` → `handle_keepalive!`

## Where Hsm.jl Fits

If adopted, each `DriverLease` becomes its own sub‑HSM owned by the driver’s `Running` state.
Stream provisioning and epoch bumps are handled directly in driver logic.
Timers become explicit `announce_timer_fired` and `lease_check_timer_fired` events
instead of implicit checks inside `driver_do_work!`.

This keeps teardown paths (detach/revoke/expiry) consistent and allows a `Draining`
super‑state to halt attaches while still servicing keepalive/detach until shutdown.
