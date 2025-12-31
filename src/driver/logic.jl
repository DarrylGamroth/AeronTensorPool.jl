const DRIVER_GROUP_HEADER_LEN = 4

"""
Initialize the SHM driver.
"""
function init_driver(config::DriverConfig)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.endpoints.aeron_dir)
    client = Aeron.Client(ctx)

    pub_control = Aeron.add_publication(client, config.endpoints.control_channel, config.endpoints.control_stream_id)
    pub_announce =
        Aeron.add_publication(client, config.endpoints.announce_channel, config.endpoints.announce_stream_id)
    pub_qos = Aeron.add_publication(client, config.endpoints.qos_channel, config.endpoints.qos_stream_id)
    sub_control = Aeron.add_subscription(client, config.endpoints.control_channel, config.endpoints.control_stream_id)

    runtime = DriverRuntime(
        ctx,
        client,
        pub_control,
        pub_announce,
        pub_qos,
        sub_control,
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        Vector{UInt8}(undef, ANNOUNCE_BUF_BYTES),
        ShmAttachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmDetachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmLeaseKeepalive.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
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
    metrics = DriverMetrics(0, 0, 0, 0, 0)
    timer_set = TimerSet(
        (
            PolledTimer(UInt64(config.policies.announce_period_ms) * 1_000_000),
            PolledTimer(UInt64(config.policies.lease_keepalive_interval_ms) * 1_000_000),
        ),
        (DriverAnnounceHandler(), DriverLeaseCheckHandler()),
    )

    state = DriverState(config, clock, runtime, streams, leases, UInt64(1), metrics, timer_set)
    state.runtime.control_assembler = make_driver_control_assembler(state)
    return state
end

"""
Poll the driver control subscription.
"""
function poll_driver_control!(state::DriverState, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(state.runtime.sub_control, state.runtime.control_assembler, fragment_limit)
end

"""
Driver work loop.
"""
function driver_do_work!(state::DriverState)
    fetch!(state.clock)
    work_count = 0
    work_count += poll_driver_control!(state)

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_count += poll_timers!(state, now_ns)

    return work_count
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


"""
Lookup or create stream state based on config and publishMode.
"""
function get_or_create_stream!(state::DriverState, stream_id::UInt32, publish_mode::DriverPublishMode.SbeEnum)
    stream_state = get(state.streams, stream_id, nothing)
    if !isnothing(stream_state)
        return stream_state
    end

    stream_config = nothing
    for entry in values(state.config.streams)
        if entry.stream_id == stream_id
            stream_config = entry
            break
        end
    end

    if isnothing(stream_config) && !state.config.policies.allow_dynamic_streams
        return nothing
    end
    if isnothing(stream_config)
        if publish_mode != DriverPublishMode.EXISTING_OR_CREATE
            return nothing
        end
        profile_name = state.config.policies.default_profile
    else
        profile_name = stream_config.profile
    end
    profile = get(state.config.profiles, profile_name, nothing)
    isnothing(profile) && return nothing

    stream_state = DriverStreamState(
        stream_id,
        profile,
        UInt64(0),
        "",
        Dict{UInt16, String}(),
        UInt64(0),
        Set{UInt64}(),
    )
    state.streams[stream_id] = stream_state
    return stream_state
end

@inline function next_lease_id!(state::DriverState)
    lease_id = state.next_lease_id
    state.next_lease_id += 1
    return lease_id
end

@inline function lease_expiry_ns(state::DriverState, now_ns::UInt64)
    grace_ns = UInt64(state.config.policies.lease_keepalive_interval_ms) * 1_000_000 *
        UInt64(state.config.policies.lease_expiry_grace_intervals)
    return now_ns + grace_ns
end

function handle_attach_request!(state::DriverState, msg::ShmAttachRequest.Decoder)
    correlation_id = ShmAttachRequest.correlationId(msg)
    stream_id = ShmAttachRequest.streamId(msg)
    client_id = ShmAttachRequest.clientId(msg)
    role = ShmAttachRequest.role(msg)
    expected_layout_version = ShmAttachRequest.expectedLayoutVersion(msg)
    max_dims = ShmAttachRequest.maxDims(msg)

    publish_mode = ShmAttachRequest.publishMode(msg)
    if publish_mode == DriverPublishMode.NULL_VALUE || publish_mode == DriverPublishMode.UNKNOWN
        publish_mode = DriverPublishMode.REQUIRE_EXISTING
    end

    require_hugepages = state.config.shm.require_hugepages
    requested_hugepages = ShmAttachRequest.requireHugepages(msg)
    if requested_hugepages != DriverBool.NULL_VALUE
        require_hugepages = (requested_hugepages == DriverBool.TRUE)
    end

    for lease in values(state.leases)
        if lease.client_id == client_id
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.REJECTED,
                "client_id already attached",
                nothing,
            )
        end
    end

    stream_state = get_or_create_stream!(state, stream_id, publish_mode)
    if isnothing(stream_state)
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "stream not provisioned",
            nothing,
        )
    end

    if expected_layout_version != 0 && expected_layout_version != UInt32(1)
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "layout_version mismatch",
            nothing,
        )
    end

    if max_dims != 0 && max_dims > stream_state.profile.max_dims
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.INVALID_PARAMS,
            "max_dims exceeds profile",
            nothing,
        )
    end

    for lease in values(state.leases)
        if lease.stream_id == stream_id && lease.client_id == client_id && lease.role == role
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.REJECTED,
                "duplicate attach",
                nothing,
            )
        end
    end

    if stream_state.epoch == 0
        try
            bump_epoch!(state, stream_state)
        catch err
            msg = sprint(showerror, err)
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.INTERNAL_ERROR,
                "failed to provision SHM: $(msg)",
                nothing,
            )
        end
    end

    if role == DriverRole.PRODUCER
        if stream_state.producer_lease_id != 0
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.REJECTED,
                "producer already attached",
                nothing,
            )
        end
        try
            bump_epoch!(state, stream_state)
        catch err
            msg = sprint(showerror, err)
            return emit_attach_response!(
                state,
                correlation_id,
                DriverResponseCode.INTERNAL_ERROR,
                "failed to provision SHM: $(msg)",
                nothing,
            )
        end
    end

    if require_hugepages && !state.config.shm.require_hugepages
        return emit_attach_response!(
            state,
            correlation_id,
            DriverResponseCode.REJECTED,
            "hugepages required but unavailable",
            nothing,
        )
    end

    now_ns = UInt64(Clocks.time_nanos(state.clock))
    lease_id = next_lease_id!(state)
    expiry_ns = lease_expiry_ns(state, now_ns)
    lease = DriverLease(lease_id, stream_id, client_id, role, expiry_ns)
    state.leases[lease_id] = lease

    if role == DriverRole.PRODUCER
        stream_state.producer_lease_id = lease_id
    else
        push!(stream_state.consumer_lease_ids, lease_id)
    end

    emit_attach_response!(state, correlation_id, DriverResponseCode.OK, "", stream_state, lease_id, expiry_ns)
    emit_driver_announce!(state, stream_state)
    return true
