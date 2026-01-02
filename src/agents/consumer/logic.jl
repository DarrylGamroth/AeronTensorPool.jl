"""
Initialize a consumer: create Aeron resources and initial timers.
"""
function init_consumer(config::ConsumerSettings; client::Aeron.Client)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)
    announce_join_ns = UInt64(Clocks.time_nanos(clock))

    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)

    sub_descriptor = Aeron.add_subscription(client, config.aeron_uri, config.descriptor_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)
    sub_progress = nothing

    timer_set = TimerSet(
        (PolledTimer(config.hello_interval_ns), PolledTimer(config.qos_interval_ns)),
        (ConsumerHelloHandler(), ConsumerQosHandler()),
    )

    control = ControlPlaneRuntime(client, pub_control, sub_control)
    runtime = ConsumerRuntime(
        control,
        pub_qos,
        sub_descriptor,
        sub_qos,
        sub_progress,
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        Vector{UInt8}(undef, CONTROL_BUF_BYTES),
        ConsumerHello.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        TensorSlotHeader256.Decoder(Vector{UInt8}),
        Vector{Int64}(undef, MAX_DIMS),
        Vector{Int64}(undef, MAX_DIMS),
        ConsumerFrameView(
            TensorSlotHeader(
                UInt64(0),
                UInt64(0),
                UInt64(0),
                UInt32(0),
                UInt32(0),
                UInt32(0),
                UInt32(0),
                UInt16(0),
                Dtype.UNKNOWN,
                MajorOrder.ROW,
                UInt8(0),
                UInt8(0),
                ntuple(_ -> Int32(0), Val(MAX_DIMS)),
                ntuple(_ -> Int32(0), Val(MAX_DIMS)),
            ),
            PayloadSlice(UInt8[], 0, 0),
        ),
    )
    mappings = ConsumerMappings(
        UInt64(0),
        nothing,
        Dict{UInt16, Vector{UInt8}}(),
        Dict{UInt16, UInt32}(),
        UInt32(0),
        UInt64(0),
        UInt64[],
    )
    metrics = ConsumerMetrics(
        UInt64(0),
        false,
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
    )
    dummy_handler = Aeron.FragmentHandler(nothing) do _, _, _
        nothing
    end
    dummy_assembler = Aeron.FragmentAssembler(dummy_handler)
    state = ConsumerState(
        config,
        clock,
        announce_join_ns,
        runtime,
        mappings,
        metrics,
        nothing,
        true,
        Int64(0),
        timer_set,
        "",
        UInt32(0),
        "",
        UInt32(0),
        dummy_assembler,
    )
    state.progress_assembler = make_progress_assembler(state)
    return state
end

"""
Initialize a consumer using driver-provisioned SHM regions.
"""
function init_consumer_from_attach(
    config::ConsumerSettings,
    attach::AttachResponseInfo;
    driver_client::Union{DriverClientState, Nothing} = nothing,
    client::Aeron.Client,
)
    attach.code == DriverResponseCode.OK || throw(ArgumentError("attach failed"))
    attach.stream_id == config.stream_id || throw(ArgumentError("stream_id mismatch"))
    state = init_consumer(config; client = client)
    ok = map_from_attach_response!(state, attach)
    ok || throw(ArgumentError("failed to map SHM from attach"))
    state.driver_client = driver_client
    state.driver_active = true
    return state
end

@inline function consumer_driver_active(state::ConsumerState)
    dc = state.driver_client
    dc === nothing && return true
    return state.driver_active && dc.lease_id != 0 && !dc.revoked && !dc.shutdown
end

