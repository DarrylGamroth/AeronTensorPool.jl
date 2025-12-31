using Test
using AeronTensorPool

include("helpers_aeron.jl")

include("test_shm_uri.jl")
include("test_shm_superblock.jl")
include("test_tensor_slot_header.jl")
include("test_consumer_validation.jl")
include("test_allocations.jl")
include("test_polled_timer.jl")
include("test_aeron_integration.jl")
include("test_supervisor_integration.jl")
include("test_payload_slot.jl")
include("test_slot_reservation.jl")
