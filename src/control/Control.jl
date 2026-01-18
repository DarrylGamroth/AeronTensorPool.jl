module Control

using ..Core
using ..Core.TPLog
using ..Timers
using ..Aeron
using ..AeronUtils
using ..UnsafeArrays
using ..SBE
using ..StringViews

include("errors.jl")
include("constants.jl")
include("runtime.jl")
include("proxies.jl")
include("pollers.jl")
include("descriptor_pollers.jl")
include("driver_client.jl")

export ControlPlaneRuntime,
    AttachRequestProxy,
    KeepaliveProxy,
    DetachRequestProxy,
    ShutdownRequestProxy,
    DriverPool,
    AttachRejectedError,
    AttachTimeoutError,
    AttachResponse,
    DetachResponse,
    LeaseRevoked,
    DriverShutdown,
    DEFAULT_FRAGMENT_LIMIT,
    CONTROL_BUF_BYTES,
    ANNOUNCE_BUF_BYTES,
    DRIVER_URI_MAX_BYTES,
    DRIVER_ERROR_MAX_BYTES,
    DriverResponsePoller,
    AbstractControlPoller,
    FrameDescriptorPoller,
    FrameDescriptorProbe,
    ConsumerConfigPoller,
    FrameProgressPoller,
    TraceLinkPoller,
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
    poll_driver_control!,
    poll!,
    rebind!,
    handle_driver_response!,
    snapshot_attach_response!,
    snapshot_detach_response!,
    snapshot_lease_revoked!,
    snapshot_shutdown!

end
