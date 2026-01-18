"""
Raised when discovery configuration is invalid.
"""
struct DiscoveryConfigError <: ProtocolError
    message::String
end

"""
Raised when discovery does not return results in time.
"""
struct DiscoveryTimeoutError <: ProtocolError
    message::String
end
