"""
Raised when discovery configuration is invalid.
"""
struct DiscoveryConfigError <: TensorPoolError
    message::String
end

"""
Raised when discovery does not return results in time.
"""
struct DiscoveryTimeoutError <: TensorPoolError
    message::String
end
