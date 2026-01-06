module Shm

using ..Core
using ..Core.TPLog
using ..Mmap

include("errors.jl")
include("uri.jl")
include("constants.jl")
include("linux.jl")
include("backend.jl")
include("paths.jl")
include("slots.jl")
include("seqlock.jl")
include("superblock.jl")

export ShmUri,
    parse_shm_uri,
    validate_uri,
    canonical_epoch_dir,
    canonical_header_uri,
    canonical_pool_uri,
    canonical_shm_paths,
    ShmUriError,
    ShmValidationError,
    SUPERBLOCK_SIZE,
    HEADER_SLOT_BYTES,
    MAGIC_TPOLSHM1,
    mmap_shm,
    mmap_shm_existing,
    header_slot_offset,
    header_commit_ptr,
    header_commit_ptr_from_offset,
    payload_slot_offset,
    payload_slot_ptr,
    payload_slot_view,
    TensorSlotHeader,
    SuperblockFields,
    page_size_bytes,
    hugepage_size_bytes,
    is_hugetlbfs_path,
    wrap_superblock!,
    wrap_tensor_header!,
    read_superblock,
    read_tensor_slot_header,
    try_read_tensor_slot_header,
    write_superblock!,
    write_tensor_slot_header!,
    validate_superblock_fields,
    seqlock_begin_write!,
    seqlock_commit_write!,
    seqlock_is_committed,
    seqlock_sequence,
    seqlock_read_begin,
    seqlock_read_end,
    validate_stride

end
