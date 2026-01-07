"""
Begin a seqlock write by marking the seq_commit as in-progress (LSB=0).

Arguments:
- `commit_ptr`: pointer to the seq_commit.
- `seq`: logical sequence number.

Returns:
- `nothing`.
"""
function seqlock_begin_write!(commit_ptr::Ptr{UInt64}, seq::UInt64)
    unsafe_store!(commit_ptr, seq << 1, :release)
    return nothing
end

"""
Commit a seqlock write by marking the seq_commit as committed (LSB=1).

Arguments:
- `commit_ptr`: pointer to the seq_commit.
- `seq`: logical sequence number.

Returns:
- `nothing`.
"""
function seqlock_commit_write!(commit_ptr::Ptr{UInt64}, seq::UInt64)
    unsafe_store!(commit_ptr, (seq << 1) | 1, :release)
    return nothing
end

"""
Acquire-load the current seqlock seq_commit at the start of a read.

Arguments:
- `commit_ptr`: pointer to the seq_commit.

Returns:
- The raw seq_commit value (UInt64).
"""
function seqlock_read_begin(commit_ptr::Ptr{UInt64})
    return unsafe_load(commit_ptr, :acquire)
end

"""
Acquire-load the seqlock seq_commit at the end of a read.

Arguments:
- `commit_ptr`: pointer to the seq_commit.

Returns:
- The raw seq_commit value (UInt64).
"""
function seqlock_read_end(commit_ptr::Ptr{UInt64})
    return unsafe_load(commit_ptr, :acquire)
end

"""
Return true if the seqlock indicates a committed slot (LSB=1).

Arguments:
- `word`: raw seq_commit value.

Returns:
- `true` if the slot is committed, `false` otherwise.
"""
function seqlock_is_committed(word::UInt64)
    return isodd(word)
end

"""
Return the logical sequence encoded in a seqlock seq_commit.

Arguments:
- `word`: raw seq_commit value.

Returns:
- Logical sequence (UInt64).
"""
function seqlock_sequence(word::UInt64)
    return word >> 1
end

"""
Return a pointer to the seq_commit for a header slot index.

Arguments:
- `header_mmap`: header mmap buffer.
- `header_index`: 0-based header slot index.

Returns:
- `Ptr{UInt64}` pointing to the seq_commit.
"""
function header_commit_ptr(header_mmap::AbstractVector{UInt8}, header_index::UInt32)
    header_offset = header_slot_offset(header_index)
    return Ptr{UInt64}(pointer(header_mmap, header_offset + 1))
end

"""
Return a pointer to the seq_commit for a header slot offset in bytes.

Arguments:
- `header_mmap`: header mmap buffer.
- `header_offset`: byte offset within the header mmap.

Returns:
- `Ptr{UInt64}` pointing to the seq_commit.
"""
function header_commit_ptr_from_offset(header_mmap::AbstractVector{UInt8}, header_offset::Integer)
    return Ptr{UInt64}(pointer(header_mmap, header_offset + 1))
end
