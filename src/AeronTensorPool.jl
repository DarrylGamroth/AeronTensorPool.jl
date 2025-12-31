module AeronTensorPool

using Aeron
using Agent
using Clocks
using Mmap
using SBE
using UnsafeArrays

include("gen/ShmTensorpoolControl.jl")
using .ShmTensorpoolControl

include("constants.jl")
include("aeron_utils.jl")
include("polled_timer.jl")
include("shm.jl")
include("producer.jl")
include("consumer.jl")
include("supervisor.jl")
include("bridge.jl")
include("decimator.jl")

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
    ProducerInfo,
    ConsumerConfig,
    ConsumerConfigMsg,
    ConsumerState,
    ConsumerInfo,
    SupervisorConfig,
    SupervisorState,
    BridgeConfig,
    BridgeState,
    DecimatorConfig,
    DecimatorState,
    ConsumerHello,
    FrameDescriptor,
    FrameProgress,
    MessageHeader,
    QosProducer,
    ShmRegionSuperblock,
    ShmUri,
    SuperblockFields,
    TensorSlotHeader256,
    TensorSlotHeader,
    Mode,
    QosConsumer,
    atomic_load_u64,
    atomic_store_u64!,
    PolledTimer,
    due!,
    reset!,
    init_consumer,
    init_supervisor,
    init_bridge,
    init_decimator,
    map_from_announce!,
    emit_consumer_config!,
    emit_announce!,
    emit_consumer_hello!,
    emit_periodic!,
    emit_progress_complete!,
    emit_qos!,
    header_slot_offset,
    payload_slot_offset,
    payload_slot_view,
    payload_slot_ptr,
    handle_consumer_hello!,
    handle_shm_pool_announce!,
    init_producer,
    init_consumer,
    mmap_shm,
    parse_shm_uri,
    publish_frame!,
    read_superblock,
    read_tensor_slot_header,
    refresh_activity_timestamps!,
    reset_mappings!,
    select_pool,
    try_read_frame!,
    apply_consumer_config!,
    validate_uri,
    validate_stride,
    validate_superblock_fields,
    wrap_superblock!,
    wrap_tensor_header!,
    make_control_assembler,
    make_descriptor_assembler,
    poll_control!,
    poll_descriptor!,
    poll_qos!,
    next_header_index,
    payload_pool_config,
    publish_frame_from_slot!,
    reserve_slot!,
    publish_reservation!,
    SlotReservation,
    bridge_frame!,
    handle_decimated_frame!,
    republish_descriptor!,
    write_superblock!,
    write_tensor_slot_header!,
    try_claim_sbe!,
    sbe_message_length

end