end

function handle_detach_request!(state::DriverState, msg::ShmDetachRequest.Decoder)
    correlation_id = ShmDetachRequest.correlationId(msg)
    lease_id = ShmDetachRequest.leaseId(msg)
    stream_id = ShmDetachRequest.streamId(msg)
    client_id = ShmDetachRequest.clientId(msg)
    role = ShmDetachRequest.role(msg)

    lease = get(state.leases, lease_id, nothing)
    if isnothing(lease) ||
       lease.stream_id != stream_id ||
       lease.client_id != client_id ||
       lease.role != role
        return emit_detach_response!(state, correlation_id, DriverResponseCode.REJECTED, "unknown lease")
    end

    revoke_lease!(state, lease_id, DriverLeaseRevokeReason.DETACHED, UInt64(Clocks.time_nanos(state.clock)))
    return emit_detach_response!(state, correlation_id, DriverResponseCode.OK, "")
end

function handle_keepalive!(state::DriverState, msg::ShmLeaseKeepalive.Decoder)
    lease_id = ShmLeaseKeepalive.leaseId(msg)
    lease = get(state.leases, lease_id, nothing)
    if isnothing(lease)
        return false
    end
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    lease.expiry_ns = lease_expiry_ns(state, now_ns)
    state.metrics.keepalives += 1
    return true
