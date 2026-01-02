"""
Driver counters accumulated for metrics.
"""
mutable struct DriverMetrics
    attach_responses::UInt64
    attach_response_drops::UInt64
    detach_responses::UInt64
    keepalives::UInt64
    lease_revoked::UInt64
    announces::UInt64
    lease_hsm_unhandled::UInt64
end
