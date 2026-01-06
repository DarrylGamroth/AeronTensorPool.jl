module Control

using ..Core
using ..Core.TPLog
using ..Timers
using ..Aeron
using ..AeronUtils
using ..UnsafeArrays
using ..SBE
using ..StringViews

include("runtime.jl")
include("proxies.jl")
include("pollers.jl")
include("driver_client.jl")

export ControlPlaneRuntime,
    AttachRequestProxy,
    KeepaliveProxy,
    DetachRequestProxy,
    ShutdownRequestProxy,
    DriverPool,
    AttachResponse,
    DetachResponse,
    LeaseRevoked,
    DriverShutdown,
    DriverResponsePoller,
    DriverClientState,
    send_attach!,
    send_detach!,
    send_keepalive!,
    send_shutdown_request!,
    init_driver_client,
    driver_client_do_work!,
    next_correlation_id!,
    send_attach_request!,
    apply_attach!,
    poll_driver_responses!,
    poll_attach!,
    poll_attach,
    poll_driver_control!,
    handle_driver_response!,
    snapshot_attach_response!,
    snapshot_detach_response!,
    snapshot_lease_revoked!,
    snapshot_shutdown!

end