end

function revoke_lease!(state::DriverState, lease_id::UInt64, reason::DriverLeaseRevokeReason.SbeEnum, now_ns::UInt64)
    lease = get(state.leases, lease_id, nothing)
    isnothing(lease) && return false

    stream_state = get(state.streams, lease.stream_id, nothing)
    if !isnothing(stream_state)
        if lease.role == DriverRole.PRODUCER
            stream_state.producer_lease_id = 0
            emit_lease_revoked!(state, lease, reason, now_ns)
            bump_epoch!(state, stream_state)
            emit_driver_announce!(state, stream_state)
        else
            delete!(stream_state.consumer_lease_ids, lease_id)
        end
    end

    lease.role == DriverRole.PRODUCER || emit_lease_revoked!(state, lease, reason, now_ns)
    delete!(state.leases, lease_id)
    return true
end

function bump_epoch!(state::DriverState, stream_state::DriverStreamState)
    stream_state.epoch = stream_state.epoch == 0 ? UInt64(1) : stream_state.epoch + 1
    provision_stream_epoch!(state, stream_state)
    return nothing
end

function provision_stream_epoch!(state::DriverState, stream_state::DriverStreamState)
    pool_ids = [pool.pool_id for pool in stream_state.profile.payload_pools]
    header_uri, pool_uris = canonical_shm_paths(
        state.config.shm.base_dir,
        "stream-$(stream_state.stream_id)",
        state.config.endpoints.instance_id,
        stream_state.epoch,
        pool_ids,
    )
    if state.config.shm.require_hugepages
        header_uri = add_hugepage_flag(header_uri)
        for (pool_id, uri) in pool_uris
            pool_uris[pool_id] = add_hugepage_flag(uri)
        end
    end
    stream_state.header_uri = header_uri
    stream_state.pool_uris = pool_uris

    header_path = parse_shm_uri(header_uri).path
    header_size = SUPERBLOCK_SIZE + Int(stream_state.profile.header_nslots) * HEADER_SLOT_BYTES
    ensure_shm_file!(state, header_path, header_size, state.config.shm.permissions_mode)
    header_mmap = mmap_shm(header_uri, header_size; write = true)
    wrap_superblock!(state.runtime.superblock_encoder, header_mmap, 0)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    write_superblock!(
        state.runtime.superblock_encoder,
        SuperblockFields(
            MAGIC_TPOLSHM1,
            UInt32(1),
            stream_state.epoch,
            stream_state.stream_id,
            RegionType.HEADER_RING,
            UInt16(0),
            stream_state.profile.header_nslots,
            UInt32(HEADER_SLOT_BYTES),
            UInt32(0),
            UInt64(getpid()),
            now_ns,
            now_ns,
        ),
    )

    for pool in stream_state.profile.payload_pools
        pool_uri = stream_state.pool_uris[pool.pool_id]
        pool_path = parse_shm_uri(pool_uri).path
        pool_size = SUPERBLOCK_SIZE + Int(stream_state.profile.header_nslots) * Int(pool.stride_bytes)
        ensure_shm_file!(state, pool_path, pool_size, state.config.shm.permissions_mode)
        pool_mmap = mmap_shm(pool_uri, pool_size; write = true)
        wrap_superblock!(state.runtime.superblock_encoder, pool_mmap, 0)
        write_superblock!(
            state.runtime.superblock_encoder,
            SuperblockFields(
                MAGIC_TPOLSHM1,
                UInt32(1),
                stream_state.epoch,
                stream_state.stream_id,
                RegionType.PAYLOAD_POOL,
                pool.pool_id,
                stream_state.profile.header_nslots,
                pool.stride_bytes,
                pool.stride_bytes,
                UInt64(getpid()),
                now_ns,
                now_ns,
            ),
        )
    end
    return nothing
