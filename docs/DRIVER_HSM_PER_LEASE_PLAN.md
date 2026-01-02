# Driver Per-Lease HSM Plan

Scope: introduce per-lease HSMs while keeping the existing top-level `DriverLifecycle` HSM.
Per-stream logic remains procedural in this stage.

## Goals
- Make lease lifecycle explicit (attach → active → expired/revoked/detached).
- Keep hot-path allocation-free and avoid dynamic dispatch.
- Preserve existing behavior (no protocol changes).

## Lease HSM State Model

States (per lease):
- `Init`: newly created lease entry.
- `Active`: keepalive updates accepted.
- `Expired`: keepalive timeout exceeded.
- `Revoked`: server-initiated revoke.
- `Detached`: client-initiated detach.
- `Closed`: terminal state (entry removed).

Events:
- `AttachOk`: lease created and active.
- `Keepalive`: keepalive update.
- `Detach`: client detach request.
- `LeaseTimeout`: keepalive expired.
- `Revoke`: driver-initiated revoke (e.g., policy, producer replacement).
- `Close`: remove lease entry.

State transitions (high level):
- `Init` → `Active` on `AttachOk`
- `Active` → `Detached` on `Detach`
- `Active` → `Expired` on `LeaseTimeout`
- `Active` → `Revoked` on `Revoke`
- `{Detached,Expired,Revoked}` → `Closed` on `Close`

## Mapping to Current Driver Logic

Current locations:
- Attach: `handle_attach_request!`
- Detach: `handle_detach_request!`
- Keepalive: `handle_keepalive!`
- Expiry scan: `check_leases!` + `revoke_lease!`
- Revoke: `revoke_lease!`

Proposed mapping:
- On successful attach response: create lease HSM and dispatch `AttachOk`.
- On keepalive: dispatch `Keepalive` (updates expiry).
- On detach request: dispatch `Detach` and then `Close`.
- On expiry scan: dispatch `LeaseTimeout` and then `Close`.
- On revoke path: dispatch `Revoke` and then `Close`.

The existing `revoke_lease!` logic remains authoritative for epoch bump and revoke emission.
The HSM wraps state transitions and guards to ensure only valid transitions occur.

## Data Ownership

Per-lease HSM instance is owned by `DriverState.leases` and stored alongside `DriverLease`.
No new allocations in hot path; HSM instance stored in `DriverLease` or a parallel map.

## Implementation Notes

- Use `Hsm.jl` with a small `@hsmdef` for lease state.
- Keep event handlers minimal; no timers inside the HSM.
- All time decisions (expiry deadlines) remain in `check_leases!`.
- The top-level driver loop remains unchanged.

## Validation

- Unit tests for lease transitions.
- Existing driver tests should pass unchanged.
- Allocation checks should remain flat for attach/keepalive/expiry paths.
