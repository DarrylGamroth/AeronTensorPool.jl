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
include("test_consumer_seqlock.jl")
include("test_allocations.jl")
include("test_allocations_load.jl")
include("test_counters.jl")
include("test_polled_timer.jl")
include("test_aeron_integration.jl")
include("test_supervisor_integration.jl")
include("test_payload_slot.jl")
include("test_slot_reservation.jl")
include("test_inflight_queue.jl")
include("test_cli_tool.jl")
include("test_driver_config.jl")
include("test_driver_attach.jl")
include("test_driver_shutdown.jl")
include("test_driver_integration.jl")
include("test_driver_reattach.jl")
include("test_driver_lease_expiry.jl")
if get(ENV, "TP_RUN_SYSTEM_SMOKE", "false") == "true"
    include("test_system_smoke.jl")
end
if get(ENV, "TP_RUN_SYSTEM_SMOKE_GC", "false") == "true"
    include("test_system_smoke_gc.jl")
end
