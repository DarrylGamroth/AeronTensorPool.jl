@inline function should_process(state::ConsumerState, seq::UInt64)
    if state.config.mode == Mode.DECIMATED
        return state.config.decimation > 0 && (seq % state.config.decimation == 0)
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
