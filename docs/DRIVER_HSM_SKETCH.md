# Driver HSM Sketch (Hsm.jl)

This is a design‑only sketch using Hsm.jl macros. It is intended to show how the driver and
per‑lease/per‑stream state machines could look without modifying production code.

## Driver HSM (top‑level)

```julia
using Hsm
using Clocks

@hsmdef mutable struct DriverHsm
    state::DriverState
end

@statedef DriverHsm :Init
@statedef DriverHsm :Running
@statedef DriverHsm :Running_Draining
@statedef DriverHsm :Stopped

@on_initial function(sm::DriverHsm, ::Root)
    return Hsm.transition!(sm, :Init)
end

@on_initial function(sm::DriverHsm, ::Init)
    # init_driver already sets up pubs/subs/timers
    return Hsm.transition!(sm, :Running)
end

@on_event function(sm::DriverHsm, ::Running, ::ShutdownRequested, _)
    return Hsm.transition!(sm, :Running_Draining)
end

@on_event function(sm::DriverHsm, ::Running_Draining, ::ShutdownTimeout, _)
    return Hsm.transition!(sm, :Stopped)
end

@on_event function(sm::DriverHsm, ::Running, ::Tick, now_ns::UInt64)
    # driver_do_work! body:
    poll_driver_control!(sm.state)
    poll_timers!(sm.state, now_ns)
    return Hsm.EventHandled
end

@on_entry function(sm::DriverHsm, ::Running)
    # arm timers / enable accepts (no transitions here)
end

@on_exit function(sm::DriverHsm, ::Running)
    # stop accepts / flush control state (no transitions here)
end

@on_entry function(sm::DriverHsm, ::Running_Draining)
    # reject new attaches, allow detach/expiry (no transitions here)
end

@on_exit function(sm::DriverHsm, ::Running_Draining)
    # emit shutdown notice if needed (no transitions here)
end
```

## Per‑Lease HSM (per client_id/stream_id/role)

```julia
@hsmdef mutable struct LeaseHsm
    lease::DriverLease
    state::DriverState
end

@statedef LeaseHsm :UNATTACHED
@statedef LeaseHsm :ACTIVE
@statedef LeaseHsm :EXPIRED
@statedef LeaseHsm :REVOKED
@statedef LeaseHsm :DETACHED

@on_initial function(sm::LeaseHsm, ::Root)
    return Hsm.transition!(sm, :UNATTACHED)
end

@on_event function(sm::LeaseHsm, ::UNATTACHED, ::AttachOk, _)
    return Hsm.transition!(sm, :ACTIVE)
end

@on_event function(sm::LeaseHsm, ::ACTIVE, ::Keepalive, now_ns::UInt64)
    sm.lease.expiry_ns = lease_expiry_ns(sm.state, now_ns)
    return Hsm.EventHandled
end

@on_entry function(sm::LeaseHsm, ::ACTIVE)
    # initialize expiry on entry
    sm.lease.expiry_ns = lease_expiry_ns(sm.state, UInt64(Clocks.time_nanos(sm.state.clock)))
end

@on_exit function(sm::LeaseHsm, ::ACTIVE)
    # teardown hooks (metrics, revocation bookkeeping)
end

@on_event function(sm::LeaseHsm, ::ACTIVE, ::LeaseTimeout, now_ns::UInt64)
    revoke_lease!(sm.state, sm.lease.lease_id, DriverLeaseRevokeReason.EXPIRED, now_ns)
    return Hsm.transition!(sm, :EXPIRED)
end

@on_event function(sm::LeaseHsm, ::ACTIVE, ::Detach, now_ns::UInt64)
    revoke_lease!(sm.state, sm.lease.lease_id, DriverLeaseRevokeReason.DETACHED, now_ns)
    return Hsm.transition!(sm, :DETACHED)
end

@on_event function(sm::LeaseHsm, ::ACTIVE, ::Revoke, now_ns::UInt64)
    revoke_lease!(sm.state, sm.lease.lease_id, DriverLeaseRevokeReason.REVOKED, now_ns)
    return Hsm.transition!(sm, :REVOKED)
end
```

## Per‑Stream HSM (per stream_id)

```julia
@hsmdef mutable struct StreamHsm
    stream::DriverStreamState
    state::DriverState
end

@statedef StreamHsm :UNCLAIMED
@statedef StreamHsm :READY
@statedef StreamHsm :PRODUCER_ATTACHED

@on_initial function(sm::StreamHsm, ::Root)
    return Hsm.transition!(sm, :UNCLAIMED)
end

@on_event function(sm::StreamHsm, ::UNCLAIMED, ::Provision, _)
    bump_epoch!(sm.state, sm.stream)
    emit_driver_announce!(sm.state, sm.stream)
    return Hsm.transition!(sm, :READY)
end

@on_entry function(sm::StreamHsm, ::READY)
    emit_driver_announce!(sm.state, sm.stream)
end

@on_exit function(sm::StreamHsm, ::PRODUCER_ATTACHED)
    # producer lease lost → epoch bump/announce handled by event
end

@on_event function(sm::StreamHsm, ::READY, ::ProducerAttach, _)
    return Hsm.transition!(sm, :PRODUCER_ATTACHED)
end

@on_event function(sm::StreamHsm, ::PRODUCER_ATTACHED, ::ProducerLeaseLost, now_ns::UInt64)
    bump_epoch!(sm.state, sm.stream)
    emit_driver_announce!(sm.state, sm.stream)
    return Hsm.transition!(sm, :READY)
end
```

## Mapping from Current Code

- `handle_attach_request!` → dispatch `AttachOk` or `AttachReject` to the per‑lease HSM, and
  `Provision`/`ProducerAttach` to the per‑stream HSM.
- `handle_keepalive!` → `Keepalive`.
- `check_leases!` → `LeaseTimeout` events.
- `handle_detach_request!` → `Detach`.
- `revoke_lease!` (explicit or expiry) → `Revoke` or `ProducerLeaseLost`.

## Why Hsm.jl fits

- Event handling is type‑stable and zero‑allocation (Val‑based dispatch).
- Hierarchy allows `Running` to share handlers while `Running_Draining` overrides attach behavior.
- Entry/exit hooks make timer arming and teardown deterministic.