"""
Remap consumer SHM from a driver attach response.
"""
function remap_consumer_from_attach!(state::ConsumerState, attach::AttachResponseInfo)
    reset_mappings!(state)
    state.config.use_shm = true
    ok = map_from_attach_response!(state, attach)
    state.driver_active = ok
    return ok
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ConsumerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0

    if dc.revoked || dc.shutdown
        state.driver_active = false
        reset_mappings!(state)
    end

    if !state.driver_active && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.expected_layout_version,
            max_dims = state.config.max_dims,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            require_hugepages = state.config.require_hugepages,
        )
        if cid != 0
            state.pending_attach_id = cid
            work_count += 1
        end
    end

    if state.pending_attach_id != 0
        attach = dc.poller.last_attach
        if attach !== nothing && attach.correlation_id == state.pending_attach_id
            state.pending_attach_id = Int64(0)
            if attach.code == DriverResponseCode.OK
                apply_attach!(dc, attach)
                state.driver_active = remap_consumer_from_attach!(state, attach)
                state.driver_active || (dc.lease_id = UInt64(0))
            else
                state.driver_active = false
            end
        end
    end
    return work_count
end

@inline function should_process(state::ConsumerState, seq::UInt64)
    if state.config.mode == Mode.DECIMATED
        return state.config.decimation > 0 && (seq % state.config.decimation == 0)
    end
    return true
end

"""
Validate stride_bytes against alignment and hugepage requirements.
"""
function validate_stride(
    stride_bytes::UInt32;
    require_hugepages::Bool,
    page_size_bytes::Int = page_size_bytes(),
    hugepage_size::Int = 0,
)
    ispow2(stride_bytes) || return false
    (stride_bytes % UInt32(page_size_bytes)) == 0 || return false
    if require_hugepages
        hugepage_size > 0 || return false
        (stride_bytes % UInt32(hugepage_size)) == 0 || return false
    end
    return true
end

"""
Validate superblock fields against expected layout and mapping rules.
"""
function validate_superblock_fields(
    fields::SuperblockFields;
    expected_layout_version::UInt32,
    expected_epoch::UInt64,
    expected_stream_id::UInt32,
    expected_nslots::UInt32,
    expected_slot_bytes::UInt32,
    expected_region_type::RegionType.SbeEnum,
    expected_pool_id::UInt16,
)
    fields.magic == MAGIC_TPOLSHM1 || return false
    fields.layout_version == expected_layout_version || return false
    fields.epoch == expected_epoch || return false
    fields.stream_id == expected_stream_id || return false
    fields.region_type == expected_region_type || return false
    fields.pool_id == expected_pool_id || return false
    fields.nslots == expected_nslots || return false
    ispow2(fields.nslots) || return false
    fields.slot_bytes == expected_slot_bytes || return false
    return true
end

