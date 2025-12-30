module AeronTensorPool

using Aeron
using Agent
using Clocks
using Mmap
using SBE

include("gen/ShmTensorpoolControl.jl")
using .ShmTensorpoolControl

include("constants.jl")
include("shm.jl")
include("producer.jl")

export Dtype,
    MajorOrder,
    RegionType,
    MAGIC_TPOLSHM1,
    SUPERBLOCK_SIZE,
    HEADER_SLOT_BYTES,
    MAX_DIMS,
    PayloadPoolConfig,
    ProducerConfig,
    ProducerState,
    ShmRegionSuperblock,
    ShmUri,
    SuperblockFields,
    TensorSlotHeader256,
    TensorSlotHeader,
    atomic_load_u64,
    atomic_store_u64!,
    emit_announce!,
    emit_periodic!,
    emit_progress_complete!,
    emit_qos!,
    header_slot_offset,
    init_producer,
    mmap_shm,
    parse_shm_uri,
    publish_frame!,
    read_superblock,
    read_tensor_slot_header,
    refresh_activity_timestamps!,
    select_pool,
    validate_uri,
    wrap_superblock!,
    wrap_tensor_header!,
    write_superblock!,
    write_tensor_slot_header!

end
