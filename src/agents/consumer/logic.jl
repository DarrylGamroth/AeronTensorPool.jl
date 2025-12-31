"""
Initialize a consumer: create Aeron resources and initial timers.
"""
function init_consumer(config::ConsumerConfig)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    ctx = Aeron.Context()
    set_aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)

    sub_descriptor = Aeron.add_subscription(client, config.aeron_uri, config.descriptor_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)

    timer_set = TimerSet(
        (PolledTimer(config.hello_interval_ns), PolledTimer(config.qos_interval_ns)),
        (ConsumerHelloHandler(), ConsumerQosHandler()),
    )

    runtime = ConsumerRuntime(
        ctx,
        client,
        pub_control,
        pub_qos,
        sub_descriptor,
        sub_control,
        sub_qos,
        Vector{UInt8}(undef, 512),
        Vector{UInt8}(undef, 512),
        ConsumerHello.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Vector{Int64}(undef, MAX_DIMS),
        Vector{Int64}(undef, MAX_DIMS),
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
    )
    return ConsumerState(config, clock, runtime, mappings, metrics, timer_set)
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
    ShmPoolAnnounce.layoutVersion(msg) == state.config.expected_layout_version || return false
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
    sent = try_claim_sbe!(state.runtime.pub_control, state.runtime.hello_claim, CONSUMER_HELLO_LEN) do buf
        ConsumerHello.wrap_and_apply_header!(state.runtime.hello_encoder, buf, 0)
        ConsumerHello.streamId!(state.runtime.hello_encoder, state.config.stream_id)
        ConsumerHello.consumerId!(state.runtime.hello_encoder, state.config.consumer_id)
        ConsumerHello.supportsShm!(
            state.runtime.hello_encoder,
            state.config.supports_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerHello.supportsProgress!(
            state.runtime.hello_encoder,
            state.config.supports_progress ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerHello.mode!(state.runtime.hello_encoder, state.config.mode)
        ConsumerHello.maxRateHz!(state.runtime.hello_encoder, state.config.max_rate_hz)
        ConsumerHello.expectedLayoutVersion!(state.runtime.hello_encoder, state.config.expected_layout_version)
        ConsumerHello.progressIntervalUs!(state.runtime.hello_encoder, progress_interval)
        ConsumerHello.progressBytesDelta!(state.runtime.hello_encoder, progress_bytes)
        ConsumerHello.progressRowsDelta!(state.runtime.hello_encoder, progress_rows)
    end
    sent || return false
    state.metrics.hello_count += 1
    return true
end

"""
Emit a QosConsumer message with drop counters and last_seq_seen.
"""
function emit_qos!(state::ConsumerState)
    sent = try_claim_sbe!(state.runtime.pub_qos, state.runtime.qos_claim, QOS_CONSUMER_LEN) do buf
        QosConsumer.wrap_and_apply_header!(state.runtime.qos_encoder, buf, 0)
        QosConsumer.streamId!(state.runtime.qos_encoder, state.config.stream_id)
        QosConsumer.consumerId!(state.runtime.qos_encoder, state.config.consumer_id)
        QosConsumer.epoch!(state.runtime.qos_encoder, state.mappings.mapped_epoch)
        QosConsumer.lastSeqSeen!(state.runtime.qos_encoder, state.metrics.last_seq_seen)
        QosConsumer.dropsGap!(state.runtime.qos_encoder, state.metrics.drops_gap)
        QosConsumer.dropsLate!(state.runtime.qos_encoder, state.metrics.drops_late)
        QosConsumer.mode!(state.runtime.qos_encoder, state.config.mode)
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
"""
function try_read_frame!(
    state::ConsumerState,
    desc::FrameDescriptor.Decoder,
)
    state.mappings.header_mmap === nothing && return nothing
    FrameDescriptor.epoch(desc) == state.mappings.mapped_epoch || return nothing
    seq = FrameDescriptor.seq(desc)
    should_process(state, seq) || return nothing

    header_index = FrameDescriptor.headerIndex(desc)
    if state.mappings.mapped_nslots == 0 || header_index >= state.mappings.mapped_nslots
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return nothing
    end

    header_offset = header_slot_offset(header_index)
    header_mmap = state.mappings.header_mmap::Vector{UInt8}

    commit_ptr = Ptr{UInt64}(pointer(header_mmap, header_offset + 1))
    first = seqlock_read_begin(commit_ptr)
    if seqlock_is_write_in_progress(first)
        state.metrics.drops_late += 1
        state.metrics.drops_odd += 1
        return nothing
    end

    hdr_dec = TensorSlotHeader256.Decoder(Vector{UInt8})
    header = try
        wrap_tensor_header!(hdr_dec, header_mmap, header_offset)
        read_tensor_slot_header(hdr_dec)
    catch
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return nothing
    end

    second = seqlock_read_end(commit_ptr)
    if first != second || seqlock_is_write_in_progress(second)
        state.metrics.drops_late += 1
        state.metrics.drops_changed += 1
        return nothing
    end

    commit_frame = second >> 1
    if commit_frame != header.frame_id
        state.metrics.drops_late += 1
        state.metrics.drops_frame_id_mismatch += 1
        return nothing
    end

    last_commit = state.mappings.last_commit_words[Int(header_index) + 1]
    if second < last_commit
        state.metrics.drops_late += 1
        state.metrics.drops_changed += 1
        return nothing
    end

    if header.frame_id != seq
        state.metrics.drops_late += 1
        state.metrics.drops_frame_id_mismatch += 1
        return nothing
    end

    if header.payload_slot != header_index
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return nothing
    end

    if header.payload_offset != 0
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return nothing
    end

    if !valid_dtype(header.dtype) || !valid_major_order(header.major_order)
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return nothing
    end

    elem_size = dtype_size_bytes(header.dtype)
    if elem_size == 0 || header.ndims > state.config.max_dims ||
       !validate_strides!(state, header, elem_size)
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        return nothing
    end

    pool_stride = get(state.mappings.pool_stride_bytes, header.pool_id, UInt32(0))
    if pool_stride == 0
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        return nothing
    end
    payload_mmap = get(state.mappings.payload_mmaps, header.pool_id, nothing)
    if payload_mmap === nothing
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        return nothing
    end

    payload_len = Int(header.values_len_bytes)
    if payload_len > Int(pool_stride)
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        return nothing
    end
    payload_offset = SUPERBLOCK_SIZE + Int(header.payload_slot) * Int(pool_stride)
    payload = view(payload_mmap, payload_offset + 1:payload_offset + payload_len)

    maybe_track_gap!(state, seq)
    state.mappings.last_commit_words[Int(header_index) + 1] = second
    return (header, payload)
end
