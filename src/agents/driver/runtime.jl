"""
Initialize the SHM driver.

Arguments:
- `config`: driver configuration.
- `client`: Aeron client to use for publications/subscriptions.

Returns:
- `DriverState` initialized with publications, subscriptions, and timers.
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
        FixedSizeVectorDefault{UInt8}(undef, CONTROL_BUF_BYTES),
        FixedSizeVectorDefault{UInt8}(undef, ANNOUNCE_BUF_BYTES),
        ShmAttachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDetachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmLeaseKeepalive.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDriverShutdownRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmAttachResponse.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDetachResponse.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmLeaseRevoked.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDriverShutdown.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmRegionSuperblock.Encoder(Vector{UInt8}),
        Aeron.BufferClaim(),
        Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, _, _
            nothing
        end),
    )

    streams = Dict{UInt32, DriverStreamState}()
    leases = Dict{UInt64, DriverLease}()
    metrics = DriverMetrics(0, 0, 0, 0, 0, 0, 0)
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
        runtime,
        streams,
        leases,
        UInt64(1),
        config.stream_id_range === nothing ? UInt32(0) : config.stream_id_range.start_id,
        config.descriptor_stream_id_range === nothing ? UInt32(0) : config.descriptor_stream_id_range.start_id,
        config.control_stream_id_range === nothing ? UInt32(0) : config.control_stream_id_range.start_id,
        Dict{UInt32, UInt32}(),
        Dict{UInt32, UInt32}(),
        metrics,
        timer_set,
        0,
        DriverShutdownReason.NORMAL,
        "",
        lifecycle,
    )
    state.runtime.control_assembler = make_driver_control_assembler(state)
    if config.policies.epoch_gc_on_startup
        now_ns = UInt64(Clocks.time_nanos(clock))
        for stream in values(config.streams)
            gc_orphan_epochs_for_stream!(state, stream.stream_id, now_ns)
        end
    end
    return state
end

"""
Poll the driver control subscription.

Arguments:
- `state`: driver state.
- `fragment_limit`: max fragments to poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Number of fragments processed.
"""
function poll_driver_control!(state::DriverState, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(state.runtime.control.sub_control, state.runtime.control_assembler, fragment_limit)
end

"""
Driver work loop.

Arguments:
- `state`: driver state.

Returns:
- Work count (sum of polled fragments and timer work).
"""
function driver_do_work!(state::DriverState)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    state.work_count = 0
    state.work_count += poll_driver_control!(state)
    state.work_count += poll_timers!(state, now_ns)
    return state.work_count
end

function announce_all_streams!(state::DriverState)
    for stream_state in values(state.streams)
        emit_driver_announce!(state, stream_state)
    end
    return nothing
end

function check_leases!(state::DriverState, now_ns::UInt64)
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
