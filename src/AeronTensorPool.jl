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
include("consumer.jl")

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
    ConsumerConfig,
    ConsumerState,
    ShmRegionSuperblock,
    ShmUri,
    SuperblockFields,
    TensorSlotHeader256,
    TensorSlotHeader,
    Mode,
    atomic_load_u64,
    atomic_store_u64!,
    init_consumer,
    map_from_announce!,
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
    try_read_frame!,
    validate_uri,
    validate_stride,
    validate_superblock_fields,
    wrap_superblock!,
    wrap_tensor_header!,
    write_superblock!,
    write_tensor_slot_header!

end