"""
Map SHM regions from a ShmPoolAnnounce message.
"""
function map_from_announce!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    state.config.use_shm || return false
    ShmPoolAnnounce.headerSlotBytes(msg) == UInt16(HEADER_SLOT_BYTES) || return false
    header_nslots = ShmPoolAnnounce.headerNslots(msg)

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    stride_bytes = Dict{UInt16, UInt32}()
    pool_specs = Vector{PayloadPoolConfig}()

    pools = ShmPoolAnnounce.payloadPools(msg)
    for pool in pools
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_nslots = ShmPoolAnnounce.PayloadPools.poolNslots(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_uri = String(ShmPoolAnnounce.PayloadPools.regionUri(pool))
        push!(pool_specs, PayloadPoolConfig(pool_id, pool_uri, pool_stride, pool_nslots))
    end

    header_uri = String(ShmPoolAnnounce.headerRegionUri(msg))
    validate_uri(header_uri) || return false
    header_parsed = parse_shm_uri(header_uri)
    require_hugepages = header_parsed.require_hugepages || state.config.require_hugepages
    if require_hugepages && !is_hugetlbfs_path(header_parsed.path)
        return false
    end
    hugepage_size = require_hugepages ? hugepage_size_bytes() : 0
    require_hugepages && hugepage_size == 0 && return false
    header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(header_nslots))

    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return false
    end

    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
        expected_epoch = ShmPoolAnnounce.epoch(msg),
        expected_stream_id = ShmPoolAnnounce.streamId(msg),
        expected_nslots = header_nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return false

    for pool in pool_specs
        pool.nslots == header_nslots || return false
        validate_uri(pool.uri) || return false
        pool_parsed = parse_shm_uri(pool.uri)
        pool_require_hugepages = pool_parsed.require_hugepages || require_hugepages
        if pool_require_hugepages && !is_hugetlbfs_path(pool_parsed.path)
            return false
        end
        validate_stride(
            pool.stride_bytes;
            require_hugepages = pool_require_hugepages,
            hugepage_size = hugepage_size,
        ) || return false

        pool_mmap = mmap_shm(pool.uri, SUPERBLOCK_SIZE + Int(pool.nslots) * Int(pool.stride_bytes))
        wrap_superblock!(sb_dec, pool_mmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return false
        end

        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
            expected_epoch = ShmPoolAnnounce.epoch(msg),
            expected_stream_id = ShmPoolAnnounce.streamId(msg),
            expected_nslots = pool.nslots,
            expected_slot_bytes = pool.stride_bytes,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool.pool_id,
        )
        pool_ok || return false

        payload_mmaps[pool.pool_id] = pool_mmap
        stride_bytes[pool.pool_id] = pool.stride_bytes
    end

    state.mappings.header_mmap = header_mmap
    state.mappings.payload_mmaps = payload_mmaps
    state.mappings.pool_stride_bytes = stride_bytes
    state.mappings.mapped_nslots = header_nslots
    state.mappings.mapped_pid = header_fields.pid
    state.mappings.last_commit_words = fill(UInt64(0), Int(header_nslots))
    state.mappings.mapped_epoch = ShmPoolAnnounce.epoch(msg)
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    state.metrics.remap_count += 1
    return true
end

"""
Map SHM regions from a driver attach response.
"""
function map_from_attach_response!(state::ConsumerState, attach::AttachResponseInfo)
    attach.code == DriverResponseCode.OK || return false
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || return false
    header_nslots = attach.header_nslots

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    stride_bytes = Dict{UInt16, UInt32}()

    header_uri = attach.header_region_uri
    validate_uri(header_uri) || return false
    header_parsed = parse_shm_uri(header_uri)
    require_hugepages = state.config.require_hugepages
    if require_hugepages && !is_hugetlbfs_path(header_parsed.path)
        return false
    end
    hugepage_size = require_hugepages ? hugepage_size_bytes() : 0
    require_hugepages && hugepage_size == 0 && return false

    header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(header_nslots))
    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return false
    end

    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = attach.layout_version,
        expected_epoch = attach.epoch,
        expected_stream_id = attach.stream_id,
        expected_nslots = header_nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return false

    for pool in attach.pools
        pool.pool_nslots == header_nslots || return false
        validate_uri(pool.region_uri) || return false
        pool_parsed = parse_shm_uri(pool.region_uri)
        pool_require_hugepages = pool_parsed.require_hugepages || require_hugepages
        if pool_require_hugepages && !is_hugetlbfs_path(pool_parsed.path)
            return false
        end
        validate_stride(
            pool.stride_bytes;
            require_hugepages = pool_require_hugepages,
            hugepage_size = hugepage_size,
        ) || return false

        pool_mmap =
            mmap_shm(pool.region_uri, SUPERBLOCK_SIZE + Int(pool.pool_nslots) * Int(pool.stride_bytes))
        wrap_superblock!(sb_dec, pool_mmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return false
        end
        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = attach.layout_version,
            expected_epoch = attach.epoch,
            expected_stream_id = attach.stream_id,
            expected_nslots = pool.pool_nslots,
            expected_slot_bytes = pool.stride_bytes,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool.pool_id,
        )
        pool_ok || return false

        payload_mmaps[pool.pool_id] = pool_mmap
        stride_bytes[pool.pool_id] = pool.stride_bytes
    end

    state.mappings.header_mmap = header_mmap
    state.mappings.payload_mmaps = payload_mmaps
    state.mappings.pool_stride_bytes = stride_bytes
    state.mappings.mapped_nslots = header_nslots
    state.mappings.mapped_pid = header_fields.pid
    state.mappings.last_commit_words = fill(UInt64(0), Int(header_nslots))
    state.mappings.mapped_epoch = attach.epoch
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    state.metrics.remap_count += 1
    state.config.expected_layout_version = attach.layout_version
    state.config.max_dims = attach.max_dims
    return true
