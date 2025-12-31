using Test
using AeronTensorPool

include("helpers_aeron.jl")

include("test_shm_uri.jl")
include("test_shm_superblock.jl")
include("test_tensor_slot_header.jl")
include("test_consumer_validation.jl")
include("test_consumer_pid_change.jl")
include("test_consumer_remap_fallback.jl")
include("test_consumer_seq_gap.jl")
include("test_consumer_stride_validation.jl")
include("test_allocations.jl")
include("test_polled_timer.jl")
include("test_aeron_integration.jl")
include("test_supervisor_integration.jl")
include("test_payload_slot.jl")
include("test_slot_reservation.jl")
include("test_inflight_queue.jl")
include("test_cli_tool.jl")
