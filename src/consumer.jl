mutable struct ConsumerConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    control_stream_id::Int32
    qos_stream_id::Int32
    stream_id::UInt32
    consumer_id::UInt32
    expected_layout_version::UInt32
    max_dims::UInt8
    mode::Mode.SbeEnum
    decimation::UInt16
    max_outstanding_seq_gap::UInt32
    use_shm::Bool
    supports_shm::Bool
    supports_progress::Bool
    max_rate_hz::UInt16
    payload_fallback_uri::String
    require_hugepages::Bool
    progress_interval_us::UInt32
    progress_bytes_delta::UInt32
    progress_rows_delta::UInt32
    hello_interval_ns::UInt64
    qos_interval_ns::UInt64
end

mutable struct ConsumerState
    config::ConsumerConfig
    clock::Clocks.AbstractClock
    client::Aeron.Client
    pub_control::Aeron.Publication
    pub_qos::Aeron.Publication
    sub_descriptor::Aeron.Subscription
    sub_control::Aeron.Subscription
    sub_qos::Aeron.Subscription
    mapped_epoch::UInt64
    header_mmap::Union{Nothing, Vector{UInt8}}
    payload_mmaps::Dict{UInt16, Vector{UInt8}}
    pool_stride_bytes::Dict{UInt16, UInt32}
    mapped_nslots::UInt32
    mapped_pid::UInt64
    last_commit_words::Vector{UInt64}
    last_seq_seen::UInt64
    seen_any::Bool
    drops_gap::UInt64
    drops_late::UInt64
    last_hello_ns::UInt64
    last_qos_ns::UInt64
    hello_buf::Vector{UInt8}
    qos_buf::Vector{UInt8}
    hello_encoder::ConsumerHello.Encoder{Vector{UInt8}}
    qos_encoder::QosConsumer.Encoder{Vector{UInt8}}
    hello_claim::Aeron.BufferClaim
    qos_claim::Aeron.BufferClaim
    desc_decoder::FrameDescriptor.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    announce_decoder::ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    config_decoder::ConsumerConfigMsg.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    scratch_dims::Vector{Int64}
    scratch_strides::Vector{Int64}
end

function init_consumer(config::ConsumerConfig)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)

    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)

    sub_descriptor = Aeron.add_subscription(client, config.aeron_uri, config.descriptor_stream_id)
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    sub_qos = Aeron.add_subscription(client, config.aeron_uri, config.qos_stream_id)

    return ConsumerState(
        config,
        clock,
        client,
        pub_control,
        pub_qos,
        sub_descriptor,
        sub_control,
        sub_qos,
        UInt64(0),
        nothing,
        Dict{UInt16, Vector{UInt8}}(),
        Dict{UInt16, UInt32}(),
        UInt32(0),
        UInt64(0),
        UInt64[],
        UInt64(0),
        false,
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        Vector{UInt8}(undef, 512),
        Vector{UInt8}(undef, 512),
        ConsumerHello.Encoder(Vector{UInt8}),
        QosConsumer.Encoder(Vector{UInt8}),
        Aeron.BufferClaim(),
        Aeron.BufferClaim(),
        FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Vector{Int64}(undef, MAX_DIMS),
        Vector{Int64}(undef, MAX_DIMS),
    )
end

@inline function should_process(state::ConsumerState, seq::UInt64)
    if state.config.mode == Mode.DECIMATED
        return state.config.decimation > 0 && (seq % state.config.decimation == 0)
    end
    return true
end

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

