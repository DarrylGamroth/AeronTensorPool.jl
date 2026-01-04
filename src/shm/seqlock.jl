"""
Begin a seqlock write by marking the commit_word as odd (WRITING).

Arguments:
- `commit_ptr`: pointer to the commit_word.
- `frame_id`: frame identifier (seq).

Returns:
- `nothing`.
"""
@inline function seqlock_begin_write!(commit_ptr::Ptr{UInt64}, frame_id::UInt64)
    unsafe_store!(commit_ptr, (frame_id << 1) | 1, :release)
    return nothing
end

"""
Commit a seqlock write by marking the commit_word as even (COMMITTED).

Arguments:
- `commit_ptr`: pointer to the commit_word.
- `frame_id`: frame identifier (seq).

Returns:
- `nothing`.
"""
@inline function seqlock_commit_write!(commit_ptr::Ptr{UInt64}, frame_id::UInt64)
    unsafe_store!(commit_ptr, frame_id << 1, :release)
    return nothing
end

"""
Acquire-load the current seqlock commit_word at the start of a read.

Arguments:
- `commit_ptr`: pointer to the commit_word.

Returns:
- The raw commit_word value (UInt64).
"""
@inline function seqlock_read_begin(commit_ptr::Ptr{UInt64})
    return unsafe_load(commit_ptr, :acquire)
end

"""
Acquire-load the seqlock commit_word at the end of a read.

Arguments:
- `commit_ptr`: pointer to the commit_word.

Returns:
- The raw commit_word value (UInt64).
"""
@inline function seqlock_read_end(commit_ptr::Ptr{UInt64})
    return unsafe_load(commit_ptr, :acquire)
end

"""
Return true if the seqlock indicates an in-progress write.

Arguments:
- `word`: raw commit_word value.

Returns:
- `true` if the write is in progress, `false` otherwise.
"""
@inline function seqlock_is_write_in_progress(word::UInt64)
    return isodd(word)
end

"""
Return the frame_id encoded in a seqlock commit_word.

Arguments:
- `word`: raw commit_word value.

Returns:
- `frame_id` (UInt64).
"""
@inline function seqlock_frame_id(word::UInt64)
    return word >> 1
end

"""
Return a pointer to the commit_word for a header slot index.

Arguments:
- `header_mmap`: header mmap buffer.
- `header_index`: 0-based header slot index.

Returns:
- `Ptr{UInt64}` pointing to the commit_word.
"""
@inline function header_commit_ptr(header_mmap::AbstractVector{UInt8}, header_index::UInt32)
    header_offset = header_slot_offset(header_index)
    return Ptr{UInt64}(pointer(header_mmap, header_offset + 1))
end

"""
Return a pointer to the commit_word for a header slot offset in bytes.

Arguments:
- `header_mmap`: header mmap buffer.
- `header_offset`: byte offset within the header mmap.

Returns:
- `Ptr{UInt64}` pointing to the commit_word.
"""
@inline function header_commit_ptr_from_offset(header_mmap::AbstractVector{UInt8}, header_offset::Integer)
    return Ptr{UInt64}(pointer(header_mmap, header_offset + 1))
end