end

@inline function parse_mode(mode_str::String)
    return parse(UInt32, mode_str; base = 8)
end

function ensure_shm_file!(state::DriverState, path::String, size::Int, mode_str::String)
    isabspath(path) || throw(ArgumentError("SHM path must be absolute"))
    path_allowed(path, state.config.shm.allowed_base_dirs) ||
        throw(ArgumentError("SHM path not within allowed_base_dirs"))
    if state.config.shm.require_hugepages && !is_hugetlbfs_path(path)
        throw(ArgumentError("SHM path not on hugetlbfs"))
    end
    mkpath(dirname(path))
    if ispath(path) && !isfile(path)
        throw(ArgumentError("SHM path must be a regular file"))
    end
    open(path, "w+") do io
        truncate(io, size)
    end
    isfile(path) || throw(ArgumentError("SHM path not a regular file"))
    chmod(path, parse_mode(mode_str))
    return nothing
end

@inline function add_hugepage_flag(uri::String)
    return "$(uri)|require_hugepages=true"
end

function path_allowed(path::String, allowed_dirs::Vector{String})
    abs_path = abspath(path)
    abs_path = ispath(abs_path) ? realpath(abs_path) : abs_path
    for dir in allowed_dirs
        abs_dir = abspath(dir)
        abs_dir = ispath(abs_dir) ? realpath(abs_dir) : abs_dir
        if abs_path == abs_dir || startswith(abs_path, abs_dir * "/")
            return true
        end
    end
    return false
end

