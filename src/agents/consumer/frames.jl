function should_process(state::ConsumerState, seq::UInt64)
    state.config.mode == Mode.RATE_LIMITED || return true
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

valid_dtype(dtype::Dtype.SbeEnum) = dtype != Dtype.UNKNOWN && dtype != Dtype.NULL_VALUE

valid_major_order(order::MajorOrder.SbeEnum) = order == MajorOrder.ROW || order == MajorOrder.COLUMN

function dtype_size_bytes(dtype::Dtype.SbeEnum)
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
function validate_strides!(state::ConsumerState, tensor::TensorHeader, elem_size::Int64)
    ndims = Int(tensor.ndims)
    ndims == 0 && return true

    for i in 1:ndims
        dim = tensor.dims[i]
        dim < 0 && return false
        state.runtime.scratch_dims[i] = Int64(dim)
    end

    for i in 1:ndims
        stride = tensor.strides[i]
        stride < 0 && return false
        state.runtime.scratch_strides[i] = Int64(stride)
    end

    if tensor.major_order == MajorOrder.ROW
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
        return progress_stride_ok!(state, tensor)
    elseif tensor.major_order == MajorOrder.COLUMN
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
        return progress_stride_ok!(state, tensor)
    end

    return false
end

function progress_stride_ok!(state::ConsumerState, tensor::TensorHeader)
    unit = tensor.progress_unit
    unit == ProgressUnit.NONE && return true
    idx = unit == ProgressUnit.ROWS ? 1 : unit == ProgressUnit.COLUMNS ? 2 : 0
    idx == 0 && return false
    ndims = Int(tensor.ndims)
    ndims < idx && return false
    expected = UInt32(state.runtime.scratch_strides[idx])
    expected == 0 && return false
    return expected == tensor.progress_stride_bytes
end

"""
Attempt to read a frame from SHM using the seqlock protocol.

Arguments:
- `state`: consumer state and mappings.
- `desc`: frame descriptor decoder.
- `view`: output view to populate on success.

Returns:
- `true` on success (and updates `view`), `false` otherwise.
"""
function try_read_frame!(
    state::ConsumerState,
    desc::FrameDescriptor.Decoder,
    view::ConsumerFrameView,
)
    if !consumer_driver_active(state)
        @tp_debug "try_read_frame drop" reason = :driver_inactive
        return false
    end
    if state.mappings.header_mmap === nothing
        @tp_debug "try_read_frame drop" reason = :no_header_mmap
        return false
    end
    if FrameDescriptor.epoch(desc) != state.mappings.mapped_epoch
        @tp_debug "try_read_frame drop" reason = :epoch_mismatch desc_epoch = FrameDescriptor.epoch(desc) mapped_epoch =
            state.mappings.mapped_epoch
        return false
    end
    seq = FrameDescriptor.seq(desc)
    if !should_process(state, seq)
        @tp_debug "try_read_frame drop" reason = :decimated seq
        return false
    end

    header_index = FrameDescriptor.headerIndex(desc)
    if state.mappings.mapped_nslots == 0 || header_index >= state.mappings.mapped_nslots
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        @tp_debug "try_read_frame drop" reason = :header_index_invalid header_index mapped_nslots =
            state.mappings.mapped_nslots
        return false
    end

    header_offset = header_slot_offset(header_index)
    header_mmap = state.mappings.header_mmap::Vector{UInt8}

    commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
    first = seqlock_read_begin(commit_ptr)
    if !seqlock_is_committed(first)
        state.metrics.drops_late += 1
        state.metrics.drops_odd += 1
        @tp_debug "try_read_frame drop" reason = :write_in_progress first
        return false
    end

    wrap_slot_header!(state.runtime.slot_decoder, header_mmap, header_offset)
    header = try_read_slot_header(state.runtime.slot_decoder, state.runtime.tensor_decoder)
    if header === nothing
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        @tp_debug "try_read_frame drop" reason = :header_decode_error
        return false
    end

    second = seqlock_read_end(commit_ptr)
    if first != second || !seqlock_is_committed(second)
        state.metrics.drops_late += 1
        state.metrics.drops_changed += 1
        @tp_debug "try_read_frame drop" reason = :seqlock_changed first second
        return false
    end

    if header.seq_commit != second
        state.metrics.drops_late += 1
        state.metrics.drops_frame_id_mismatch += 1
        @tp_debug "try_read_frame drop" reason = :seq_commit_mismatch header_seq_commit = header.seq_commit seq_commit =
            second
        return false
    end

    last_commit = state.mappings.last_commit_words[Int(header_index) + 1]
    if second < last_commit
        state.metrics.drops_late += 1
        state.metrics.drops_changed += 1
        @tp_debug "try_read_frame drop" reason = :commit_rewind last_commit second
        return false
    end

    commit_seq = seqlock_sequence(second)
    if commit_seq != seq
        state.metrics.drops_late += 1
        state.metrics.drops_frame_id_mismatch += 1
        @tp_debug "try_read_frame drop" reason = :seq_mismatch seq_commit = commit_seq seq
        return false
    end

    if header.payload_slot != header_index
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        @tp_debug "try_read_frame drop" reason = :payload_slot_mismatch payload_slot = header.payload_slot header_index
        return false
    end

    if header.payload_offset != 0
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        @tp_debug "try_read_frame drop" reason = :payload_offset_nonzero payload_offset =
            header.payload_offset
        return false
    end

    if !valid_dtype(header.tensor.dtype) || !valid_major_order(header.tensor.major_order)
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        @tp_debug "try_read_frame drop" reason = :dtype_or_order_invalid dtype = header.tensor.dtype major_order =
            header.tensor.major_order
        return false
    end

    elem_size = dtype_size_bytes(header.tensor.dtype)
    if elem_size == 0 || header.tensor.ndims == 0 || header.tensor.ndims > UInt8(MAX_DIMS) ||
       !validate_strides!(state, header.tensor, elem_size)
        state.metrics.drops_late += 1
        state.metrics.drops_header_invalid += 1
        @tp_debug "try_read_frame drop" reason = :stride_invalid elem_size header_ndims = header.tensor.ndims
        return false
    end

    pool_stride = get(state.mappings.pool_stride_bytes, header.pool_id, UInt32(0))
    if pool_stride == 0
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        @tp_debug "try_read_frame drop" reason = :pool_stride_missing pool_id = header.pool_id
        return false
    end
    payload_mmap = get(state.mappings.payload_mmaps, header.pool_id, nothing)
    if payload_mmap === nothing
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        @tp_debug "try_read_frame drop" reason = :payload_mmap_missing pool_id = header.pool_id
        return false
    end

    payload_len = Int(header.values_len_bytes)
    if payload_len > Int(pool_stride)
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        @tp_debug "try_read_frame drop" reason = :payload_len_invalid payload_len pool_stride
        return false
    end
    if Int(header.payload_offset) + payload_len > Int(pool_stride)
        state.metrics.drops_late += 1
        state.metrics.drops_payload_invalid += 1
        @tp_debug "try_read_frame drop" reason = :payload_bounds_invalid payload_offset = header.payload_offset payload_len pool_stride
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

Arguments:
- `state`: consumer state and mappings.
- `desc`: frame descriptor decoder.

Returns:
- `true` on success, `false` otherwise.
"""
function try_read_frame!(state::ConsumerState, desc::FrameDescriptor.Decoder)
    return try_read_frame!(state, desc, state.runtime.frame_view)
end
