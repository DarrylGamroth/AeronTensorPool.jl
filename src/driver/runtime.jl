"""
Initialize the SHM driver.
"""
function init_driver(config::DriverConfig; client::Aeron.Client)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())

    pub_control = Aeron.add_publication(client, config.endpoints.control_channel, config.endpoints.control_stream_id)
    pub_announce =
        Aeron.add_publication(client, config.endpoints.announce_channel, config.endpoints.announce_stream_id)
    pub_qos = Aeron.add_publication(client, config.endpoints.qos_channel, config.endpoints.qos_stream_id)
    sub_control = Aeron.add_subscription(client, config.endpoints.control_channel, config.endpoints.control_stream_id)

    control = ControlPlaneRuntime(client, pub_control, sub_control)
    runtime = DriverRuntime(
        control,
        pub_announce,
        pub_qos,
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        Vector{UInt8}(undef, ANNOUNCE_BUF_BYTES),
        ShmAttachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDetachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmLeaseKeepalive.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDriverShutdownRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmAttachResponse.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDetachResponse.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmLeaseRevoked.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDriverShutdown.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmRegionSuperblock.Encoder(Vector{UInt8}),
        Aeron.BufferClaim(),
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, _, _
            nothing
        end),
    )

    streams = Dict{UInt32, DriverStreamState}()
    leases = Dict{UInt64, DriverLease}()
    metrics = DriverMetrics(0, 0, 0, 0, 0, 0, 0, 0)
    timer_set = TimerSet(
        (
            PolledTimer(UInt64(config.policies.announce_period_ms) * 1_000_000),
            PolledTimer(UInt64(config.policies.lease_keepalive_interval_ms) * 1_000_000),
            PolledTimer(UInt64(0)),
        ),
        (DriverAnnounceHandler(), DriverLeaseCheckHandler(), DriverShutdownHandler()),
    )

    lifecycle = DriverLifecycle()
    state = DriverState(
        config,
        clock,
        UInt64(0),
        runtime,
        streams,
        leases,
        UInt64(1),
        metrics,
        timer_set,
        0,
        DriverShutdownReason.NORMAL,
        "",
        lifecycle,
    )
    state.runtime.control_assembler = make_driver_control_assembler(state)
    return state
end

"""
Poll the driver control subscription.
"""
function poll_driver_control!(state::DriverState, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(state.runtime.control.sub_control, state.runtime.control_assembler, fragment_limit)
end

"""
Driver work loop.
"""
function driver_do_work!(state::DriverState)
    fetch!(state.clock)
    state.now_ns = UInt64(Clocks.time_nanos(state.clock))
    state.work_count = 0
    state.work_count += poll_driver_control!(state)
    state.work_count += poll_timers!(state, state.now_ns)
    return state.work_count
end

@inline function announce_all_streams!(state::DriverState)
    for stream_state in values(state.streams)
        emit_driver_announce!(state, stream_state)
    end
    return nothing
end

@inline function check_leases!(state::DriverState, now_ns::UInt64)
    expired = UInt64[]
    for (lease_id, lease) in state.leases
        if now_ns > lease.expiry_ns
            push!(expired, lease_id)
        end
    end
    for lease_id in expired
        revoke_lease!(state, lease_id, DriverLeaseRevokeReason.EXPIRED, now_ns)
    end
    return nothing
end