function emit_attach_response!(
    state::DriverState,
    correlation_id::Int64,
    code::DriverResponseCode.SbeEnum,
    error_message::String,
    stream_state::Union{DriverStreamState, Nothing},
    lease_id::UInt64 = typemax(UInt64),
    lease_expiry_ns::UInt64 = typemax(UInt64),
)
    payload_count = isnothing(stream_state) ? 0 : length(stream_state.profile.payload_pools)
    header_uri_len = isnothing(stream_state) ? 0 : sizeof(stream_state.header_uri)
    error_len = isempty(error_message) ? 0 : sizeof(error_message)
    pools_len = 0
    if !isnothing(stream_state)
        for pool in stream_state.profile.payload_pools
            pools_len += 10
            pools_len += ShmAttachResponse.PayloadPools.regionUri_header_length
            pools_len += sizeof(stream_state.pool_uris[pool.pool_id])
        end
    end

    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmAttachResponse.sbe_block_length(ShmAttachResponse.Decoder)) +
        DRIVER_GROUP_HEADER_LEN +
        pools_len +
        (isnothing(stream_state) ? ShmAttachResponse.headerRegionUri_header_length :
         ShmAttachResponse.headerRegionUri_header_length + header_uri_len) +
        (isempty(error_message) ? ShmAttachResponse.errorMessage_header_length :
         ShmAttachResponse.errorMessage_header_length + error_len)

    return try_claim_sbe!(state.runtime.pub_control, state.runtime.control_claim, msg_len) do buf
        ShmAttachResponse.wrap_and_apply_header!(state.runtime.attach_encoder, buf, 0)
        ShmAttachResponse.correlationId!(state.runtime.attach_encoder, correlation_id)
        ShmAttachResponse.code!(state.runtime.attach_encoder, code)

        if code == DriverResponseCode.OK && !isnothing(stream_state)
            ShmAttachResponse.leaseId!(state.runtime.attach_encoder, lease_id)
            ShmAttachResponse.leaseExpiryTimestampNs!(state.runtime.attach_encoder, lease_expiry_ns)
            ShmAttachResponse.streamId!(state.runtime.attach_encoder, stream_state.stream_id)
            ShmAttachResponse.epoch!(state.runtime.attach_encoder, stream_state.epoch)
            ShmAttachResponse.layoutVersion!(state.runtime.attach_encoder, UInt32(1))
            ShmAttachResponse.headerNslots!(state.runtime.attach_encoder, stream_state.profile.header_nslots)
            ShmAttachResponse.headerSlotBytes!(state.runtime.attach_encoder, UInt16(HEADER_SLOT_BYTES))
            ShmAttachResponse.maxDims!(state.runtime.attach_encoder, stream_state.profile.max_dims)

            pools_group = ShmAttachResponse.payloadPools!(state.runtime.attach_encoder, payload_count)
            for pool in stream_state.profile.payload_pools
                entry = ShmAttachResponse.PayloadPools.next!(pools_group)
                ShmAttachResponse.PayloadPools.poolId!(entry, pool.pool_id)
                ShmAttachResponse.PayloadPools.poolNslots!(entry, stream_state.profile.header_nslots)
                ShmAttachResponse.PayloadPools.strideBytes!(entry, pool.stride_bytes)
                ShmAttachResponse.PayloadPools.regionUri!(entry, stream_state.pool_uris[pool.pool_id])
            end
            ShmAttachResponse.headerRegionUri!(state.runtime.attach_encoder, stream_state.header_uri)
            ShmAttachResponse.errorMessage!(state.runtime.attach_encoder, error_message)
        else
            ShmAttachResponse.leaseId!(state.runtime.attach_encoder, typemax(UInt64))
            ShmAttachResponse.leaseExpiryTimestampNs!(state.runtime.attach_encoder, typemax(UInt64))
            ShmAttachResponse.streamId!(state.runtime.attach_encoder, typemax(UInt32))
            ShmAttachResponse.epoch!(state.runtime.attach_encoder, typemax(UInt64))
            ShmAttachResponse.layoutVersion!(state.runtime.attach_encoder, typemax(UInt32))
            ShmAttachResponse.headerNslots!(state.runtime.attach_encoder, typemax(UInt32))
            ShmAttachResponse.headerSlotBytes!(state.runtime.attach_encoder, typemax(UInt16))
            ShmAttachResponse.maxDims!(state.runtime.attach_encoder, typemax(UInt8))
            ShmAttachResponse.payloadPools!(state.runtime.attach_encoder, 0)
            ShmAttachResponse.headerRegionUri!(state.runtime.attach_encoder, "")
            ShmAttachResponse.errorMessage!(state.runtime.attach_encoder, error_message)
        end
    end && (state.metrics.attach_responses += 1; true)
end

function emit_detach_response!(
    state::DriverState,
    correlation_id::Int64,
    code::DriverResponseCode.SbeEnum,
    error_message::String,
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmDetachResponse.sbe_block_length(ShmDetachResponse.Decoder)) +
        ShmDetachResponse.errorMessage_header_length +
        sizeof(error_message)

    return try_claim_sbe!(state.runtime.pub_control, state.runtime.control_claim, msg_len) do buf
        ShmDetachResponse.wrap_and_apply_header!(state.runtime.detach_encoder, buf, 0)
        ShmDetachResponse.correlationId!(state.runtime.detach_encoder, correlation_id)
        ShmDetachResponse.code!(state.runtime.detach_encoder, code)
        ShmDetachResponse.errorMessage!(state.runtime.detach_encoder, error_message)
    end && (state.metrics.detach_responses += 1; true)
end

