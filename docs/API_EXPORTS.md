# API Exports Inventory

This is the Phase 0 export inventory for AeronTensorPool. Public exports are defined in `src/AeronTensorPool.jl`.

## Exported Types and Constants
- Dtype, MajorOrder, RegionType, DriverHugepagesPolicy, DriverResponseCode, DriverRole, DriverPublishMode, DriverLeaseRevokeReason, DriverShutdownReason
- MAGIC_TPOLSHM1, SUPERBLOCK_SIZE, HEADER_SLOT_BYTES, MAX_DIMS
- PayloadPoolConfig, DriverPoolConfig, DriverProfileConfig, DriverStreamConfig, DriverPolicies, DriverShmConfig, DriverEndpoints, DriverConfig
- ProducerConfig, ProducerState, ProducerAgent, ProducerInfo
- ConsumerSettings, ConsumerConfigMsg, ConsumerState, ConsumerAgent, ConsumerInfo
- SupervisorConfig, SupervisorState, SupervisorAgent
- DriverAgent, DriverState
- BridgeAgent, BridgeConfig, BridgeMapping, BridgeSourceInfo, BridgeAssembledFrame, BridgeSenderState, BridgeReceiverState
- ConsumerHello, FrameDescriptor, FrameProgress, MessageHeader, DriverMessageHeader, QosProducer, QosConsumer
- ShmRegionSuperblock, ShmUri, SuperblockFields, TensorSlotHeader256, TensorSlotHeader, PayloadView, ConsumerFrameView, Mode
- ShmAttachRequest, ShmAttachResponse, ShmDetachRequest, ShmDetachResponse, ShmLeaseKeepalive
- ShmDriverShutdown, ShmLeaseRevoked, ShmDriverShutdownRequest
- FixedString, DriverPool, AttachResponse, DetachResponse, LeaseRevoked, DriverShutdown
- SlotClaim

## Exported Functions
- seqlock_begin_write!, seqlock_commit_write!, seqlock_read_begin, seqlock_read_end, seqlock_is_write_in_progress, seqlock_frame_id
- header_commit_ptr, header_commit_ptr_from_offset
- add_counter, make_counter_type_id
- due!, reset!, poll_timers!
- init_consumer, init_producer, init_producer_from_attach, producer_config_from_attach, init_consumer_from_attach
- init_supervisor, init_driver, init_bridge_sender, init_bridge_receiver
- bridge_forward_announce!, bridge_send_frame!, bridge_sender_do_work!, bridge_receiver_do_work!, bridge_rematerialize!
- map_from_announce!, map_from_attach_response!
- emit_consumer_config!, emit_announce!, emit_consumer_hello!, emit_progress_complete!, emit_qos!
- header_slot_offset, payload_slot_offset, payload_slot_view, payload_slot_ptr, payload_view
- handle_consumer_hello!, handle_shm_pool_announce!
- mmap_shm, parse_shm_uri, validate_uri, validate_stride, validate_superblock_fields
- offer_frame!, try_claim_slot!, commit_slot!, with_claimed_slot!
- read_superblock, read_tensor_slot_header, write_superblock!, write_tensor_slot_header!
- refresh_activity_timestamps!, reset_mappings!, select_pool
- try_read_frame!
- apply_consumer_config!
- canonical_epoch_dir, canonical_header_uri, canonical_pool_uri, canonical_shm_paths
- wrap_superblock!, wrap_tensor_header!
- make_control_assembler, make_descriptor_assembler, make_qos_assembler
- poll_control!, poll_descriptor!, poll_qos!, poll_driver_control!
- view (FixedString)
- supervisor_do_work!, producer_do_work!, consumer_do_work!, driver_do_work!
- next_header_index, payload_pool_config
- bridge_frame!, republish_descriptor!

## Exported Errors and Counters
- TensorPoolError, ShmUriError, ShmValidationError, AeronInitError
- Counters, ProducerCounters, ConsumerCounters, SupervisorCounters, DriverCounters, BridgeCounters

## Internal-Only (Not Exported)
- None