function map_from_announce!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    state.config.use_shm || return false
    header_uri = String(ShmPoolAnnounce.headerRegionUri(msg))
    validate_uri(header_uri) || return false
    ShmPoolAnnounce.headerSlotBytes(msg) == UInt16(HEADER_SLOT_BYTES) || return false
    header_parsed = parse_shm_uri(header_uri)
    require_hugepages = header_parsed.require_hugepages || state.config.require_hugepages
    if require_hugepages && !is_hugetlbfs_path(header_parsed.path)
        return false
    end
    hugepage_size = require_hugepages ? hugepage_size_bytes() : 0
    require_hugepages && hugepage_size == 0 && return false
    header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(ShmPoolAnnounce.headerNslots(msg)))

    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return false
    end

    header_expected_nslots = ShmPoolAnnounce.headerNslots(msg)
    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = ShmPoolAnnounce.layoutVersion(msg),
        expected_epoch = ShmPoolAnnounce.epoch(msg),
        expected_stream_id = ShmPoolAnnounce.streamId(msg),
        expected_nslots = header_expected_nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return false

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    stride_bytes = Dict{UInt16, UInt32}()

    pools = ShmPoolAnnounce.payloadPools(msg)
    for pool in pools
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_nslots = ShmPoolAnnounce.PayloadPools.poolNslots(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_uri = String(ShmPoolAnnounce.PayloadPools.regionUri(pool))

        pool_nslots == header_expected_nslots || return false
        validate_uri(pool_uri) || return false
        pool_parsed = parse_shm_uri(pool_uri)
        pool_require_hugepages = pool_parsed.require_hugepages || state.config.require_hugepages
        if pool_require_hugepages && !is_hugetlbfs_path(pool_parsed.path)
            return false
        end
        pool_hugepage_size = pool_require_hugepages ? hugepage_size_bytes() : 0
        pool_require_hugepages && pool_hugepage_size == 0 && return false
        validate_stride(
            pool_stride;
            require_hugepages = pool_require_hugepages,
            hugepage_size = pool_hugepage_size,
        ) || return false

        pool_mmap = mmap_shm(pool_uri, SUPERBLOCK_SIZE + Int(pool_nslots) * Int(pool_stride))
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
            expected_nslots = pool_nslots,
            expected_slot_bytes = pool_stride,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool_id,
        )
        pool_ok || return false

        payload_mmaps[pool_id] = pool_mmap
        stride_bytes[pool_id] = pool_stride
    end

    state.header_mmap = header_mmap
    state.payload_mmaps = payload_mmaps
    state.pool_stride_bytes = stride_bytes
    state.mapped_nslots = header_expected_nslots
    state.mapped_pid = header_fields.pid
    state.last_commit_words = fill(UInt64(0), Int(header_expected_nslots))
    state.mapped_epoch = ShmPoolAnnounce.epoch(msg)
    state.last_seq_seen = UInt64(0)
    state.seen_any = false
    return true
end

function validate_mapped_superblocks!(state::ConsumerState, msg::ShmPoolAnnounce.Decoder)
    header_mmap = state.header_mmap
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
    if state.mapped_pid != 0 && header_fields.pid != state.mapped_pid
        return :pid_changed
    end

    pools = ShmPoolAnnounce.payloadPools(msg)
    pool_count = 0
    for pool in pools
        pool_count += 1
        pool_id = ShmPoolAnnounce.PayloadPools.poolId(pool)
        pool_nslots = ShmPoolAnnounce.PayloadPools.poolNslots(pool)
        pool_stride = ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        pool_mmap = get(state.payload_mmaps, pool_id, nothing)
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

    pool_count == length(state.payload_mmaps) || return :mismatch
    return :ok
end

function reset_mappings!(state::ConsumerState)
    state.header_mmap = nothing
    empty!(state.payload_mmaps)
    empty!(state.pool_stride_bytes)
    state.mapped_nslots = UInt32(0)
    state.mapped_pid = UInt64(0)
    empty!(state.last_commit_words)
    state.mapped_epoch = UInt64(0)
    state.last_seq_seen = UInt64(0)
    state.seen_any = false
    return nothing
end

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

    if state.mapped_epoch != 0 && ShmPoolAnnounce.epoch(msg) != state.mapped_epoch
        reset_mappings!(state)
    end

    if state.header_mmap === nothing
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
    if state.seen_any
        if seq > state.last_seq_seen + 1
            gap = seq - state.last_seq_seen - 1
            state.drops_gap += gap
            if state.config.max_outstanding_seq_gap > 0 &&
               gap > state.config.max_outstanding_seq_gap
                state.last_seq_seen = seq
                state.seen_any = false
                return nothing
            end
        end
    else
        state.seen_any = true
    end
    state.last_seq_seen = seq
    return nothing
end

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