function emit_lease_revoked!(
    state::DriverState,
    lease::DriverLease,
    reason::DriverLeaseRevokeReason.SbeEnum,
    now_ns::UInt64,
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmLeaseRevoked.sbe_block_length(ShmLeaseRevoked.Decoder)) +
        ShmLeaseRevoked.errorMessage_header_length
    return try_claim_sbe!(state.runtime.pub_control, state.runtime.control_claim, msg_len) do buf
        ShmLeaseRevoked.wrap_and_apply_header!(state.runtime.revoke_encoder, buf, 0)
        ShmLeaseRevoked.timestampNs!(state.runtime.revoke_encoder, now_ns)
        ShmLeaseRevoked.leaseId!(state.runtime.revoke_encoder, lease.lease_id)
        ShmLeaseRevoked.streamId!(state.runtime.revoke_encoder, lease.stream_id)
        ShmLeaseRevoked.clientId!(state.runtime.revoke_encoder, lease.client_id)
        ShmLeaseRevoked.role!(state.runtime.revoke_encoder, lease.role)
        ShmLeaseRevoked.reason!(state.runtime.revoke_encoder, reason)
        ShmLeaseRevoked.errorMessage!(state.runtime.revoke_encoder, "")
    end && (state.metrics.lease_revoked += 1; true)
end

function emit_driver_announce!(state::DriverState, stream_state::DriverStreamState)
    payload_count = length(stream_state.profile.payload_pools)
    msg_len = MESSAGE_HEADER_LEN +
        Int(ShmPoolAnnounce.sbe_block_length(ShmPoolAnnounce.Decoder)) +
        4 +
        sum(
            10 + ShmPoolAnnounce.PayloadPools.regionUri_header_length +
            sizeof(stream_state.pool_uris[pool.pool_id])
            for pool in stream_state.profile.payload_pools
        ) +
        ShmPoolAnnounce.headerRegionUri_header_length +
        sizeof(stream_state.header_uri)

    return try_claim_sbe!(state.runtime.pub_announce, state.runtime.control_claim, msg_len) do buf
        ShmPoolAnnounce.wrap_and_apply_header!(state.runtime.announce_encoder, buf, 0)
        ShmPoolAnnounce.streamId!(state.runtime.announce_encoder, stream_state.stream_id)
        ShmPoolAnnounce.producerId!(state.runtime.announce_encoder, UInt32(0))
        ShmPoolAnnounce.epoch!(state.runtime.announce_encoder, stream_state.epoch)
        ShmPoolAnnounce.layoutVersion!(state.runtime.announce_encoder, UInt32(1))
        ShmPoolAnnounce.headerNslots!(state.runtime.announce_encoder, stream_state.profile.header_nslots)
        ShmPoolAnnounce.headerSlotBytes!(state.runtime.announce_encoder, UInt16(HEADER_SLOT_BYTES))
        ShmPoolAnnounce.maxDims!(state.runtime.announce_encoder, stream_state.profile.max_dims)

        pools_group = ShmPoolAnnounce.payloadPools!(state.runtime.announce_encoder, payload_count)
        for pool in stream_state.profile.payload_pools
            entry = ShmPoolAnnounce.PayloadPools.next!(pools_group)
            ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
            ShmPoolAnnounce.PayloadPools.poolNslots!(entry, stream_state.profile.header_nslots)
            ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
            ShmPoolAnnounce.PayloadPools.regionUri!(entry, stream_state.pool_uris[pool.pool_id])
        end
        ShmPoolAnnounce.headerRegionUri!(state.runtime.announce_encoder, stream_state.header_uri)
    end && (state.metrics.announces += 1; true)
end

function emit_driver_shutdown!(
    state::DriverState,
    reason::DriverShutdownReason.SbeEnum = DriverShutdownReason.NORMAL,
    error_message::String = "",
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmDriverShutdown.sbe_block_length(ShmDriverShutdown.Decoder)) +
        ShmDriverShutdown.errorMessage_header_length +
        sizeof(error_message)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    return try_claim_sbe!(state.runtime.pub_control, state.runtime.control_claim, msg_len) do buf
        ShmDriverShutdown.wrap_and_apply_header!(state.runtime.shutdown_encoder, buf, 0)
        ShmDriverShutdown.timestampNs!(state.runtime.shutdown_encoder, now_ns)
        ShmDriverShutdown.reason!(state.runtime.shutdown_encoder, reason)
        ShmDriverShutdown.errorMessage!(state.runtime.shutdown_encoder, error_message)
    end
end
