module Driver

using ..Core
using ..Core.TPLog
using ..Aeron
using ..Shm
using ..Control
using ..Timers
using ..AeronUtils
using ..Clocks
using ..UnsafeArrays
using ..SBE
using ..FixedSizeArrays
using ..Hsm
using ..ShmTensorpoolControl

include("config.jl")
include("metrics.jl")
include("lease_lifecycle.jl")
include("lifecycle.jl")
include("state.jl")
include("streams.jl")
include("leases.jl")
include("runtime.jl")
include("registry.jl")
include("inspect.jl")
include("encoders.jl")
include("handlers.jl")
include("lifecycle_handlers.jl")

export DriverConfig,
    DriverPolicies,
    DriverEndpoints,
    DriverPoolConfig,
    DriverProfileConfig,
    DriverStreamIdRange,
    DriverStreamConfig,
    DriverShmConfig,
    DriverState,
    DriverMetrics,
    DriverStatusSnapshot,
    DriverLeaseSnapshot,
    LeaseLifecycle,
    DriverStreamSnapshot,
    DriverAssignedStreamSnapshot,
    init_driver,
    load_driver_config,
    driver_do_work!,
    register_driver!,
    unregister_driver!,
    find_driver_state,
    list_driver_instances,
    driver_status_snapshot,
    driver_leases_snapshot,
    driver_streams_snapshot,
    driver_assigned_streams_snapshot,
    emit_driver_shutdown!,
    driver_lifecycle_dispatch!,
    revoke_lease!

end
