# Driver HSM Middle-Ground Sketch

This sketch shows a minimal Hsm.jl integration: only the top‑level driver lifecycle uses an HSM.
Per‑lease and per‑stream logic remains procedural for now, but with explicit enums for future migration.

## Top‑Level Driver HSM (only)

```julia
using Hsm

@hsmdef mutable struct DriverLifecycle
    state::DriverState
end

@statedef DriverLifecycle :BOOT
@statedef DriverLifecycle :RUNNING
@statedef DriverLifecycle :DRAINING
@statedef DriverLifecycle :STOPPED

@on_initial function(sm::DriverLifecycle, ::Root)
    return Hsm.transition!(sm, :BOOT)
end

@on_initial function(sm::DriverLifecycle, ::BOOT)
    # init_driver already sets up pubs/subs/timers
    return Hsm.transition!(sm, :RUNNING)
end

@on_event function(sm::DriverLifecycle, ::RUNNING, ::ShutdownRequested, _)
    return Hsm.transition!(sm, :DRAINING)
end

@on_event function(sm::DriverLifecycle, ::DRAINING, ::ShutdownTimeout, _)
    return Hsm.transition!(sm, :STOPPED)
end

@on_event function(sm::DriverLifecycle, ::RUNNING, ::Tick, now_ns::UInt64)
    poll_driver_control!(sm.state)
    poll_timers!(sm.state, now_ns)
    return Hsm.EventHandled
end

@on_event function(sm::DriverLifecycle, ::DRAINING, ::Tick, now_ns::UInt64)
    # no new attach accepted in DRAINING, but keep detaches/expiry
    poll_driver_control!(sm.state)
    poll_timers!(sm.state, now_ns)
    return Hsm.EventHandled
end
```

## Procedural Lease/Stream Logic (explicit enums for future migration)

```julia
@enum LeaseStatus UNATTACHED ACTIVE EXPIRED REVOKED DETACHED
@enum StreamStatus UNCLAIMED READY PRODUCER_ATTACHED

struct DriverLease
    lease_id::UInt64
    stream_id::UInt32
    client_id::UInt32
    role::DriverRole.SbeEnum
    expiry_ns::UInt64
    status::LeaseStatus
end

mutable struct DriverStreamState
    stream_id::UInt32
    profile::DriverProfileConfig
    epoch::UInt64
    header_uri::String
    pool_uris::Dict{UInt16, String}
    producer_lease_id::UInt64
    consumer_lease_ids::Set{UInt64}
    status::StreamStatus
end
```

## Why this helps

- Top‑level lifecycle is explicit and avoids flag‑hell.
- Timers become events (`Tick`, `ShutdownRequested`) without refactoring lease logic.
- Lease/stream states are already explicit enums, making a later HSM migration low‑risk.

## Migration Note (Middle → Full HSM)

If/when the driver grows:
- Reuse the existing `LeaseStatus`/`StreamStatus` enums as HSM state names.
- Convert existing procedural handlers (`handle_attach_request!`, `handle_keepalive!`, `revoke_lease!`)
  into `@on_event` handlers for per‑lease/per‑stream HSMs.
- Keep event names stable (`:AttachOk`, `:Keepalive`, `:LeaseTimeout`, `:Detach`, `:Revoke`) so the
  top‑level HSM can dispatch into child HSMs without renaming.