end

function validate_mapped_superblocks!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    header_mmap = state.mappings.header_mmap
    header_mmap === nothing && return :mismatch

    expected_epoch = ShmPoolAnnounce.epoch(msg)
    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return :mismatch
    end

    header_expected_nslots = ShmPoolAnnounce.headerNslots(msg)
    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
        expected_epoch = expected_epoch,
        expected_stream_id = ShmPoolAnnounce.streamId(msg),
        expected_nslots = header_expected_nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return :mismatch
    if state.mappings.mapped_pid != 0 && header_fields.pid != state.mappings.mapped_pid
        return :pid_changed
    end

    pools = ShmPoolAnnounce.payloadPools(msg)
    pool_count = 0
    for pool in pools
        pool_count += 1
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_nslots = ShmPoolAnnounce.PayloadPools.poolNslots(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_mmap = get(state.mappings.payload_mmaps, pool_id, nothing)
        pool_mmap === nothing && return :mismatch

        wrap_superblock!(sb_dec, pool_mmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return :mismatch
        end

        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
            expected_epoch = expected_epoch,
            expected_stream_id = ShmPoolAnnounce.streamId(msg),
            expected_nslots = pool_nslots,
            expected_slot_bytes = pool_stride,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool_id,
        )
        pool_ok || return :mismatch
    end

    pool_count == length(state.mappings.payload_mmaps) || return :mismatch
    return :ok
end

"""
Drop all SHM mappings and reset mapping state.
"""
function reset_mappings!(state::ConsumerState)
    state.mappings.header_mmap = nothing
    empty!(state.mappings.payload_mmaps)
    empty!(state.mappings.pool_stride_bytes)
    state.mappings.mapped_nslots = UInt32(0)
    state.mappings.mapped_pid = UInt64(0)
    empty!(state.mappings.last_commit_words)
    state.mappings.mapped_epoch = UInt64(0)
    state.metrics.last_seq_seen = UInt64(0)
    state.metrics.seen_any = false
    return nothing
end

"""
Handle ShmPoolAnnounce updates, remapping on epoch/layout changes.
"""
function handle_shm_pool_announce!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    ShmPoolAnnounce.streamId(msg) == state.config.stream_id || return false
    consumer_driver_active(state) || return false
    ShmPoolAnnounce.layoutVersion(msg) == state.config.expected_layout_version || return false
    announce_ts = ShmPoolAnnounce.announceTimestampNs(msg)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    if announce_ts == 0
        return false
    end
    if announce_ts + state.config.announce_freshness_ns < state.announce_join_ns ||
       now_ns > announce_ts + state.config.announce_freshness_ns
        return false
    end
    if ShmPoolAnnounce.maxDims(msg) != state.config.max_dims
        if !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            return true
        end
        return false
    end

    if state.mappings.mapped_epoch != 0 && ShmPoolAnnounce.epoch(msg) != state.mappings.mapped_epoch
        reset_mappings!(state)
    end

    if state.mappings.header_mmap === nothing
        ok = map_from_announce!(state, msg)
        if !ok && !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            return true
        end
        return ok
    end

    validation = validate_mapped_superblocks!(state, msg)
    if validation != :ok
        reset_mappings!(state)
        if validation == :pid_changed
            return false
        end
        ok = map_from_announce!(state, msg)
        if !ok && !isempty(state.config.payload_fallback_uri)
            state.config.use_shm = false
            reset_mappings!(state)
            return true
        end
        return ok
    end
    return true
end

function maybe_track_gap!(state::ConsumerState, seq::UInt64)
    if state.metrics.seen_any
        if seq > state.metrics.last_seq_seen + 1
            gap = seq - state.metrics.last_seq_seen - 1
            state.metrics.drops_gap += gap
            if state.config.max_outstanding_seq_gap > 0 &&
               gap > state.config.max_outstanding_seq_gap
                state.metrics.last_seq_seen = seq
                state.metrics.seen_any = false
                return nothing
            end
        end
    else
        state.metrics.seen_any = true
    end
    state.metrics.last_seq_seen = seq
    return nothing
end

"""
Apply a ConsumerConfig message to a live consumer.
"""
function apply_consumer_config!(state::ConsumerState, msg::ConsumerConfigMsg.Decoder)
    ConsumerConfigMsg.streamId(msg) == state.config.stream_id || return false
    ConsumerConfigMsg.consumerId(msg) == state.config.consumer_id || return false

    state.config.use_shm = (ConsumerConfigMsg.useShm(msg) == ShmTensorpoolControl.Bool_.TRUE)
    state.config.mode = ConsumerConfigMsg.mode(msg)
    state.config.decimation = ConsumerConfigMsg.decimation(msg)
    state.config.payload_fallback_uri = String(ConsumerConfigMsg.payloadFallbackUri(msg))

    descriptor_channel = String(ConsumerConfigMsg.descriptorChannel(msg))
    descriptor_stream_id = ConsumerConfigMsg.descriptorStreamId(msg)
    descriptor_null = ConsumerConfigMsg.descriptorStreamId_null_value(ConsumerConfigMsg.Decoder)
    descriptor_assigned =
        !isempty(descriptor_channel) && descriptor_stream_id != 0 && descriptor_stream_id != descriptor_null

    if descriptor_assigned
        if state.assigned_descriptor_stream_id != descriptor_stream_id ||
            state.assigned_descriptor_channel != descriptor_channel
            new_sub = Aeron.add_subscription(
                state.runtime.control.client,
                descriptor_channel,
                Int32(descriptor_stream_id),
            )
            close(state.runtime.sub_descriptor)
            state.runtime.sub_descriptor = new_sub
            state.assigned_descriptor_channel = descriptor_channel
            state.assigned_descriptor_stream_id = descriptor_stream_id
        end
    elseif state.assigned_descriptor_stream_id != 0
        new_sub = Aeron.add_subscription(
            state.runtime.control.client,
            state.config.aeron_uri,
            state.config.descriptor_stream_id,
        )
        close(state.runtime.sub_descriptor)
        state.runtime.sub_descriptor = new_sub
        state.assigned_descriptor_channel = ""
        state.assigned_descriptor_stream_id = UInt32(0)
    end

    control_channel = String(ConsumerConfigMsg.controlChannel(msg))
    control_stream_id = ConsumerConfigMsg.controlStreamId(msg)
    control_null = ConsumerConfigMsg.controlStreamId_null_value(ConsumerConfigMsg.Decoder)
    control_assigned =
        !isempty(control_channel) && control_stream_id != 0 && control_stream_id != control_null

    if control_assigned
        if state.assigned_control_stream_id != control_stream_id ||
            state.assigned_control_channel != control_channel
            new_sub = Aeron.add_subscription(
                state.runtime.control.client,
                control_channel,
                Int32(control_stream_id),
            )
            state.runtime.sub_progress === nothing || close(state.runtime.sub_progress)
            state.runtime.sub_progress = new_sub
            state.assigned_control_channel = control_channel
            state.assigned_control_stream_id = control_stream_id
        end
    elseif state.runtime.sub_progress !== nothing
        close(state.runtime.sub_progress)
        state.runtime.sub_progress = nothing
        state.assigned_control_channel = ""
        state.assigned_control_stream_id = UInt32(0)
    end

    if !state.config.use_shm
        reset_mappings!(state)
    end
    return true
end

"""
Emit a ConsumerHello message for capability negotiation.
"""
function emit_consumer_hello!(state::ConsumerState)
    progress_interval = state.config.progress_interval_us
    progress_bytes = state.config.progress_bytes_delta
    progress_rows = state.config.progress_rows_delta
    if !state.config.supports_progress
        progress_interval = typemax(UInt32)
        progress_bytes = typemax(UInt32)
        progress_rows = typemax(UInt32)
    end

    requested_descriptor_channel = state.config.requested_descriptor_channel
    requested_descriptor_stream_id = state.config.requested_descriptor_stream_id
    requested_control_channel = state.config.requested_control_channel
    requested_control_stream_id = state.config.requested_control_stream_id

    descriptor_requested =
        !isempty(requested_descriptor_channel) && requested_descriptor_stream_id != 0
    control_requested = !isempty(requested_control_channel) && requested_control_stream_id != 0

    msg_len = MESSAGE_HEADER_LEN +
        Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder)) +
        Int(ConsumerHello.descriptorChannel_header_length) +
        (descriptor_requested ? sizeof(requested_descriptor_channel) : 0) +
        Int(ConsumerHello.controlChannel_header_length) +
        (control_requested ? sizeof(requested_control_channel) : 0)

    sent = let st = state,
        interval = progress_interval,
        bytes = progress_bytes,
        rows = progress_rows,
        descriptor_requested = descriptor_requested,
        control_requested = control_requested,
        requested_descriptor_channel = requested_descriptor_channel,
        requested_descriptor_stream_id = requested_descriptor_stream_id,
        requested_control_channel = requested_control_channel,
        requested_control_stream_id = requested_control_stream_id
        try_claim_sbe!(st.runtime.control.pub_control, st.runtime.hello_claim, msg_len) do buf
            ConsumerHello.wrap_and_apply_header!(st.runtime.hello_encoder, buf, 0)
            ConsumerHello.streamId!(st.runtime.hello_encoder, st.config.stream_id)
            ConsumerHello.consumerId!(st.runtime.hello_encoder, st.config.consumer_id)
            ConsumerHello.supportsShm!(
                st.runtime.hello_encoder,
                st.config.supports_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerHello.supportsProgress!(
                st.runtime.hello_encoder,
                st.config.supports_progress ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerHello.mode!(st.runtime.hello_encoder, st.config.mode)
            ConsumerHello.maxRateHz!(st.runtime.hello_encoder, st.config.max_rate_hz)
            ConsumerHello.expectedLayoutVersion!(st.runtime.hello_encoder, st.config.expected_layout_version)
            ConsumerHello.progressIntervalUs!(st.runtime.hello_encoder, interval)
            ConsumerHello.progressBytesDelta!(st.runtime.hello_encoder, bytes)
            ConsumerHello.progressRowsDelta!(st.runtime.hello_encoder, rows)
            ConsumerHello.descriptorStreamId!(
                st.runtime.hello_encoder,
                descriptor_requested ?
                requested_descriptor_stream_id :
                ConsumerHello.descriptorStreamId_null_value(ConsumerHello.Encoder),
            )
            ConsumerHello.controlStreamId!(
                st.runtime.hello_encoder,
                control_requested ? requested_control_stream_id :
                ConsumerHello.controlStreamId_null_value(ConsumerHello.Encoder),
            )
            if descriptor_requested
                ConsumerHello.descriptorChannel!(st.runtime.hello_encoder, requested_descriptor_channel)
            else
                ConsumerHello.descriptorChannel_length!(st.runtime.hello_encoder, 0)
            end
            if control_requested
                ConsumerHello.controlChannel!(st.runtime.hello_encoder, requested_control_channel)
            else
                ConsumerHello.controlChannel_length!(st.runtime.hello_encoder, 0)
            end
        end
    end
    sent || return false
    state.metrics.hello_count += 1
    return true
end

"""
Emit a QosConsumer message with drop counters and last_seq_seen.
"""
function emit_qos!(state::ConsumerState)
    sent = let st = state
        try_claim_sbe!(st.runtime.pub_qos, st.runtime.qos_claim, QOS_CONSUMER_LEN) do buf
            QosConsumer.wrap_and_apply_header!(st.runtime.qos_encoder, buf, 0)
            QosConsumer.streamId!(st.runtime.qos_encoder, st.config.stream_id)
            QosConsumer.consumerId!(st.runtime.qos_encoder, st.config.consumer_id)
            QosConsumer.epoch!(st.runtime.qos_encoder, st.mappings.mapped_epoch)
            QosConsumer.lastSeqSeen!(st.runtime.qos_encoder, st.metrics.last_seq_seen)
            QosConsumer.dropsGap!(st.runtime.qos_encoder, st.metrics.drops_gap)
            QosConsumer.dropsLate!(st.runtime.qos_encoder, st.metrics.drops_late)
            QosConsumer.mode!(st.runtime.qos_encoder, st.config.mode)
        end
    end
    sent || return false
    state.metrics.qos_count += 1
    return true
end

@inline function valid_dtype(dtype::Dtype.SbeEnum)
    return dtype != Dtype.UNKNOWN && dtype != Dtype.NULL_VALUE
end

@inline function valid_major_order(order::MajorOrder.SbeEnum)
    return order == MajorOrder.ROW || order == MajorOrder.COLUMN
end

@inline function dtype_size_bytes(dtype::Dtype.SbeEnum)
    if dtype == Dtype.UINT8 || dtype == Dtype.INT8 || dtype == Dtype.BOOLEAN ||
       dtype == Dtype.BYTES || dtype == Dtype.BIT
        return Int64(1)
    elseif dtype == Dtype.UINT16 || dtype == Dtype.INT16
        return Int64(2)
    elseif dtype == Dtype.UINT32 || dtype == Dtype.INT32 || dtype == Dtype.FLOAT32
        return Int64(4)
    elseif dtype == Dtype.UINT64 || dtype == Dtype.INT64 || dtype == Dtype.FLOAT64
        return Int64(8)
    end
    return Int64(0)
end

"""
Validate decoded strides against element size and payload length.
"""
function validate_strides!(state::ConsumerState, header::TensorSlotHeader, elem_size::Int64)
    ndims = Int(header.ndims)
    ndims == 0 && return true

    for i in 1:ndims
        dim = header.dims[i]
        dim < 0 && return false
        state.runtime.scratch_dims[i] = Int64(dim)
    end

    for i in 1:ndims
        stride = header.strides[i]
        stride < 0 && return false
        state.runtime.scratch_strides[i] = Int64(stride)
    end

    if header.major_order == MajorOrder.ROW
        if state.runtime.scratch_strides[ndims] == 0
            state.runtime.scratch_strides[ndims] = elem_size
        elseif state.runtime.scratch_strides[ndims] < elem_size
            return false
        end
        for i in (ndims - 1):-1:1
            required = state.runtime.scratch_strides[i + 1] * max(state.runtime.scratch_dims[i + 1], 1)
            if state.runtime.scratch_strides[i] == 0
                state.runtime.scratch_strides[i] = required
            end
            state.runtime.scratch_strides[i] < required && return false
        end
        return true
    elseif header.major_order == MajorOrder.COLUMN
        if state.runtime.scratch_strides[1] == 0
            state.runtime.scratch_strides[1] = elem_size
        elseif state.runtime.scratch_strides[1] < elem_size
            return false
        end
        for i in 2:ndims
            required = state.runtime.scratch_strides[i - 1] * max(state.runtime.scratch_dims[i - 1], 1)
            if state.runtime.scratch_strides[i] == 0
                state.runtime.scratch_strides[i] = required
            end
            state.runtime.scratch_strides[i] < required && return false
        end
        return true
    end

    return false
end
"""
Attempt to read a frame from SHM using the seqlock protocol.

Returns true on success and updates the provided `ConsumerFrameView`.
"""
function try_read_frame!(
    state::ConsumerState,
    desc::FrameDescriptor.Decoder,
    view::ConsumerFrameView,
)
    consumer_driver_active(state) || return false
    state.mappings.header_mmap === nothing && return false
    FrameDescriptor.epoch(desc) == state.mappings.mapped_epoch || return false
    seq = FrameDescriptor.seq(desc)
    should_process(state, seq) || return false

    header_index = FrameDescriptor.headerIndex(desc)
    if state.mappings.mapped_nslots == 0 || header_index >= state.mappings.mapped_nslots
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return false
    end

    header_offset = header_slot_offset(header_index)
    header_mmap = state.mappings.header_mmap::Vector{UInt8}

    commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
    first = seqlock_read_begin(commit_ptr)
    if seqlock_is_write_in_progress(first)
        state.metrics.drops_late += 1
        state.metrics.drops_odd += 1
        return false
    end

    header = try
        wrap_tensor_header!(state.runtime.header_decoder, header_mmap, header_offset)
        read_tensor_slot_header(state.runtime.header_decoder)
    catch
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return false
    end

    second = seqlock_read_end(commit_ptr)
    if first != second || seqlock_is_write_in_progress(second)
        state.metrics.drops_late += 1
        state.metrics.drops_changed += 1
        return false
    end

    commit_frame = seqlock_frame_id(second)
    if commit_frame != header.frame_id
        state.metrics.drops_late += 1
        state.metrics.drops_frame_id_mismatch += 1
        return false
    end

    last_commit = state.mappings.last_commit_words[Int(header_index) + 1]
    if second < last_commit
        state.metrics.drops_late += 1
        state.metrics.drops_changed += 1
        return false
    end

    if header.frame_id != seq
        state.metrics.drops_late += 1
        state.metrics.drops_frame_id_mismatch += 1
        return false
    end

    if header.payload_slot != header_index
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return false
    end

    if header.payload_offset != 0
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return false
    end

    if !valid_dtype(header.dtype) || !valid_major_order(header.major_order)
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return false
    end

    elem_size = dtype_size_bytes(header.dtype)
    if elem_size == 0 || header.ndims > state.config.max_dims ||
       !validate_strides!(state, header, elem_size)
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return false
    end

    pool_stride = get(state.mappings.pool_stride_bytes, header.pool_id, UInt32(0))
    if pool_stride == 0
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        return false
    end
    payload_mmap = get(state.mappings.payload_mmaps, header.pool_id, nothing)
    if payload_mmap === nothing
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        return false
    end

    payload_len = Int(header.values_len_bytes)
    if payload_len > Int(pool_stride)
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        return false
    end
    payload_offset = SUPERBLOCK_SIZE + Int(header.payload_slot) * Int(pool_stride)
    payload_mmap_vec = payload_mmap::Vector{UInt8}

    maybe_track_gap!(state, seq)
    state.mappings.last_commit_words[Int(header_index) + 1] = second
    view.header = header
    slice = view.payload
    slice.mmap = payload_mmap_vec
    slice.offset = payload_offset
    slice.len = payload_len
    return true
end

"""
Attempt to read a frame using the state's preallocated frame view.
"""
@inline function try_read_frame!(state::ConsumerState, desc::FrameDescriptor.Decoder)
    return try_read_frame!(state, desc, state.runtime.frame_view)
end
