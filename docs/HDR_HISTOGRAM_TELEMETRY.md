# HdrHistogram Telemetry (Driver/Control Plane)

This document describes why HdrHistogram-style telemetry is useful and how to integrate it into AeronTensorPool with minimal overhead and zero allocations in steady state.

## Why It Is Useful
HdrHistogram provides distribution metrics (p50/p90/p99/max) rather than averages. For the driver control plane, that gives you:
- Tail latency of attach/detach handling (response time under load).
- Poll loop jitter (detect stalls or backpressure).
- Keepalive inter-arrival jitter (clients near expiry).
- Lease expiry reaction time (revocation and announce cadence).
- Announce/QoS cadence jitter (timing stability).

These are all operationally important and hard to see with simple counters.

## Design Goals
- Zero allocations after initialization.
- Opt-in only (feature flag or telemetry sink).
- No extra overhead in hot data-plane loops.
- Small constant cost per update (HdrHistogram is fine if preallocated).
- Use fixed-range histograms; auto-resize allocates and can serialize recording.
- Prefer IntervalRecorder for export without blocking writers.

## Recommended Integration Pattern (Preferred)
Use the existing telemetry sink and add a timing/histogram hook. This keeps the core decoupled from any specific metrics library.

### 1) Extend TelemetrySink with timing support
Add a new no-op method and a gated helper (sketch):

```julia
# src/core/telemetry.jl
@inline emit_timing!(::TelemetrySink, ::Symbol, ::UInt64, ::NamedTuple) = nothing

@inline function maybe_emit_timing!(name::Symbol, value_ns::UInt64, fields::NamedTuple)
    telemetry_enabled() || return nothing
    emit_timing!(telemetry_sink(), name, value_ns, fields)
    return nothing
end
```

### 2) Provide an HdrHistogram sink (optional module)
Implement a sink that records into fixed histograms (no Dicts). Example:

```julia
struct HdrHistogramSink <: TelemetrySink
    driver_poll_ns::HdrHistogram{UInt64}
    attach_latency_ns::HdrHistogram{UInt64}
    keepalive_delta_ns::HdrHistogram{UInt64}
end

@inline function emit_timing!(sink::HdrHistogramSink, name::Symbol, value_ns::UInt64, fields::NamedTuple)
    # Keep this branch-free with a small if/elseif chain.
    if name === :driver_poll_ns
        HdrHistogram.record!(sink.driver_poll_ns, value_ns)
    elseif name === :attach_latency_ns
        HdrHistogram.record!(sink.attach_latency_ns, value_ns)
    elseif name === :keepalive_delta_ns
        HdrHistogram.record!(sink.keepalive_delta_ns, value_ns)
    end
    return nothing
end
```

This keeps the telemetry cost constant and allocation-free.

HdrHistogram implementation notes:
- Use `Histogram(min, max, sigfigs)` with a fixed range; avoid auto-resize in hot paths.
- `IntervalRecorder` allows an export agent to read interval histograms without blocking writers.
- For allocation-free queries during export, reuse iterator state (`recorded_values_state` + `iterate!`).

### 2b) Dispatch-based metric types (optional)
If you want to avoid symbol switches entirely, define metric types and dispatch on them:

```julia
abstract type TimingMetric end
struct DriverPollNs <: TimingMetric end
struct AttachLatencyNs <: TimingMetric end
struct KeepaliveDeltaNs <: TimingMetric end

@inline emit_timing!(::TelemetrySink, ::TimingMetric, ::UInt64, ::NamedTuple) = nothing

@inline function emit_timing!(sink::HdrHistogramSink, ::DriverPollNs, value_ns::UInt64, fields::NamedTuple)
    HdrHistogram.record!(sink.driver_poll_ns, value_ns)
    return nothing
end
```

Call sites then use `maybe_emit_timing!(DriverPollNs(), elapsed_ns, (role = :driver,))`.

### 3) Instrument control-plane hot spots only
Suggested sites and events:

- Driver poll loop (control-plane work only):
  - `:driver_poll_ns` for each `poll_driver_control!` + `poll_timers!` cycle.
- Attach handling:
  - `:attach_latency_ns` measured from request receive to response publish.
- Lease keepalive:
  - `:keepalive_delta_ns` (delta between keepalives per lease).
- Announce cadence:
  - `:announce_delta_ns` between successive `ShmPoolAnnounce` publishes.

Use cached timestamps at the top of each loop. Avoid extra `time_ns()` calls where possible.

## Example Instrumentation Sketch (Driver Loop)
```julia
now_ns = Clocks.time_nanos(state.clock)
# ... poll work ...
elapsed_ns = Clocks.time_nanos(state.clock) - now_ns
maybe_emit_timing!(:driver_poll_ns, elapsed_ns, (role = :driver,))
```

## Alternative: Direct HdrHistogram in Driver
If you want always-on histograms without the sink indirection:
- Store histograms directly in driver state.
- Update in the same locations as above.
- Keep it gated by a config flag to avoid overhead in minimal builds.

This is simpler but couples the driver to HdrHistogram.jl and makes optional builds harder.

## Recommended Metrics (Driver)
- `driver_poll_ns`: poll loop duration.
- `attach_latency_ns`: from request decode to response publish.
- `detach_latency_ns`: from request decode to response publish.
- `keepalive_delta_ns`: time since last keepalive for a lease.
- `lease_expire_delay_ns`: time between expiry deadline and actual revoke.
- `announce_delta_ns`: time between `ShmPoolAnnounce` publishes.

## Operational Output
- Export histograms periodically (e.g., on timer) to logs or metrics backends.
- Prefer a separate Agent task for export so driver control-plane loops stay tight.
- Use p99/p999 to detect tail regressions.
- Keep raw histograms per driver instance (do not label per client to avoid explosion).

### Exporter Agent sketch
Example export loop using an interval recorder (no writer blocking):

```julia
struct HistogramExportAgent
    recorder::HdrHistogram.IntervalRecorder
    interval_ns::UInt64
    next_emit_ns::UInt64
end

Agent.name(::HistogramExportAgent) = "hdr-export"

function Agent.do_work(agent::HistogramExportAgent)
    now_ns = UInt64(time_ns())
    now_ns < agent.next_emit_ns && return 0
    agent.next_emit_ns = now_ns + agent.interval_ns

    interval = HdrHistogram.interval_histogram(agent.recorder)
    iter, state = HdrHistogram.recorded_values_state(interval)
    p99 = HdrHistogram.value_at_percentile(interval, 99.0, iter, state)
    @info "driver poll p99 (ns)" p99
    return 1
end
```

If you store fixed histograms directly, export with a lock or copy to avoid contention.