function emit_consumer_hello!(state::ConsumerState)
    progress_interval = state.config.progress_interval_us
    progress_bytes = state.config.progress_bytes_delta
    progress_rows = state.config.progress_rows_delta
    if !state.config.supports_progress
        progress_interval = typemax(UInt32)
        progress_bytes = typemax(UInt32)
        progress_rows = typemax(UInt32)
    end
    sent = try_claim_sbe!(state.pub_control, state.hello_claim, CONSUMER_HELLO_LEN) do buf
        ConsumerHello.wrap_and_apply_header!(state.hello_encoder, buf, 0)
        ConsumerHello.streamId!(state.hello_encoder, state.config.stream_id)
        ConsumerHello.consumerId!(state.hello_encoder, state.config.consumer_id)
        ConsumerHello.supportsShm!(
            state.hello_encoder,
            state.config.supports_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerHello.supportsProgress!(
            state.hello_encoder,
            state.config.supports_progress ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerHello.mode!(state.hello_encoder, state.config.mode)
        ConsumerHello.maxRateHz!(state.hello_encoder, state.config.max_rate_hz)
        ConsumerHello.expectedLayoutVersion!(state.hello_encoder, state.config.expected_layout_version)
        ConsumerHello.progressIntervalUs!(state.hello_encoder, progress_interval)
        ConsumerHello.progressBytesDelta!(state.hello_encoder, progress_bytes)
        ConsumerHello.progressRowsDelta!(state.hello_encoder, progress_rows)
    end
    if !sent
        ConsumerHello.wrap_and_apply_header!(state.hello_encoder, state.hello_buf, 0)
        ConsumerHello.streamId!(state.hello_encoder, state.config.stream_id)
        ConsumerHello.consumerId!(state.hello_encoder, state.config.consumer_id)
        ConsumerHello.supportsShm!(
            state.hello_encoder,
            state.config.supports_shm ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerHello.supportsProgress!(
            state.hello_encoder,
            state.config.supports_progress ? ShmTensorpoolControl.Bool_.TRUE : ShmTensorpoolControl.Bool_.FALSE,
        )
        ConsumerHello.mode!(state.hello_encoder, state.config.mode)
        ConsumerHello.maxRateHz!(state.hello_encoder, state.config.max_rate_hz)
        ConsumerHello.expectedLayoutVersion!(state.hello_encoder, state.config.expected_layout_version)
        ConsumerHello.progressIntervalUs!(state.hello_encoder, progress_interval)
        ConsumerHello.progressBytesDelta!(state.hello_encoder, progress_bytes)
        ConsumerHello.progressRowsDelta!(state.hello_encoder, progress_rows)
        Aeron.offer(
            state.pub_control,
            view(state.hello_buf, 1:sbe_message_length(state.hello_encoder)),
        )
    end
    return nothing
end

function emit_qos!(state::ConsumerState)
    sent = try_claim_sbe!(state.pub_qos, state.qos_claim, QOS_CONSUMER_LEN) do buf
        QosConsumer.wrap_and_apply_header!(state.qos_encoder, buf, 0)
        QosConsumer.streamId!(state.qos_encoder, state.config.stream_id)
        QosConsumer.consumerId!(state.qos_encoder, state.config.consumer_id)
        QosConsumer.epoch!(state.qos_encoder, state.mapped_epoch)
        QosConsumer.lastSeqSeen!(state.qos_encoder, state.last_seq_seen)
        QosConsumer.dropsGap!(state.qos_encoder, state.drops_gap)
        QosConsumer.dropsLate!(state.qos_encoder, state.drops_late)
        QosConsumer.mode!(state.qos_encoder, state.config.mode)
    end
    if !sent
        QosConsumer.wrap_and_apply_header!(state.qos_encoder, state.qos_buf, 0)
        QosConsumer.streamId!(state.qos_encoder, state.config.stream_id)
        QosConsumer.consumerId!(state.qos_encoder, state.config.consumer_id)
        QosConsumer.epoch!(state.qos_encoder, state.mapped_epoch)
        QosConsumer.lastSeqSeen!(state.qos_encoder, state.last_seq_seen)
        QosConsumer.dropsGap!(state.qos_encoder, state.drops_gap)
        QosConsumer.dropsLate!(state.qos_encoder, state.drops_late)
        QosConsumer.mode!(state.qos_encoder, state.config.mode)
        Aeron.offer(
            state.pub_qos,
            view(state.qos_buf, 1:sbe_message_length(state.qos_encoder)),
        )
    end
    return nothing
end

function make_descriptor_assembler(state::ConsumerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
            FrameDescriptor.wrap!(st.desc_decoder, buffer, 0; header = header)
            try_read_frame!(st, st.desc_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

function make_control_assembler(state::ConsumerState)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        template_id = MessageHeader.templateId(header)
        if template_id == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.announce_decoder, buffer, 0; header = header)
            handle_shm_pool_announce!(st, st.announce_decoder)
        elseif template_id == TEMPLATE_CONSUMER_CONFIG
            ConsumerConfigMsg.wrap!(st.config_decoder, buffer, 0; header = header)
            apply_consumer_config!(st, st.config_decoder)
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

@inline function poll_descriptor!(state::ConsumerState, assembler::Aeron.FragmentAssembler, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(state.sub_descriptor, assembler, fragment_limit)
end

@inline function poll_control!(state::ConsumerState, assembler::Aeron.FragmentAssembler, fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT)
    return Aeron.poll(state.sub_control, assembler, fragment_limit)
end

function emit_periodic!(state::ConsumerState)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    work_done = false

    if now_ns - state.last_hello_ns >= state.config.hello_interval_ns
        emit_consumer_hello!(state)
        state.last_hello_ns = now_ns
        work_done = true
    end

    if now_ns - state.last_qos_ns >= state.config.qos_interval_ns
        emit_qos!(state)
        state.last_qos_ns = now_ns
        work_done = true
    end

    return work_done
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

function validate_strides!(state::ConsumerState, header::TensorSlotHeader, elem_size::Int64)
    ndims = Int(header.ndims)
    ndims == 0 && return true

    for i in 1:ndims
        dim = header.dims[i]
        dim < 0 && return false
        state.scratch_dims[i] = Int64(dim)
    end

    for i in 1:ndims
        stride = header.strides[i]
        stride < 0 && return false
        state.scratch_strides[i] = Int64(stride)
    end

    if header.major_order == MajorOrder.ROW
        if state.scratch_strides[ndims] == 0
            state.scratch_strides[ndims] = elem_size
        elseif state.scratch_strides[ndims] < elem_size
            return false
        end
        for i in (ndims - 1):-1:1
            required = state.scratch_strides[i + 1] * max(state.scratch_dims[i + 1], 1)
            if state.scratch_strides[i] == 0
                state.scratch_strides[i] = required
            end
            state.scratch_strides[i] < required && return false
        end
        return true
    elseif header.major_order == MajorOrder.COLUMN
        if state.scratch_strides[1] == 0
            state.scratch_strides[1] = elem_size
        elseif state.scratch_strides[1] < elem_size
            return false
        end
        for i in 2:ndims
            required = state.scratch_strides[i - 1] * max(state.scratch_dims[i - 1], 1)
            if state.scratch_strides[i] == 0
                state.scratch_strides[i] = required
            end
            state.scratch_strides[i] < required && return false
        end
        return true
    end

    return false
end
function try_read_frame!(
    state::ConsumerState,
    desc::FrameDescriptor.Decoder,
)
    state.header_mmap === nothing && return nothing
    FrameDescriptor.epoch(desc) == state.mapped_epoch || return nothing
    seq = FrameDescriptor.seq(desc)
    should_process(state, seq) || return nothing

    header_index = FrameDescriptor.headerIndex(desc)
    if state.mapped_nslots == 0 || header_index >= state.mapped_nslots
        state.drops_late += 1
        return nothing
    end

    header_offset = header_slot_offset(header_index)
    header_mmap = state.header_mmap::Vector{UInt8}

    commit_ptr = Ptr{UInt64}(pointer(header_mmap, header_offset + 1))
    first = atomic_load_u64(commit_ptr)
    if isodd(first)
        state.drops_late += 1
        return nothing
    end

    hdr_dec = TensorSlotHeader256.Decoder(Vector{UInt8})
    header = try
        wrap_tensor_header!(hdr_dec, header_mmap, header_offset)
        read_tensor_slot_header(hdr_dec)
    catch
        state.drops_late += 1
        return nothing
    end

    second = atomic_load_u64(commit_ptr)
    if first != second || isodd(second)
        state.drops_late += 1
        return nothing
    end

    commit_frame = second >> 1
    if commit_frame != header.frame_id
        state.drops_late += 1
        return nothing
    end

    last_commit = state.last_commit_words[Int(header_index) + 1]
    if second < last_commit
        state.drops_late += 1
        return nothing
    end

    if header.frame_id != seq
        state.drops_late += 1
        return nothing
    end

    if header.payload_slot != header_index
        state.drops_late += 1
        return nothing
    end

    if header.payload_offset != 0
        state.drops_late += 1
        return nothing
    end

    if !valid_dtype(header.dtype) || !valid_major_order(header.major_order)
        state.drops_late += 1
        return nothing
    end

    elem_size = dtype_size_bytes(header.dtype)
    if elem_size == 0 || header.ndims > state.config.max_dims ||
       !validate_strides!(state, header, elem_size)
        state.drops_late += 1
        return nothing
    end

    pool_stride = get(state.pool_stride_bytes, header.pool_id, UInt32(0))
    pool_stride == 0 && return nothing
    payload_mmap = get(state.payload_mmaps, header.pool_id, nothing)
    payload_mmap === nothing && return nothing

    payload_len = Int(header.values_len_bytes)
    payload_len > Int(pool_stride) && return nothing
    payload_offset = SUPERBLOCK_SIZE + Int(header.payload_slot) * Int(pool_stride)
    payload = view(payload_mmap, payload_offset + 1:payload_offset + payload_len)

    maybe_track_gap!(state, seq)
    state.last_commit_words[Int(header_index) + 1] = second
    return (header, payload)
end
